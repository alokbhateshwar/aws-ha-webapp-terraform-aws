output "certificate_arn" {
  description = "Validated certificate ARN (available only after validation completes)."
  value       = aws_acm_certificate_validation.this.certificate_arn
}
