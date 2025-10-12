/**
 * RDS Aurora Module Variables
 */

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, production)"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for the DB subnet group"
  type        = list(string)
}

variable "security_group_id" {
  description = "Security group ID for the RDS cluster"
  type        = string
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
}

variable "engine" {
  description = "Aurora database engine"
  type        = string
  default     = "aurora-postgresql"
}

variable "engine_version" {
  description = "Aurora database engine version"
  type        = string
  default     = "15.4"
}

variable "engine_mode" {
  description = "The database engine mode (provisioned, serverless, parallelquery, global)"
  type        = string
  default     = "provisioned"
}

variable "database_name" {
  description = "Name of the database to create"
  type        = string
  default     = "appdb"
}

variable "database_port" {
  description = "Port on which the database accepts connections"
  type        = number
  default     = 5432
}

variable "master_username" {
  description = "Master username for the database"
  type        = string
  default     = "dbadmin"
}

variable "instance_class" {
  description = "Instance class for primary instance"
  type        = string
  default     = "db.r6g.large"
}

variable "replica_count" {
  description = "Number of read replica instances to create"
  type        = number
  default     = 0
}

variable "replica_instance_class" {
  description = "Instance class for replica instances (defaults to instance_class if not set)"
  type        = string
  default     = null
}

variable "parameter_group_family" {
  description = "Database parameter group family"
  type        = string
  default     = "aurora-postgresql15"
}

variable "backup_retention_period" {
  description = "Number of days to retain backups"
  type        = number
  default     = 7
}

variable "preferred_backup_window" {
  description = "Daily time range for backups (UTC)"
  type        = string
  default     = "03:00-04:00"
}

variable "preferred_maintenance_window" {
  description = "Weekly time range for maintenance (UTC)"
  type        = string
  default     = "sun:04:00-sun:05:00"
}

variable "storage_encrypted" {
  description = "Enable storage encryption"
  type        = bool
  default     = true
}

variable "kms_key_id" {
  description = "KMS key ID for encryption (uses default if not provided)"
  type        = string
  default     = null
}

variable "deletion_protection" {
  description = "Enable deletion protection"
  type        = bool
  default     = true
}

variable "skip_final_snapshot" {
  description = "Skip final snapshot when destroying cluster"
  type        = bool
  default     = false
}

variable "performance_insights_enabled" {
  description = "Enable Performance Insights"
  type        = bool
  default     = true
}

variable "performance_insights_kms_key_id" {
  description = "KMS key ID for Performance Insights encryption"
  type        = string
  default     = null
}

variable "performance_insights_retention_period" {
  description = "Performance Insights retention period in days"
  type        = number
  default     = 7
}

variable "monitoring_interval" {
  description = "Enhanced monitoring interval in seconds (0, 1, 5, 10, 15, 30, 60)"
  type        = number
  default     = 60
}

variable "auto_minor_version_upgrade" {
  description = "Enable automatic minor version upgrades"
  type        = bool
  default     = true
}

variable "enabled_cloudwatch_logs_exports" {
  description = "List of log types to export to CloudWatch"
  type        = list(string)
  default     = ["postgresql"]
}

variable "serverless_v2_scaling" {
  description = "Serverless v2 scaling configuration"
  type = object({
    min_capacity = number
    max_capacity = number
  })
  default = null
}

variable "enable_cloudwatch_alarms" {
  description = "Enable CloudWatch alarms for monitoring"
  type        = bool
  default     = true
}

variable "cpu_utilization_threshold" {
  description = "CPU utilization threshold for CloudWatch alarm"
  type        = number
  default     = 80
}

variable "database_connections_threshold" {
  description = "Database connections threshold for CloudWatch alarm"
  type        = number
  default     = 100
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
