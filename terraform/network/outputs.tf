output "available_zones" {
  value = data.aws_availability_zones.available.names
}

output "vpc_main_id" {
  value = aws_vpc.main.id
}

output "public_subtens_id" {
  value = aws_subnet.public[*].id
}

output "route_table_id" {
  value = aws_route_table.prod-route.id
}
