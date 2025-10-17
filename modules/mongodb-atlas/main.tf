/**
 * MongoDB Atlas Module
 * 
 * Creates a MongoDB Atlas cluster with project, database users, and network access configuration
 * Integrates with AWS for private endpoints and VPC peering
 */

terraform {
  required_providers {
    mongodbatlas = {
      source  = "mongodb/mongodbatlas"
      version = "~> 1.15"
    }
  }
}

# Atlas Project
resource "mongodbatlas_project" "main" {
  count = var.create_project ? 1 : 0

  name   = "${var.project_name}-${var.environment}"
  org_id = var.atlas_org_id

  is_collect_database_specifics_statistics_enabled = var.enable_performance_advisor
  is_data_explorer_enabled                         = var.enable_data_explorer
  is_extended_storage_sizes_enabled                = var.enable_extended_storage_sizes
  is_performance_advisor_enabled                   = var.enable_performance_advisor
  is_realtime_performance_panel_enabled            = var.enable_realtime_performance_panel
  is_schema_advisor_enabled                        = var.enable_schema_advisor
}

# Use existing project or created one
locals {
  project_id = var.create_project ? mongodbatlas_project.main[0].id : var.existing_project_id
}

# Advanced Cluster
resource "mongodbatlas_advanced_cluster" "main" {
  project_id   = local.project_id
  name         = "${var.project_name}-${var.environment}-cluster"
  cluster_type = var.cluster_type

  backup_enabled                 = var.backup_enabled
  pit_enabled                    = var.pit_enabled
  mongo_db_major_version         = var.mongodb_version
  version_release_system         = var.version_release_system
  termination_protection_enabled = var.termination_protection_enabled

  replication_specs = [
    {
      num_shards = var.num_shards
      region_configs = [
        {
          electable_specs = {
            instance_size = var.instance_size
            node_count    = var.node_count
          }
          analytics_specs = {
            instance_size = var.analytics_instance_size
            node_count    = var.analytics_node_count
          }
          priority      = 7
          provider_name = "AWS"
          region_name   = var.atlas_region
        }
      ]
    }
  ]

  bi_connector_config = {
    enabled         = var.bi_connector_enabled
    read_preference = var.bi_connector_read_preference
  }

  advanced_configuration = var.advanced_configuration != null ? var.advanced_configuration : {}

  tags = concat(
    [
      {
        key   = "Environment"
        value = var.environment
      },
      {
        key   = "Project"
        value = var.project_name
      }
    ],
    [for k, v in var.atlas_tags : {
      key   = k
      value = v
    }]
  )
}

# Database Users
resource "mongodbatlas_database_user" "main" {
  for_each = var.database_users

  username           = each.value.username
  password           = each.value.password
  project_id         = local.project_id
  auth_database_name = each.value.auth_database_name

  dynamic "roles" {
    for_each = each.value.roles
    content {
      role_name     = roles.value.role_name
      database_name = roles.value.database_name
    }
  }

  dynamic "scopes" {
    for_each = each.value.scopes
    content {
      name = scopes.value.name
      type = scopes.value.type
    }
  }

  labels {
    key   = "Environment"
    value = var.environment
  }

  dynamic "labels" {
    for_each = each.value.labels
    content {
      key   = labels.key
      value = labels.value
    }
  }
}

# Network Access - IP Whitelist
resource "mongodbatlas_project_ip_access_list" "ip_whitelist" {
  for_each = var.ip_whitelist

  project_id = local.project_id
  cidr_block = each.value.cidr_block
  comment    = each.value.comment
}

# AWS VPC Peering Connection (if enabled)
resource "mongodbatlas_network_peering" "aws_peer" {
  count = var.enable_vpc_peering ? 1 : 0

  project_id             = local.project_id
  container_id           = mongodbatlas_network_container.main[0].container_id
  provider_name          = "AWS"
  route_table_cidr_block = var.vpc_peering_route_table_cidr_block
  vpc_id                 = var.vpc_id
  aws_account_id         = var.aws_account_id
}

# Network Container for VPC Peering
resource "mongodbatlas_network_container" "main" {
  count = var.enable_vpc_peering ? 1 : 0

  project_id       = local.project_id
  atlas_cidr_block = var.atlas_cidr_block
  provider_name    = "AWS"
  region_name      = var.atlas_region
}

