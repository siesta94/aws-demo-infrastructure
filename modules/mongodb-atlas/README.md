# MongoDB Atlas Module

This Terraform module creates a production-ready MongoDB Atlas cluster with comprehensive security, backup, and monitoring features integrated with AWS infrastructure.

## Features

- **Managed MongoDB Cluster**: Fully managed MongoDB database with auto-scaling
- **Multi-Region Support**: Deploy across multiple AWS regions for high availability
- **VPC Peering**: Secure private connection between Atlas and AWS VPC
- **AWS PrivateLink**: Private connectivity without VPC peering
- **Database Users**: Flexible user management with role-based access control
- **IP Whitelisting**: Network access control
- **Automated Backups**: Point-in-time recovery and scheduled snapshots
- **Monitoring & Alerts**: Built-in performance monitoring and alerting
- **Security**: Encryption at rest and in transit, auditing capabilities
- **Analytics Nodes**: Dedicated nodes for analytics workloads

## Prerequisites

1. **MongoDB Atlas Account**: You need a MongoDB Atlas organization
2. **MongoDB Atlas API Keys**: Create programmatic API keys in Atlas
3. **Terraform MongoDB Atlas Provider**: Module uses `mongodbatlas` provider

### Setting Up Atlas API Keys

1. Log in to MongoDB Atlas
2. Go to Organization Settings → Access Manager → API Keys
3. Create API Key with "Organization Project Creator" permissions
4. Note the Public and Private keys

### Provider Configuration

Add to your `provider.tf`:

```hcl
terraform {
  required_providers {
    mongodbatlas = {
      source  = "mongodb/mongodbatlas"
      version = "~> 1.15"
    }
  }
}

provider "mongodbatlas" {
  public_key  = var.mongodb_atlas_public_key
  private_key = var.mongodb_atlas_private_key
}
```

## Usage

### Basic Example

```hcl
module "mongodb_atlas" {
  source = "../../modules/mongodb-atlas"

  project_name  = "myapp"
  environment   = "dev"
  atlas_org_id  = "5f2e3a1b2c4d5e6f7a8b9c0d"
  
  # Cluster Configuration
  instance_size   = "M10"
  node_count      = 3
  atlas_region    = "US_EAST_1"
  mongodb_version = "7.0"
  
  # Database Users
  database_users = {
    app_user = {
      username           = "appuser"
      password           = "SecurePassword123!"
      auth_database_name = "admin"
      roles = [
        {
          role_name     = "readWrite"
          database_name = "myapp_db"
        }
      ]
      scopes = []
      labels = {}
    }
  }
  
  # IP Whitelist
  ip_whitelist = {
    office = {
      cidr_block = "203.0.113.0/24"
      comment    = "Office network"
    }
  }
}
```

### Production Example with VPC Peering

```hcl
module "mongodb_atlas" {
  source = "../../modules/mongodb-atlas"

  project_name  = "myapp"
  environment   = "production"
  atlas_org_id  = "5f2e3a1b2c4d5e6f7a8b9c0d"
  
  # Cluster Configuration
  cluster_type    = "REPLICASET"
  instance_size   = "M30"
  node_count      = 3
  atlas_region    = "US_EAST_1"
  mongodb_version = "7.0"
  
  # Enable backups
  backup_enabled = true
  pit_enabled    = true
  
  # Termination protection
  termination_protection_enabled = true
  
  # VPC Peering with AWS
  enable_vpc_peering = true
  vpc_id             = module.vpc.vpc_id
  aws_account_id     = "123456789012"
  aws_region         = "us-east-1"
  atlas_cidr_block   = "192.168.248.0/21"
  vpc_peering_route_table_cidr_block = "10.0.0.0/16"
  
  # Database Users
  database_users = {
    admin_user = {
      username           = "admin"
      password           = var.mongodb_admin_password
      auth_database_name = "admin"
      roles = [
        {
          role_name     = "atlasAdmin"
          database_name = "admin"
        }
      ]
      scopes = []
      labels = {
        Type = "admin"
      }
    }
    
    app_user = {
      username           = "appuser"
      password           = var.mongodb_app_password
      auth_database_name = "admin"
      roles = [
        {
          role_name     = "readWrite"
          database_name = "production_db"
        }
      ]
      scopes = [
        {
          name = "${var.project_name}-${var.environment}-cluster"
          type = "CLUSTER"
        }
      ]
      labels = {
        Type = "application"
      }
    }
    
    readonly_user = {
      username           = "readonly"
      password           = var.mongodb_readonly_password
      auth_database_name = "admin"
      roles = [
        {
          role_name     = "read"
          database_name = "production_db"
        }
      ]
      scopes = []
      labels = {
        Type = "readonly"
      }
    }
  }
  
  # Maintenance Window (Sunday 3 AM UTC)
  maintenance_window = {
    day_of_week           = 1
    hour_of_day           = 3
    auto_defer_once_enabled = true
  }
  
  # Backup Policy
  backup_reference_hour_of_day    = 3
  backup_reference_minute_of_hour = 0
  backup_restore_window_days      = 7
  
  backup_policy_daily = {
    frequency_interval = 1
    retention_unit     = "days"
    retention_value    = 7
  }
  
  backup_policy_weekly = {
    frequency_interval = 6
    retention_unit     = "weeks"
    retention_value    = 4
  }
  
  backup_policy_monthly = {
    frequency_interval = 40
    retention_unit     = "months"
    retention_value    = 12
  }
  
  # Alerts
  alert_configurations = {
    high_connections = {
      event_type = "OUTSIDE_METRIC_THRESHOLD"
      enabled    = true
      notifications = [
        {
          type_name     = "EMAIL"
          interval_min  = 5
          delay_min     = 0
          email_enabled = true
          email_address = "alerts@example.com"
          sms_enabled   = false
        }
      ]
      metric_threshold_config = {
        metric_name = "CONNECTIONS"
        operator    = "GREATER_THAN"
        threshold   = 1000
        units       = "RAW"
        mode        = "AVERAGE"
      }
      threshold_config = null
    }
  }
  
  atlas_tags = {
    CostCenter = "Engineering"
    Compliance = "PCI"
  }
}
```

