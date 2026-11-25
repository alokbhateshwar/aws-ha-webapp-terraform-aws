# Screenshots checklist

Take these after `terraform apply` and save them in this folder (PNG). Reference them in the main README.

| File name | Where to capture | What it should show |
|-----------|------------------|---------------------|
| `01-app-browser.png` | Browser | The app page showing instance ID + AZ (take two shots after refresh to show different instances) |
| `02-ec2-instances.png` | EC2 > Instances | 2+ running instances in different AZs |
| `03-load-balancer.png` | EC2 > Load Balancers | ALB state `active`, 2 AZs, DNS name |
| `04-target-group-health.png` | EC2 > Target Groups > Targets | All targets `healthy` |
| `05-auto-scaling-group.png` | EC2 > Auto Scaling Groups | Min/desired/max, instances, scaling policy |
| `06-scaling-activity.png` | ASG > Activity | A scale-out event after running the load test |
| `07-cloudwatch-alarms.png` | CloudWatch > Alarms | All alarms in `OK` state |
| `08-cloudwatch-dashboard.png` | CloudWatch > Dashboards | Dashboard with CPU, request count, instance count |
| `09-rds.png` | RDS > Databases | Instance with Multi-AZ / private (Publicly accessible: No) |
| `10-vpc-resource-map.png` | VPC > Your VPCs > Resource map | Subnets, route tables, gateways |
| `11-security-groups.png` | EC2 > Security Groups | Inbound rules of ALB, App and DB groups |