# AWS PrivateLink Endpoint (if enabled)
resource "mongodbatlas_privatelink_endpoint" "main" {
  count = var.enable_privatelink ? 1 : 0

  project_id    = local.project_id
  provider_name = "AWS"
  region        = var.aws_region
}

resource "mongodbatlas_privatelink_endpoint_service" "main" {
  count = var.enable_privatelink ? 1 : 0

  project_id          = mongodbatlas_privatelink_endpoint.main[0].project_id
  private_link_id     = mongodbatlas_privatelink_endpoint.main[0].private_link_id
  endpoint_service_id = var.aws_vpc_endpoint_service_id
  provider_name       = "AWS"
}

# Maintenance Window
resource "mongodbatlas_maintenance_window" "main" {
  count = var.maintenance_window != null ? 1 : 0

  project_id              = local.project_id
  day_of_week             = var.maintenance_window.day_of_week
  hour_of_day             = var.maintenance_window.hour_of_day
  auto_defer_once_enabled = try(var.maintenance_window.auto_defer_once_enabled, false)
}

# Auditing (requires M10+ cluster)
resource "mongodbatlas_auditing" "main" {
  count = var.enable_auditing ? 1 : 0

  project_id                  = local.project_id
  audit_filter                = var.audit_filter
  audit_authorization_success = var.audit_authorization_success
  enabled                     = true
}

# Cloud Provider Snapshots
resource "mongodbatlas_cloud_backup_schedule" "main" {
  count = var.backup_enabled ? 1 : 0

  project_id   = local.project_id
  cluster_name = mongodbatlas_advanced_cluster.main.name

  reference_hour_of_day    = var.backup_reference_hour_of_day
  reference_minute_of_hour = var.backup_reference_minute_of_hour
  restore_window_days      = var.backup_restore_window_days

  dynamic "policy_item_hourly" {
    for_each = var.backup_policy_hourly != null ? [var.backup_policy_hourly] : []
    content {
      frequency_interval = policy_item_hourly.value.frequency_interval
      retention_unit     = policy_item_hourly.value.retention_unit
      retention_value    = policy_item_hourly.value.retention_value
    }
  }

  dynamic "policy_item_daily" {
    for_each = var.backup_policy_daily != null ? [var.backup_policy_daily] : []
    content {
      frequency_interval = policy_item_daily.value.frequency_interval
      retention_unit     = policy_item_daily.value.retention_unit
      retention_value    = policy_item_daily.value.retention_value
    }
  }

  dynamic "policy_item_weekly" {
    for_each = var.backup_policy_weekly != null ? [var.backup_policy_weekly] : []
    content {
      frequency_interval = policy_item_weekly.value.frequency_interval
      retention_unit     = policy_item_weekly.value.retention_unit
      retention_value    = policy_item_weekly.value.retention_value
    }
  }

  dynamic "policy_item_monthly" {
    for_each = var.backup_policy_monthly != null ? [var.backup_policy_monthly] : []
    content {
      frequency_interval = policy_item_monthly.value.frequency_interval
      retention_unit     = policy_item_monthly.value.retention_unit
      retention_value    = policy_item_monthly.value.retention_value
    }
  }
}

# Alert Configurations
resource "mongodbatlas_alert_configuration" "main" {
  for_each = var.alert_configurations

  project_id = local.project_id
  event_type = each.value.event_type
  enabled    = each.value.enabled

  dynamic "notification" {
    for_each = each.value.notifications
    content {
      type_name     = notification.value.type_name
      interval_min  = notification.value.interval_min
      delay_min     = notification.value.delay_min
      email_enabled = try(notification.value.email_enabled, null)
      sms_enabled   = try(notification.value.sms_enabled, null)
      email_address = try(notification.value.email_address, null)
    }
  }

  dynamic "threshold_config" {
    for_each = each.value.threshold_config != null ? [each.value.threshold_config] : []
    content {
      operator  = threshold_config.value.operator
      threshold = threshold_config.value.threshold
      units     = try(threshold_config.value.units, null)
    }
  }

  dynamic "metric_threshold_config" {
    for_each = each.value.metric_threshold_config != null ? [each.value.metric_threshold_config] : []
    content {
      metric_name = metric_threshold_config.value.metric_name
      operator    = metric_threshold_config.value.operator
      threshold   = metric_threshold_config.value.threshold
      units       = try(metric_threshold_config.value.units, null)
      mode        = try(metric_threshold_config.value.mode, null)
    }
  }
}