### Multi-Region Cluster

```hcl
module "mongodb_atlas_global" {
  source = "../../modules/mongodb-atlas"

  project_name  = "myapp"
  environment   = "production"
  atlas_org_id  = "5f2e3a1b2c4d5e6f7a8b9c0d"
  
  cluster_type    = "GEOSHARDED"
  instance_size   = "M30"
  node_count      = 3
  atlas_region    = "US_EAST_1"
  
  # Additional regions for global deployment
  additional_regions = [
    {
      region_name              = "EU_WEST_1"
      instance_size            = "M30"
      node_count               = 3
      analytics_instance_size  = "M30"
      analytics_node_count     = 1
      priority                 = 6
    },
    {
      region_name              = "AP_SOUTHEAST_1"
      instance_size            = "M30"
      node_count               = 3
      analytics_instance_size  = "M30"
      analytics_node_count     = 1
      priority                 = 5
    }
  ]
  
  # Analytics nodes in primary region
  analytics_instance_size = "M30"
  analytics_node_count    = 1
}
```

## Connecting to Your Cluster

After deployment, use the connection strings from outputs:

```bash
# Get connection string
terraform output -raw connection_string

# Connect with mongo shell
mongo "mongodb+srv://cluster-name.mongodb.net/mydb" --username appuser

# Connection string format for applications
mongodb+srv://appuser:password@cluster-name.mongodb.net/mydb?retryWrites=true&w=majority
```

## VPC Peering Setup

When `enable_vpc_peering = true`, additional AWS resources are needed:

```hcl
# Accept VPC peering connection in AWS
resource "aws_vpc_peering_connection_accepter" "atlas" {
  vpc_peering_connection_id = module.mongodb_atlas.vpc_peering_connection_id
  auto_accept               = true

  tags = {
    Name = "Atlas VPC Peering"
  }
}

# Add route to Atlas CIDR in your route tables
resource "aws_route" "atlas_peering" {
  route_table_id            = module.vpc.private_route_table_ids[0]
  destination_cidr_block    = module.mongodb_atlas.network_container_atlas_cidr_block
  vpc_peering_connection_id = module.mongodb_atlas.vpc_peering_connection_id
}
```

## AWS PrivateLink Setup

For PrivateLink connectivity:

1. Create VPC Endpoint in AWS:
```hcl
resource "aws_vpc_endpoint" "atlas" {
  vpc_id             = module.vpc.vpc_id
  service_name       = module.mongodb_atlas.privatelink_endpoint_service_name
  vpc_endpoint_type  = "Interface"
  subnet_ids         = module.vpc.private_subnet_ids
  security_group_ids = [aws_security_group.atlas_privatelink.id]
}
```

2. Pass the endpoint service ID to the module:
```hcl
module "mongodb_atlas" {
  # ... other configuration
  enable_privatelink            = true
  aws_vpc_endpoint_service_id   = aws_vpc_endpoint.atlas.id
}
```

## Instance Sizes

Choose the right instance size for your workload:

