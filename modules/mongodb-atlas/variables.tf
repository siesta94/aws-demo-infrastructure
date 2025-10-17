/**
 * MongoDB Atlas Module Variables
 */

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, production)"
  type        = string
}

variable "create_project" {
  description = "Whether to create a new Atlas project or use an existing one"
  type        = bool
  default     = true
}

variable "atlas_org_id" {
  description = "MongoDB Atlas Organization ID"
  type        = string
  default     = ""
}

variable "existing_project_id" {
  description = "Existing Atlas project ID (used if create_project is false)"
  type        = string
  default     = ""
}

# Cluster Configuration
variable "cluster_type" {
  description = "Type of the cluster (REPLICASET, SHARDED, GEOSHARDED)"
  type        = string
  default     = "REPLICASET"
}

variable "instance_size" {
  description = "Atlas instance size (e.g., M10, M20, M30)"
  type        = string
  default     = "M10"
}

variable "node_count" {
  description = "Number of nodes in the cluster"
  type        = number
  default     = 3
}

variable "num_shards" {
  description = "Number of shards for sharded clusters"
  type        = number
  default     = 1
}

variable "mongodb_version" {
  description = "MongoDB major version"
  type        = string
  default     = "7.0"
}

variable "version_release_system" {
  description = "Release cadence that Atlas uses for this cluster (LTS or CONTINUOUS)"
  type        = string
  default     = "LTS"
}

variable "atlas_region" {
  description = "Atlas region name (e.g., US_EAST_1)"
  type        = string
  default     = "US_EAST_1"
}

# Analytics Nodes
variable "analytics_instance_size" {
  description = "Instance size for analytics nodes"
  type        = string
  default     = "M10"
}

variable "analytics_node_count" {
  description = "Number of analytics nodes"
  type        = number
  default     = 0
}

# Backup Configuration
variable "backup_enabled" {
  description = "Enable cloud backup for the cluster"
  type        = bool
  default     = true
}

variable "pit_enabled" {
  description = "Enable point-in-time restore"
  type        = bool
  default     = false
}

variable "backup_reference_hour_of_day" {
  description = "Hour of the day for backup snapshots (0-23)"
  type        = number
  default     = 3
}

variable "backup_reference_minute_of_hour" {
  description = "Minute of the hour for backup snapshots (0-59)"
  type        = number
  default     = 0
}

variable "backup_restore_window_days" {
  description = "Number of days to retain backups"
  type        = number
  default     = 7
}

variable "backup_policy_hourly" {
  description = "Hourly backup policy"
  type = object({
    frequency_interval = number
    retention_unit     = string
    retention_value    = number
  })
  default = null
}

variable "backup_policy_daily" {
  description = "Daily backup policy"
  type = object({
    frequency_interval = number
    retention_unit     = string
    retention_value    = number
  })
  default = {
    frequency_interval = 1
    retention_unit     = "days"
    retention_value    = 7
  }
}

variable "backup_policy_weekly" {
  description = "Weekly backup policy"
  type = object({
    frequency_interval = number
    retention_unit     = string
    retention_value    = number
  })
  default = {
    frequency_interval = 6
    retention_unit     = "weeks"
    retention_value    = 4
  }
}

variable "backup_policy_monthly" {
  description = "Monthly backup policy"
  type = object({
    frequency_interval = number
    retention_unit     = string
    retention_value    = number
  })
  default = {
    frequency_interval = 40
    retention_unit     = "months"
    retention_value    = 12
  }
}

# Security
variable "termination_protection_enabled" {
  description = "Enable termination protection"
  type        = bool
  default     = false
}

# Database Users
variable "database_users" {
  description = "Map of database users to create"
  type = map(object({
    username           = string
    password           = string
    auth_database_name = string
    roles = list(object({
      role_name     = string
      database_name = string
    }))
    scopes = list(object({
      name = string
      type = string
    }))
    labels = map(string)
  }))
  default = {}
}

