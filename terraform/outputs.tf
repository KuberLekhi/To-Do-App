output "instance_id" {
  description = "EC2 instance ID (used by GitHub Actions to target SSM commands)"
  value       = aws_instance.app.id
}

output "instance_public_ip" {
  description = "Public IP of the app server"
  value       = aws_instance.app.public_ip
}

output "ecr_repository_url" {
  description = "ECR repository URL to push images to"
  value       = aws_ecr_repository.app.repository_url
}

output "app_url" {
  value = "http://${aws_instance.app.public_ip}:5000"
}

output "grafana_url" {
  value = "http://${aws_instance.app.public_ip}:3000"
}
