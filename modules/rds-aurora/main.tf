/**
 * RDS Aurora Module
 * 
 * Creates:
 * - Aurora PostgreSQL cluster
 * - Primary instance
 * - Read replica instances (optional)
 * - DB subnet group
 * - Parameter groups
 * - Secrets Manager integration for credentials
 */

# Random password for database
resource "random_password" "master_password" {
  length  = 16
  special = true
}

# Store master password in Secrets Manager
resource "aws_secretsmanager_secret" "db_master_password" {
  name_prefix             = "${var.project_name}-${var.environment}-db-master-"
  description             = "Master password for RDS Aurora cluster"
  recovery_window_in_days = var.environment == "production" ? 30 : 0

  tags = var.common_tags
}

resource "aws_secretsmanager_secret_version" "db_master_password" {
  secret_id = aws_secretsmanager_secret.db_master_password.id
  secret_string = jsonencode({
    username = var.master_username
    password = random_password.master_password.result
    engine   = "aurora-postgresql"
    host     = aws_rds_cluster.main.endpoint
    port     = var.database_port
    dbname   = var.database_name
  })
}

# DB Subnet Group
resource "aws_db_subnet_group" "main" {
  name_prefix = "${var.project_name}-${var.environment}-"
  description = "Database subnet group for ${var.project_name} ${var.environment}"
  subnet_ids  = var.subnet_ids

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-db-subnet-group"
    }
  )
}

# RDS Cluster Parameter Group
resource "aws_rds_cluster_parameter_group" "main" {
  name_prefix = "${var.project_name}-${var.environment}-cluster-"
  family      = var.parameter_group_family
  description = "Cluster parameter group for ${var.project_name} ${var.environment}"

  # Enable query logging for non-production environments
  dynamic "parameter" {
    for_each = var.environment != "production" ? [1] : []
    content {
      name  = "log_statement"
      value = "all"
    }
  }

  parameter {
    name  = "shared_preload_libraries"
    value = "pg_stat_statements"
  }

  tags = var.common_tags

  lifecycle {
    create_before_destroy = true
  }
}

# DB Parameter Group
resource "aws_db_parameter_group" "main" {
  name_prefix = "${var.project_name}-${var.environment}-instance-"
  family      = var.parameter_group_family
  description = "DB parameter group for ${var.project_name} ${var.environment}"

  tags = var.common_tags

  lifecycle {
    create_before_destroy = true
  }
}

# RDS Aurora Cluster
resource "aws_rds_cluster" "main" {
  cluster_identifier     = "${var.project_name}-${var.environment}-aurora-cluster"
  engine                 = var.engine
  engine_version         = var.engine_version
  engine_mode            = var.engine_mode
  database_name          = var.database_name
  master_username        = var.master_username
  master_password        = random_password.master_password.result
  port                   = var.database_port
  
  # Networking
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.security_group_id]
  
  # Backup configuration
  backup_retention_period      = var.backup_retention_period
  preferred_backup_window      = var.preferred_backup_window
  preferred_maintenance_window = var.preferred_maintenance_window
  
  # High availability
  availability_zones = var.availability_zones
  
  # Encryption
  storage_encrypted = var.storage_encrypted
  kms_key_id        = var.kms_key_id
  
  # Parameter groups
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.main.name
  
  # Deletion protection
  deletion_protection = var.deletion_protection
  skip_final_snapshot = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${var.project_name}-${var.environment}-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"
  
  # Performance Insights
  enabled_cloudwatch_logs_exports = var.enabled_cloudwatch_logs_exports
  
  # Auto scaling configuration
  dynamic "serverlessv2_scaling_configuration" {
    for_each = var.engine_mode == "provisioned" && var.serverless_v2_scaling != null ? [var.serverless_v2_scaling] : []
    content {
      min_capacity = serverlessv2_scaling_configuration.value.min_capacity
      max_capacity = serverlessv2_scaling_configuration.value.max_capacity
    }
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-aurora-cluster"
    }
  )

  lifecycle {
    ignore_changes = [
      final_snapshot_identifier
    ]
  }
}