# Network Access
variable "ip_whitelist" {
  description = "Map of IP addresses/CIDR blocks to whitelist"
  type = map(object({
    cidr_block = string
    comment    = string
  }))
  default = {}
}

# VPC Peering
variable "enable_vpc_peering" {
  description = "Enable VPC peering with AWS"
  type        = bool
  default     = false
}

variable "vpc_id" {
  description = "AWS VPC ID for peering"
  type        = string
  default     = ""
}

variable "aws_account_id" {
  description = "AWS Account ID"
  type        = string
  default     = ""
}

variable "aws_region" {
  description = "AWS region for PrivateLink"
  type        = string
  default     = "us-east-1"
}

variable "vpc_peering_route_table_cidr_block" {
  description = "AWS VPC CIDR block for route table"
  type        = string
  default     = ""
}

variable "atlas_cidr_block" {
  description = "Atlas CIDR block for network peering"
  type        = string
  default     = "192.168.248.0/21"
}

# PrivateLink
variable "enable_privatelink" {
  description = "Enable AWS PrivateLink"
  type        = bool
  default     = false
}

variable "aws_vpc_endpoint_service_id" {
  description = "AWS VPC Endpoint Service ID for PrivateLink"
  type        = string
  default     = ""
}

# Project Features
variable "enable_performance_advisor" {
  description = "Enable Performance Advisor"
  type        = bool
  default     = true
}

variable "enable_data_explorer" {
  description = "Enable Data Explorer"
  type        = bool
  default     = true
}

variable "enable_extended_storage_sizes" {
  description = "Enable extended storage sizes"
  type        = bool
  default     = false
}

variable "enable_realtime_performance_panel" {
  description = "Enable Real-time Performance Panel"
  type        = bool
  default     = true
}

variable "enable_schema_advisor" {
  description = "Enable Schema Advisor"
  type        = bool
  default     = true
}

# BI Connector
variable "bi_connector_enabled" {
  description = "Enable BI Connector"
  type        = bool
  default     = false
}

variable "bi_connector_read_preference" {
  description = "BI Connector read preference"
  type        = string
  default     = "secondary"
}

# Advanced Configuration
variable "advanced_configuration" {
  description = "Advanced cluster configuration options"
  type = object({
    fail_index_key_too_long              = optional(bool)
    javascript_enabled                   = optional(bool)
    minimum_enabled_tls_protocol         = optional(string)
    no_table_scan                        = optional(bool)
    oplog_size_mb                        = optional(number)
    sample_size_bi_connector             = optional(number)
    sample_refresh_interval_bi_connector = optional(number)
  })
  default = null
}

# Maintenance Window
variable "maintenance_window" {
  description = "Maintenance window configuration"
  type = object({
    day_of_week           = number
    hour_of_day           = number
    auto_defer_once_enabled = optional(bool)
  })
  default = null
}

# Auditing
variable "enable_auditing" {
  description = "Enable database auditing (requires M10+ cluster)"
  type        = bool
  default     = false
}

variable "audit_filter" {
  description = "JSON-formatted audit filter"
  type        = string
  default     = "{}"
}

variable "audit_authorization_success" {
  description = "Indicates whether successful authentication attempts should be audited"
  type        = bool
  default     = false
}

# Alert Configurations
variable "alert_configurations" {
  description = "Map of alert configurations"
  type = map(object({
    event_type = string
    enabled    = bool
    notifications = list(object({
      type_name     = string
      interval_min  = number
      delay_min     = number
      email_enabled = optional(bool)
      sms_enabled   = optional(bool)
      email_address = optional(string)
    }))
    threshold_config = optional(object({
      operator  = string
      threshold = number
      units     = optional(string)
    }))
    metric_threshold_config = optional(object({
      metric_name = string
      operator    = string
      threshold   = number
      units       = optional(string)
      mode        = optional(string)
    }))
  }))
  default = {}
}

# Tags
variable "atlas_tags" {
  description = "Additional tags for Atlas resources"
  type        = map(string)
  default     = {}
}
