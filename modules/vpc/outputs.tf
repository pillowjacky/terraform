output "vpc-id" {
  value = aws_vpc.main.id
}

output "vpc-private-subnets" {
  value = aws_subnet.private[*].id
}
