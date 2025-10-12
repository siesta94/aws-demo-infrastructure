/**
 * RDS Aurora Module Outputs
 */

output "cluster_id" {
  description = "The ID of the RDS cluster"
  value       = aws_rds_cluster.main.id
}

output "cluster_arn" {
  description = "The ARN of the RDS cluster"
  value       = aws_rds_cluster.main.arn
}

output "cluster_endpoint" {
  description = "The cluster endpoint (writer)"
  value       = aws_rds_cluster.main.endpoint
}

output "cluster_reader_endpoint" {
  description = "The cluster reader endpoint"
  value       = aws_rds_cluster.main.reader_endpoint
}

output "cluster_port" {
  description = "The port the cluster is listening on"
  value       = aws_rds_cluster.main.port
}

output "database_name" {
  description = "The name of the database"
  value       = aws_rds_cluster.main.database_name
}

output "master_username" {
  description = "The master username"
  value       = aws_rds_cluster.main.master_username
  sensitive   = true
}

output "primary_instance_id" {
  description = "The ID of the primary instance"
  value       = aws_rds_cluster_instance.primary.id
}

output "replica_instance_ids" {
  description = "List of replica instance IDs"
  value       = aws_rds_cluster_instance.replica[*].id
}

output "secret_arn" {
  description = "ARN of the Secrets Manager secret containing DB credentials"
  value       = aws_secretsmanager_secret.db_master_password.arn
}

output "secret_name" {
  description = "Name of the Secrets Manager secret containing DB credentials"
  value       = aws_secretsmanager_secret.db_master_password.name
}

output "db_subnet_group_name" {
  description = "Name of the DB subnet group"
  value       = aws_db_subnet_group.main.name
}

output "cluster_resource_id" {
  description = "The Resource ID of the cluster"
  value       = aws_rds_cluster.main.cluster_resource_id
}
