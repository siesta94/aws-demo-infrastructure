/**
 * MongoDB Atlas Module Outputs
 */

# Project Outputs
output "project_id" {
  description = "The ID of the Atlas project"
  value       = local.project_id
}

output "project_name" {
  description = "The name of the Atlas project"
  value       = var.create_project ? mongodbatlas_project.main[0].name : null
}

# Cluster Outputs
output "cluster_id" {
  description = "The ID of the Atlas cluster"
  value       = mongodbatlas_advanced_cluster.main.cluster_id
}

output "cluster_name" {
  description = "The name of the Atlas cluster"
  value       = mongodbatlas_advanced_cluster.main.name
}

output "cluster_state" {
  description = "Current state of the cluster"
  value       = mongodbatlas_advanced_cluster.main.state_name
}

output "connection_strings" {
  description = "Connection strings for the cluster"
  value = {
    standard     = mongodbatlas_advanced_cluster.main.connection_strings[0].standard
    standard_srv = mongodbatlas_advanced_cluster.main.connection_strings[0].standard_srv
    private      = try(mongodbatlas_advanced_cluster.main.connection_strings[0].private, null)
    private_srv  = try(mongodbatlas_advanced_cluster.main.connection_strings[0].private_srv, null)
  }
  sensitive = true
}

output "mongo_db_version" {
  description = "Version of MongoDB the cluster is running"
  value       = mongodbatlas_advanced_cluster.main.mongo_db_version
}

output "cluster_type" {
  description = "Type of the cluster"
  value       = mongodbatlas_advanced_cluster.main.cluster_type
}

# Database Users
output "database_users" {
  description = "Map of created database users"
  value = {
    for k, v in mongodbatlas_database_user.main : k => {
      username           = v.username
      auth_database_name = v.auth_database_name
    }
  }
}

# Network Configuration
output "network_container_id" {
  description = "The ID of the network container (if VPC peering is enabled)"
  value       = var.enable_vpc_peering ? mongodbatlas_network_container.main[0].container_id : null
}

output "network_container_atlas_cidr_block" {
  description = "CIDR block of the Atlas network container"
  value       = var.enable_vpc_peering ? mongodbatlas_network_container.main[0].atlas_cidr_block : null
}

output "vpc_peering_connection_id" {
  description = "The ID of the VPC peering connection"
  value       = var.enable_vpc_peering ? mongodbatlas_network_peering.aws_peer[0].connection_id : null
}

output "vpc_peering_status" {
  description = "Status of the VPC peering connection"
  value       = var.enable_vpc_peering ? mongodbatlas_network_peering.aws_peer[0].status_name : null
}

# PrivateLink
output "privatelink_endpoint_id" {
  description = "The ID of the PrivateLink endpoint"
  value       = var.enable_privatelink ? mongodbatlas_privatelink_endpoint.main[0].private_link_id : null
}

output "privatelink_endpoint_service_name" {
  description = "The service name of the PrivateLink endpoint"
  value       = var.enable_privatelink ? mongodbatlas_privatelink_endpoint.main[0].endpoint_service_name : null
}

output "privatelink_status" {
  description = "Status of the PrivateLink connection"
  value       = var.enable_privatelink ? mongodbatlas_privatelink_endpoint.main[0].status : null
}

# Backup Configuration
output "backup_enabled" {
  description = "Whether backup is enabled for the cluster"
  value       = mongodbatlas_advanced_cluster.main.backup_enabled
}

output "pit_enabled" {
  description = "Whether point-in-time restore is enabled"
  value       = mongodbatlas_advanced_cluster.main.pit_enabled
}

output "snapshot_backup_policy" {
  description = "Snapshot backup policy configuration"
  value = var.backup_enabled ? {
    cluster_name             = mongodbatlas_cloud_backup_schedule.main[0].cluster_name
    reference_hour_of_day    = mongodbatlas_cloud_backup_schedule.main[0].reference_hour_of_day
    reference_minute_of_hour = mongodbatlas_cloud_backup_schedule.main[0].reference_minute_of_hour
    restore_window_days      = mongodbatlas_cloud_backup_schedule.main[0].restore_window_days
  } : null
}

# Maintenance Window
output "maintenance_window" {
  description = "Configured maintenance window"
  value = var.maintenance_window != null ? {
    day_of_week = mongodbatlas_maintenance_window.main[0].day_of_week
    hour_of_day = mongodbatlas_maintenance_window.main[0].hour_of_day
  } : null
}

# Monitoring and Alerts
output "alert_configuration_ids" {
  description = "Map of alert configuration IDs"
  value = {
    for k, v in mongodbatlas_alert_configuration.main : k => v.alert_configuration_id
  }
}

# IP Access List
output "ip_whitelist" {
  description = "Map of whitelisted IP addresses/CIDR blocks"
  value = {
    for k, v in mongodbatlas_project_ip_access_list.ip_whitelist : k => {
      cidr_block = v.cidr_block
      comment    = v.comment
    }
  }
}

# Cluster Endpoints
output "cluster_endpoints" {
  description = "List of cluster endpoints"
  value       = [for endpoint in mongodbatlas_advanced_cluster.main.replication_specs[0].region_configs : {
    provider_name = endpoint.provider_name
    region_name   = endpoint.region_name
  }]
}

# Summary Output
output "cluster_summary" {
  description = "Summary of the MongoDB Atlas cluster configuration"
  value = {
    project_id         = local.project_id
    cluster_id         = mongodbatlas_advanced_cluster.main.cluster_id
    cluster_name       = mongodbatlas_advanced_cluster.main.name
    cluster_type       = mongodbatlas_advanced_cluster.main.cluster_type
    mongodb_version    = mongodbatlas_advanced_cluster.main.mongo_db_version
    state              = mongodbatlas_advanced_cluster.main.state_name
    backup_enabled     = mongodbatlas_advanced_cluster.main.backup_enabled
    pit_enabled        = mongodbatlas_advanced_cluster.main.pit_enabled
    vpc_peering_enabled = var.enable_vpc_peering
    privatelink_enabled = var.enable_privatelink
  }
}
