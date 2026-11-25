"""Demo 3-tier web application.

Endpoints
  /          HTML page: which instance/AZ served you + visit counter from RDS
  /health    ALB health check (always 200 if the process is alive)
  /db        JSON: database connectivity + visit counter
  /s3        JSON: writes a small object to the S3 bucket (proves the IAM role works)
  /cpu       burns CPU for a short time (used by scripts/load_test.sh to trigger scaling)

Configuration is read from environment variables written by Terraform user data:
  DB_HOST, DB_PORT, DB_NAME, DB_SECRET_ARN, S3_BUCKET, AWS_REGION
"""
import json
import os
import socket
import time
import urllib.request
from datetime import datetime, timezone

import boto3
import pymysql
from flask import Flask, jsonify

app = Flask(__name__)

REGION = os.environ.get("AWS_REGION", "ap-south-1")
DB_HOST = os.environ.get("DB_HOST", "")
DB_PORT = int(os.environ.get("DB_PORT", "3306"))
DB_NAME = os.environ.get("DB_NAME", "appdb")
DB_SECRET_ARN = os.environ.get("DB_SECRET_ARN", "")
S3_BUCKET = os.environ.get("S3_BUCKET", "")

_IMDS = "http://169.254.169.254/latest"
_creds = {"value": None, "fetched_at": 0.0}
CREDS_TTL_SECONDS = 300  # RDS-managed secrets rotate, so never cache forever


def _imds(path):
    """Read instance metadata using IMDSv2."""
    try:
        token_req = urllib.request.Request(
            f"{_IMDS}/api/token",
            method="PUT",
            headers={"X-aws-ec2-metadata-token-ttl-seconds": "60"},
        )
        token = urllib.request.urlopen(token_req, timeout=2).read().decode()
        req = urllib.request.Request(
            f"{_IMDS}/meta-data/{path}",
            headers={"X-aws-ec2-metadata-token": token},
        )
        return urllib.request.urlopen(req, timeout=2).read().decode()
    except Exception:
        return "unknown"


INSTANCE_ID = _imds("instance-id")
AZ = _imds("placement/availability-zone")
HOSTNAME = socket.gethostname()


def _db_credentials(force_refresh=False):
    now = time.time()
    if force_refresh or _creds["value"] is None or now - _creds["fetched_at"] > CREDS_TTL_SECONDS:
        client = boto3.client("secretsmanager", region_name=REGION)
        secret = client.get_secret_value(SecretId=DB_SECRET_ARN)
        _creds["value"] = json.loads(secret["SecretString"])
        _creds["fetched_at"] = now
    return _creds["value"]


def _connect(creds):
    return pymysql.connect(
        host=DB_HOST,
        port=DB_PORT,
        user=creds["username"],
        password=creds["password"],
        database=DB_NAME,
        connect_timeout=5,
        autocommit=True,
    )


def get_connection():
    try:
        return _connect(_db_credentials())
    except pymysql.err.OperationalError:
        # password may have been rotated: refresh once and retry
        return _connect(_db_credentials(force_refresh=True))


def record_visit():
    """Insert one visit row and return the total number of visits."""
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            cur.execute(
                "CREATE TABLE IF NOT EXISTS visits ("
                "id INT AUTO_INCREMENT PRIMARY KEY, "
                "instance_id VARCHAR(32), "
                "visited_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP)"
            )
            cur.execute("INSERT INTO visits (instance_id) VALUES (%s)", (INSTANCE_ID,))
            cur.execute("SELECT COUNT(*) FROM visits")
            return cur.fetchone()[0]
    finally:
        conn.close()


@app.route("/health")
def health():
    # Deliberately independent of the database: a DB blip must not make the ALB
    # pull every server out of rotation.
    return "ok", 200


@app.route("/db")
def db_check():
    try:
        return jsonify(status="connected", total_visits=record_visit(), served_by=INSTANCE_ID)
    except Exception as exc:  # noqa: BLE001
        return jsonify(status="error", error=str(exc)), 503


@app.route("/s3")
def s3_check():
    try:
        key = f"health-checks/{INSTANCE_ID}.txt"
        boto3.client("s3", region_name=REGION).put_object(
            Bucket=S3_BUCKET,
            Key=key,
            Body=f"written by {INSTANCE_ID} at {datetime.now(timezone.utc).isoformat()}".encode(),
        )
        return jsonify(status="ok", bucket=S3_BUCKET, key=key)
    except Exception as exc:  # noqa: BLE001
        return jsonify(status="error", error=str(exc)), 503


@app.route("/cpu")
def cpu():
    """Burn CPU for ~0.8s so load tests can trigger Auto Scaling."""
    end = time.time() + 0.8
    n = 0
    while time.time() < end:
        n += sum(i * i for i in range(2000))
    return jsonify(status="done", served_by=INSTANCE_ID)


PAGE = """<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Highly Available Web App on AWS</title>
  <style>
    body {{ font-family: system-ui, sans-serif; background:#0f172a; color:#e2e8f0; margin:0; }}
    main {{ max-width: 720px; margin: 8vh auto; padding: 0 1.5rem; }}
    h1 {{ font-size: 1.6rem; }}
    .card {{ background:#1e293b; border-radius:12px; padding:1.25rem 1.5rem; margin-top:1rem; }}
    dt {{ color:#94a3b8; font-size:.8rem; text-transform:uppercase; margin-top:.8rem; }}
    dd {{ margin:0; font-size:1.1rem; font-family: ui-monospace, monospace; }}
    .ok {{ color:#4ade80; }} .bad {{ color:#f87171; }}
  </style>
</head>
<body>
<main>
  <h1>Highly Available Web App on AWS</h1>
  <p>Refresh the page: the instance and Availability Zone change as the load balancer rotates requests.</p>
  <div class="card">
    <dl>
      <dt>Served by instance</dt><dd>{instance}</dd>
      <dt>Availability Zone</dt><dd>{az}</dd>
      <dt>Hostname</dt><dd>{host}</dd>
      <dt>Database (RDS, private subnet)</dt><dd class="{db_class}">{db_status}</dd>
      <dt>Total visits stored in RDS</dt><dd>{visits}</dd>
      <dt>Server time (UTC)</dt><dd>{now}</dd>
    </dl>
  </div>
</main>
</body>
</html>
"""


@app.route("/")
def index():
    try:
        visits = record_visit()
        db_status, db_class = "connected", "ok"
    except Exception as exc:  # noqa: BLE001
        visits, db_status, db_class = "n/a", f"unreachable ({type(exc).__name__})", "bad"

    return PAGE.format(
        instance=INSTANCE_ID,
        az=AZ,
        host=HOSTNAME,
        db_status=db_status,
        db_class=db_class,
        visits=visits,
        now=datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S"),
    )


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("APP_PORT", "8080")))