| Size | RAM | Storage | Use Case |
|------|-----|---------|----------|
| M0   | Shared | 512MB | Development/Testing |
| M2   | Shared | 2GB | Small apps |
| M5   | Shared | 5GB | Small production |
| M10  | 2GB | 10GB | Entry production |
| M20  | 4GB | 20GB | Standard production |
| M30  | 8GB | 40GB | Medium production |
| M40  | 16GB | 80GB | Large production |
| M50  | 32GB | 160GB | Very large production |
| M60+ | 64GB+ | 320GB+ | Enterprise scale |

## Atlas Regions

Common Atlas region names (AWS):

- `US_EAST_1` - Virginia
- `US_EAST_2` - Ohio
- `US_WEST_1` - N. California
- `US_WEST_2` - Oregon
- `EU_WEST_1` - Ireland
- `EU_CENTRAL_1` - Frankfurt
- `AP_SOUTHEAST_1` - Singapore
- `AP_SOUTHEAST_2` - Sydney

## Database User Roles

Common MongoDB roles:

- `read` - Read data on non-system collections
- `readWrite` - Read and write data on non-system collections
- `dbAdmin` - Database administration operations
- `userAdmin` - User and role management
- `clusterAdmin` - Cluster administration
- `atlasAdmin` - Full Atlas administration

## Security Best Practices

1. **Never commit passwords**: Use Terraform variables or secrets managers
2. **Restrict IP Access**: Only whitelist necessary IPs/CIDR blocks
3. **Use VPC Peering or PrivateLink**: Avoid public internet access
4. **Enable Encryption**: Always use TLS 1.2 or higher
5. **Enable Auditing**: Track database access (M10+)
6. **Regular Backups**: Enable pit_enabled for point-in-time recovery
7. **Least Privilege**: Grant minimum required permissions to users
8. **Maintenance Windows**: Schedule during low-traffic periods

## Monitoring and Alerts

### Common Alert Types

- `OUTSIDE_METRIC_THRESHOLD` - Metric exceeds threshold
- `HOST_DOWN` - Host is unreachable
- `REPLICA_SET_ELECTION_FAILED` - Primary election failed
- `CLUSTER_MONGOS_IS_MISSING` - Mongos process missing

### Alert Metrics

- `CONNECTIONS` - Number of connections
- `DISK_PARTITION_SPACE_USED` - Disk usage
- `MEMORY_RESIDENT` - Resident memory
- `OPCOUNTER_REPL_CMD` - Replication operations
- `QUERY_TARGETING_SCANNED_OBJECTS_PER_RETURNED` - Query efficiency

## Backup and Recovery

### Backup Policies

- **Hourly**: For critical data requiring minimal RPO
- **Daily**: Standard production backup
- **Weekly**: Long-term retention
- **Monthly**: Compliance and archival

### Restore Process

1. Go to Atlas Console → Clusters → Backup
2. Select snapshot or point-in-time
3. Choose restore method (download or restore to cluster)
4. Confirm and initiate restore

## Cost Optimization

1. **Right-size Instances**: Start with M10, scale as needed
2. **Use Analytics Nodes**: Separate reporting workloads
3. **Optimize Backup Retention**: Balance compliance with costs
4. **Monitor Storage Growth**: Plan for data lifecycle
5. **Consider Reserved Capacity**: For long-term deployments
6. **Use Appropriate Regions**: Balance latency vs. cost

## Troubleshooting

### Connection Issues

1. Check IP whitelist
2. Verify VPC peering/PrivateLink status
3. Confirm user credentials
4. Check security group rules (for VPC peering)

### Performance Issues

1. Review Performance Advisor recommendations
2. Check index usage
3. Monitor connection pool settings
4. Review query patterns
5. Consider adding analytics nodes

### High Storage Usage

1. Check collection sizes
2. Review index sizes
3. Implement data archival strategy
4. Consider data lifecycle policies

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| project_name | Name of the project | string | - | yes |
| environment | Environment name | string | - | yes |
| atlas_org_id | MongoDB Atlas Organization ID | string | "" | conditional |
| instance_size | Atlas instance size | string | "M10" | no |
| node_count | Number of nodes | number | 3 | no |
| atlas_region | Atlas region name | string | "US_EAST_1" | no |
| enable_vpc_peering | Enable VPC peering | bool | false | no |
| database_users | Map of database users | map(object) | {} | no |

See `variables.tf` for complete list.

## Outputs

| Name | Description |
|------|-------------|
| cluster_id | The ID of the Atlas cluster |
| connection_strings | Connection strings (sensitive) |
| project_id | The ID of the Atlas project |
| vpc_peering_connection_id | VPC peering connection ID |
| cluster_summary | Summary of cluster configuration |

See `outputs.tf` for complete list.

## Examples

See the root `MONGODB_ATLAS_USAGE_GUIDE.md` for comprehensive examples and usage patterns.

## License

MIT License
