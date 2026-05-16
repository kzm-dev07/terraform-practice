output "instance_public_ip" {
  description = "EC2のパブリックIP"
  value       = aws_instance.web.public_ip
}

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}