# Primary Aurora Instance
resource "aws_rds_cluster_instance" "primary" {
  identifier              = "${var.project_name}-${var.environment}-aurora-primary"
  cluster_identifier      = aws_rds_cluster.main.id
  instance_class          = var.instance_class
  engine                  = aws_rds_cluster.main.engine
  engine_version          = aws_rds_cluster.main.engine_version
  
  # Performance
  performance_insights_enabled    = var.performance_insights_enabled
  performance_insights_kms_key_id = var.performance_insights_kms_key_id
  performance_insights_retention_period = var.performance_insights_retention_period
  
  # Monitoring
  monitoring_interval = var.monitoring_interval
  monitoring_role_arn = var.monitoring_interval > 0 ? aws_iam_role.rds_monitoring[0].arn : null
  
  # Parameter group
  db_parameter_group_name = aws_db_parameter_group.main.name
  
  # Auto minor version upgrade
  auto_minor_version_upgrade = var.auto_minor_version_upgrade
  
  # Public accessibility
  publicly_accessible = false

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-aurora-primary"
    }
  )
}

# Read Replica Instances
resource "aws_rds_cluster_instance" "replica" {
  count              = var.replica_count
  identifier         = "${var.project_name}-${var.environment}-aurora-replica-${count.index + 1}"
  cluster_identifier = aws_rds_cluster.main.id
  instance_class     = var.replica_instance_class != null ? var.replica_instance_class : var.instance_class
  engine             = aws_rds_cluster.main.engine
  engine_version     = aws_rds_cluster.main.engine_version
  
  # Performance
  performance_insights_enabled    = var.performance_insights_enabled
  performance_insights_kms_key_id = var.performance_insights_kms_key_id
  performance_insights_retention_period = var.performance_insights_retention_period
  
  # Monitoring
  monitoring_interval = var.monitoring_interval
  monitoring_role_arn = var.monitoring_interval > 0 ? aws_iam_role.rds_monitoring[0].arn : null
  
  # Parameter group
  db_parameter_group_name = aws_db_parameter_group.main.name
  
  # Auto minor version upgrade
  auto_minor_version_upgrade = var.auto_minor_version_upgrade
  
  # Public accessibility
  publicly_accessible = false

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-aurora-replica-${count.index + 1}"
    }
  )
}

# IAM Role for Enhanced Monitoring
resource "aws_iam_role" "rds_monitoring" {
  count       = var.monitoring_interval > 0 ? 1 : 0
  name_prefix = "${var.project_name}-${var.environment}-rds-monitoring-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })

  tags = var.common_tags
}

# Attach Enhanced Monitoring Policy to Role
resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  count      = var.monitoring_interval > 0 ? 1 : 0
  role       = aws_iam_role.rds_monitoring[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# CloudWatch Alarms
resource "aws_cloudwatch_metric_alarm" "database_cpu" {
  count               = var.enable_cloudwatch_alarms ? 1 : 0
  alarm_name          = "${var.project_name}-${var.environment}-aurora-cpu-utilization"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = var.cpu_utilization_threshold
  alarm_description   = "This metric monitors RDS CPU utilization"
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBClusterIdentifier = aws_rds_cluster.main.cluster_identifier
  }

  tags = var.common_tags
}

resource "aws_cloudwatch_metric_alarm" "database_connections" {
  count               = var.enable_cloudwatch_alarms ? 1 : 0
  alarm_name          = "${var.project_name}-${var.environment}-aurora-connections"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = var.database_connections_threshold
  alarm_description   = "This metric monitors RDS database connections"
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBClusterIdentifier = aws_rds_cluster.main.cluster_identifier
  }

  tags = var.common_tags
}
