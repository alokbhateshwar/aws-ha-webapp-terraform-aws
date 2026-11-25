output "asg_name" {
  value = aws_autoscaling_group.app.name
}

output "iam_role_name" {
  value = aws_iam_role.app.name
}

output "log_group_name" {
  value = aws_cloudwatch_log_group.app.name
}
