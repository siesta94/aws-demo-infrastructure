# MongoDB Atlas Usage Guide

This guide provides comprehensive instructions for deploying and managing MongoDB Atlas clusters using the mongodb-atlas module in this infrastructure repository.

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Getting Started](#getting-started)
- [Configuration Examples](#configuration-examples)
- [Database Users and Roles](#database-users-and-roles)
- [Network Configuration](#network-configuration)
- [Backup and Recovery](#backup-and-recovery)
- [Monitoring and Alerts](#monitoring-and-alerts)
- [Security Best Practices](#security-best-practices)
- [Performance Optimization](#performance-optimization)
- [Connecting Applications](#connecting-applications)
- [Troubleshooting](#troubleshooting)
- [Cost Management](#cost-management)

## Overview

MongoDB Atlas is a fully managed cloud database service that handles all the complexity of deploying, managing, and healing deployments on the cloud provider of your choice. This module provides Terraform automation for:

- Creating and managing Atlas projects
- Deploying MongoDB clusters (replica sets, sharded clusters, global clusters)
- Configuring database users with role-based access control
- Setting up network security (IP whitelisting, VPC peering, PrivateLink)
- Automated backup and point-in-time recovery
- Performance monitoring and alerting
- Integration with AWS infrastructure

## Prerequisites

### 1. MongoDB Atlas Account

Create a MongoDB Atlas account at https://www.mongodb.com/cloud/atlas/register

### 2. Create an Organization

1. Log in to MongoDB Atlas
2. Create an organization (if you don't have one)
3. Note your Organization ID (found in Organization Settings)

### 3. Generate API Keys

1. Go to Organization Settings → Access Manager → API Keys
2. Click "Create API Key"
3. Name: `terraform-automation`
4. Permissions: Select "Organization Project Creator"
5. Click "Next"
6. **Save the Public Key and Private Key** - you won't see the private key again!
7. Add your IP to the Access List for the API key

### 4. Configure Terraform Provider

Create or update `environments/dev/provider.tf`:

```hcl
terraform {
  required_providers {
    mongodbatlas = {
      source  = "mongodb/mongodbatlas"
      version = "~> 1.15"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "mongodbatlas" {
  public_key  = var.mongodb_atlas_public_key
  private_key = var.mongodb_atlas_private_key
}

provider "aws" {
  region = var.aws_region
}
```

### 5. Store Credentials Securely

Never commit API keys to version control! Use environment variables:

```bash
export TF_VAR_mongodb_atlas_public_key="your-public-key"
export TF_VAR_mongodb_atlas_private_key="your-private-key"
```

Or use AWS Secrets Manager:

```hcl
data "aws_secretsmanager_secret_version" "atlas_keys" {
  secret_id = "mongodb-atlas-api-keys"
}

locals {
  atlas_keys = jsondecode(data.aws_secretsmanager_secret_version.atlas_keys.secret_string)
}

provider "mongodbatlas" {
  public_key  = local.atlas_keys.public_key
  private_key = local.atlas_keys.private_key
}
```

## Getting Started

### Basic Development Cluster

Create a simple cluster for development:

```hcl
# environments/dev/main.tf

module "mongodb_atlas" {
  source = "../../modules/mongodb-atlas"

  project_name = local.project_name
  environment  = local.environment
  
  # Your Atlas Organization ID
  atlas_org_id = "60a1234567890abcdef12345"
  
  # Cluster configuration
  instance_size   = "M10"          # Smallest production-ready instance
  node_count      = 3              # 3-node replica set
  atlas_region    = "US_EAST_1"    # Virginia region
  mongodb_version = "7.0"
  
  # Create a database user
  database_users = {
    dev_user = {
      username           = "devuser"
      password           = var.mongodb_dev_password  # Store in terraform.tfvars or env var
      auth_database_name = "admin"
      roles = [
        {
          role_name     = "readWrite"
          database_name = "myapp_dev"
        }
      ]
      scopes = []
      labels = {}
    }
  }
  
  # Allow access from your IP
  ip_whitelist = {
    development = {
      cidr_block = "203.0.113.0/24"  # Your office/VPN IP
      comment    = "Development access"
    }
  }
}

# Output the connection string
output "mongodb_connection_string" {
  value     = module.mongodb_atlas.connection_strings.standard_srv
  sensitive = true
}
```

### Deploy

```bash
cd environments/dev
terraform init
terraform plan
terraform apply

# Get the connection string
terraform output -raw mongodb_connection_string
```

## Configuration Examples

### Production Cluster with VPC Peering

```hcl
module "mongodb_atlas_prod" {
  source = "../../modules/mongodb-atlas"

  project_name = local.project_name
  environment  = "production"
  atlas_org_id = "60a1234567890abcdef12345"
  
  # Production-grade cluster
  instance_size   = "M30"
  node_count      = 3
  atlas_region    = "US_EAST_1"
  mongodb_version = "7.0"
  
  # Enable backups
  backup_enabled = true
  pit_enabled    = true
  
  # Protect from accidental deletion
  termination_protection_enabled = true
  
  # VPC Peering for private connectivity
  enable_vpc_peering                 = true
  vpc_id                             = module.vpc.vpc_id
  aws_account_id                     = data.aws_caller_identity.current.account_id
  aws_region                         = "us-east-1"
  atlas_cidr_block                   = "192.168.248.0/21"
  vpc_peering_route_table_cidr_block = module.vpc.vpc_cidr_block
  
  # Database users
  database_users = {
    admin = {
      username           = "prodadmin"
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
    
    application = {
      username           = "appuser"
      password           = var.mongodb_app_password
      auth_database_name = "admin"
      roles = [
        {
          role_name     = "readWrite"
          database_name = "production"
        }
      ]
      scopes = [
        {
          name = "${local.project_name}-production-cluster"
          type = "CLUSTER"
        }
      ]
      labels = {
        Type = "application"
      }
    }
    
    analytics = {
      username           = "analytics"
      password           = var.mongodb_analytics_password
      auth_database_name = "admin"
      roles = [
        {
          role_name     = "read"
          database_name = "production"
        }
      ]
      scopes = []
      labels = {
        Type = "analytics"
      }
    }
  }
  
  # Maintenance window (Sunday 3 AM)
  maintenance_window = {
    day_of_week           = 1
    hour_of_day           = 3
    auto_defer_once_enabled = true
  }
  
  # Comprehensive backup policy
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
  
  # Monitoring alerts
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
          email_address = "ops-team@example.com"
          sms_enabled   = false
        }
      ]
      metric_threshold_config = {
        metric_name = "CONNECTIONS"
        operator    = "GREATER_THAN"
        threshold   = 1500
        units       = "RAW"
        mode        = "AVERAGE"
      }
      threshold_config = null
    }
    
    disk_usage = {
      event_type = "OUTSIDE_METRIC_THRESHOLD"
      enabled    = true
      notifications = [
        {
          type_name     = "EMAIL"
          interval_min  = 60
          delay_min     = 0
          email_enabled = true
          email_address = "ops-team@example.com"
          sms_enabled   = false
        }
      ]
      metric_threshold_config = {
        metric_name = "DISK_PARTITION_SPACE_USED_DATA"
        operator    = "GREATER_THAN"
        threshold   = 80
        units       = "RAW"
        mode        = "AVERAGE"
      }
      threshold_config = null
    }
    
    replica_set_election = {
      event_type = "REPLICA_SET_ELECTION_FAILED"
      enabled    = true
      notifications = [
        {
          type_name     = "EMAIL"
          interval_min  = 5
          delay_min     = 0
          email_enabled = true
          email_address = "ops-team@example.com"
          sms_enabled   = true
        }
      ]
      threshold_config      = null
      metric_threshold_config = null
    }
  }
}

# AWS resources for VPC peering
resource "aws_vpc_peering_connection_accepter" "atlas" {
  vpc_peering_connection_id = module.mongodb_atlas_prod.vpc_peering_connection_id
  auto_accept               = true

  tags = {
    Name = "MongoDB Atlas VPC Peering"
  }
}

resource "aws_route" "atlas_peering" {
  count = length(module.vpc.private_route_table_ids)
  
  route_table_id            = module.vpc.private_route_table_ids[count.index]
  destination_cidr_block    = module.mongodb_atlas_prod.network_container_atlas_cidr_block
  vpc_peering_connection_id = module.mongodb_atlas_prod.vpc_peering_connection_id
  
  depends_on = [aws_vpc_peering_connection_accepter.atlas]
}
```

### Multi-Region Global Cluster

```hcl
module "mongodb_atlas_global" {
  source = "../../modules/mongodb-atlas"

  project_name = "globalapp"
  environment  = "production"
  atlas_org_id = "60a1234567890abcdef12345"
  
  # Global cluster configuration
  cluster_type    = "GEOSHARDED"
  instance_size   = "M30"
  node_count      = 3
  atlas_region    = "US_EAST_1"
  
  # Additional regions
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
  
  database_users = {
    global_app = {
      username           = "globalapp"
      password           = var.mongodb_global_password
      auth_database_name = "admin"
      roles = [
        {
          role_name     = "readWrite"
          database_name = "global_data"
        }
      ]
      scopes = []
      labels = {}
    }
  }
}
```

## Database Users and Roles

### Built-in Roles

**Read Roles:**
- `read` - Read any database except config and local
- `readAnyDatabase` - Read all databases

**Read-Write Roles:**
- `readWrite` - Read and write to any database except config and local
- `readWriteAnyDatabase` - Read and write to all databases

**Database Administration:**
- `dbAdmin` - Database administration tasks
- `dbAdminAnyDatabase` - Database administration on all databases
- `userAdmin` - Create and modify users and roles
- `userAdminAnyDatabase` - User administration on all databases

**Cluster Administration:**
- `clusterAdmin` - Cluster administration
- `clusterManager` - Monitor and manage cluster
- `clusterMonitor` - Read-only access to monitoring tools
- `hostManager` - Monitor and manage servers

**Backup and Restore:**
- `backup` - Backup data
- `restore` - Restore data

**Atlas-Specific:**
- `atlasAdmin` - Full Atlas administration (includes billing)
- `enableSharding` - Enable sharding on a database

### Creating Custom Roles

```hcl
database_users = {
  custom_role_user = {
    username           = "customuser"
    password           = var.password
    auth_database_name = "admin"
    roles = [
      # Read from one database
      {
        role_name     = "read"
        database_name = "analytics"
      },
      # Write to another database
      {
        role_name     = "readWrite"
        database_name = "application"
      },
      # Admin on specific database
      {
        role_name     = "dbAdmin"
        database_name = "application"
      }
    ]
    # Scope to specific cluster
    scopes = [
      {
        name = "myapp-production-cluster"
        type = "CLUSTER"
      }
    ]
    labels = {
      Team = "Backend"
      Purpose = "Application"
    }
  }
}
```

## Network Configuration

### IP Whitelisting

```hcl
ip_whitelist = {
  office_hq = {
    cidr_block = "203.0.113.0/24"
    comment    = "Office HQ"
  }
  
  office_branch = {
    cidr_block = "198.51.100.0/24"
    comment    = "Branch Office"
  }
  
  vpn = {
    cidr_block = "192.0.2.0/24"
    comment    = "VPN Users"
  }
  
  # Allow from anywhere (NOT recommended for production)
  everywhere = {
    cidr_block = "0.0.0.0/0"
    comment    = "Temporary - Remove before production"
  }
}
```

### VPC Peering

VPC Peering creates a private connection between your AWS VPC and MongoDB Atlas:

1. **Configure in Terraform:**

```hcl
module "mongodb_atlas" {
  # ... other config
  
  enable_vpc_peering = true
  vpc_id             = module.vpc.vpc_id
  aws_account_id     = data.aws_caller_identity.current.account_id
  aws_region         = "us-east-1"
  atlas_cidr_block   = "192.168.248.0/21"
  vpc_peering_route_table_cidr_block = "10.0.0.0/16"
}
```

2. **Accept the Peering Connection:**

```hcl
resource "aws_vpc_peering_connection_accepter" "atlas" {
  vpc_peering_connection_id = module.mongodb_atlas.vpc_peering_connection_id
  auto_accept               = true
}
```

3. **Update Route Tables:**

```hcl
resource "aws_route" "atlas" {
  for_each = toset(module.vpc.private_route_table_ids)
  
  route_table_id            = each.value
  destination_cidr_block    = module.mongodb_atlas.network_container_atlas_cidr_block
  vpc_peering_connection_id = module.mongodb_atlas.vpc_peering_connection_id
}
```

4. **Update Security Groups:**

```hcl
resource "aws_security_group_rule" "allow_mongodb" {
  type              = "egress"
  from_port         = 27017
  to_port           = 27017
  protocol          = "tcp"
  cidr_blocks       = [module.mongodb_atlas.network_container_atlas_cidr_block]
  security_group_id = aws_security_group.app.id
  description       = "MongoDB Atlas"
}
```

### AWS PrivateLink

PrivateLink provides private connectivity without VPC peering:

```hcl
# Step 1: Enable PrivateLink in Atlas module
module "mongodb_atlas" {
  # ... other config
  enable_privatelink = true
  aws_region         = "us-east-1"
}

# Step 2: Create VPC Endpoint
resource "aws_vpc_endpoint" "atlas" {
  vpc_id             = module.vpc.vpc_id
  service_name       = module.mongodb_atlas.privatelink_endpoint_service_name
  vpc_endpoint_type  = "Interface"
  subnet_ids         = module.vpc.private_subnet_ids
  
  security_group_ids = [aws_security_group.atlas_privatelink.id]
  
  private_dns_enabled = true
}

# Step 3: Security group for PrivateLink
resource "aws_security_group" "atlas_privatelink" {
  name        = "atlas-privatelink"
  description = "MongoDB Atlas PrivateLink"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 27017
    to_port     = 27017
    protocol    = "tcp"
    cidr_blocks = [module.vpc.vpc_cidr_block]
  }
}

# Step 4: Update module with VPC endpoint ID
module "mongodb_atlas" {
  # ... other config
  enable_privatelink            = true
  aws_vpc_endpoint_service_id   = aws_vpc_endpoint.atlas.id
}
```

## Backup and Recovery

### Backup Configuration

```hcl
module "mongodb_atlas" {
  # ... other config
  
  # Enable cloud backups
  backup_enabled = true
  
  # Enable point-in-time restore (requires M10+)
  pit_enabled    = true
  
  # Backup schedule (3 AM UTC)
  backup_reference_hour_of_day    = 3
  backup_reference_minute_of_hour = 0
  backup_restore_window_days      = 7
  
  # Retention policies
  backup_policy_daily = {
    frequency_interval = 1      # Every day
    retention_unit     = "days"
    retention_value    = 7      # Keep for 7 days
  }
  
  backup_policy_weekly = {
    frequency_interval = 6      # Every Sunday (day 1)
    retention_unit     = "weeks"
    retention_value    = 4      # Keep for 4 weeks
  }
  
  backup_policy_monthly = {
    frequency_interval = 40     # On the 1st
    retention_unit     = "months"
    retention_value    = 12     # Keep for 12 months
  }
}
```

### Restoring from Backup

1. **Via Atlas Console:**
   - Go to Clusters → Select cluster → Backup
   - Choose snapshot or point-in-time
   - Select restore method
   - Download or restore to new/existing cluster

2. **Via Terraform (restore to new cluster):**

```hcl
resource "mongodbatlas_cloud_backup_snapshot_restore_job" "restore" {
  project_id   = module.mongodb_atlas.project_id
  cluster_name = module.mongodb_atlas.cluster_name
  snapshot_id  = "5f4007f44787531 def8c0" # From Atlas console

  delivery_type_config {
    automated = true
    target_cluster_name = "restored-cluster"
    target_project_id   = module.mongodb_atlas.project_id
  }
}
```

## Monitoring and Alerts

### Setting Up Alerts

```hcl
alert_configurations = {
  # Connection spike
  connection_spike = {
    event_type = "OUTSIDE_METRIC_THRESHOLD"
    enabled    = true
    notifications = [
      {
        type_name     = "EMAIL"
        interval_min  = 5
        delay_min     = 0
        email_enabled = true
        email_address = "ops@example.com"
        sms_enabled   = false
      }
    ]
    metric_threshold_config = {
      metric_name = "CONNECTIONS"
      operator    = "GREATER_THAN"
      threshold   = 2000
      units       = "RAW"
      mode        = "AVERAGE"
    }
    threshold_config = null
  }
  
  # High CPU
  high_cpu = {
    event_type = "OUTSIDE_METRIC_THRESHOLD"
    enabled    = true
    notifications = [
      {
        type_name     = "EMAIL"
        interval_min  = 10
        delay_min     = 5
        email_enabled = true
        email_address = "ops@example.com"
        sms_enabled   = false
      }
    ]
    metric_threshold_config = {
      metric_name = "SYSTEM_CPU_USER"
      operator    = "GREATER_THAN"
      threshold   = 80
      units       = "RAW"
      mode        = "AVERAGE"
    }
    threshold_config = null
  }
  
  # Replication lag
  replication_lag = {
    event_type = "OUTSIDE_METRIC_THRESHOLD"
    enabled    = true
    notifications = [
      {
        type_name     = "EMAIL"
        interval_min  = 5
        delay_min     = 0
        email_enabled = true
        email_address = "ops@example.com"
        sms_enabled   = true
      }
    ]
    metric_threshold_config = {
      metric_name = "OPLOG_SLAVE_LAG_MASTER_TIME"
      operator    = "GREATER_THAN"
      threshold   = 10
      units       = "SECONDS"
      mode        = "AVERAGE"
    }
    threshold_config = null
  }
}
```

## Security Best Practices

1. **Use Strong Passwords:**
```hcl
# Generate secure passwords
resource "random_password" "mongodb" {
  length  = 32
  special = true
}

# Store in AWS Secrets Manager
resource "aws_secretsmanager_secret" "mongodb_password" {
  name = "mongodb-app-password"
}

resource "aws_secretsmanager_secret_version" "mongodb_password" {
  secret_id     = aws_secretsmanager_secret.mongodb_password.id
  secret_string = random_password.mongodb.result
}
```

2. **Enable Auditing (M10+):**
```hcl
enable_auditing                = true
audit_authorization_success    = false
audit_filter                   = jsonencode({
  atype = "authenticate"
  "param.user" = { "$in" = ["admin", "prodadmin"] }
})
```

3. **Use TLS 1.2+:**
```hcl
advanced_configuration = {
  minimum_enabled_tls_protocol = "TLS1_2"
}
```

4. **Limit Network Access:**
- Use VPC peering or PrivateLink
- Restrict IP whitelist to known IPs
- Never use 0.0.0.0/0 in production

5. **Role-Based Access Control:**
- Grant least privilege
- Use scopes to limit user access to specific clusters
- Rotate passwords regularly

## Connecting Applications

### Node.js Example

```javascript
const { MongoClient } = require('mongodb');

const uri = process.env.MONGODB_URI;
const client = new MongoClient(uri, {
  useNewUrlParser: true,
  useUnifiedTopology: true,
  maxPoolSize: 50,
  wtimeoutMS: 2500,
  retryWrites: true
});

async function run() {
  try {
    await client.connect();
    const database = client.db('production');
    const collection = database.collection('users');
    
    const user = await collection.findOne({ email: 'user@example.com' });
    console.log(user);
  } finally {
    await client.close();
  }
}

run().catch(console.error);
```

### Python Example

```python
from pymongo import MongoClient
import os

uri = os.environ.get('MONGODB_URI')
client = MongoClient(uri, maxPoolSize=50)

db = client.production
collection = db.users

user = collection.find_one({'email': 'user@example.com'})
print(user)
```

### Connection String Format

```
# Standard connection string
mongodb://username:password@host1:27017,host2:27017,host3:27017/database?replicaSet=rs0

# SRV connection string (recommended)
mongodb+srv://username:password@cluster-name.mongodb.net/database?retryWrites=true&w=majority
```

## Performance Optimization

### Indexing Strategy

```javascript
// Create indexes via mongo shell
db.users.createIndex({ email: 1 }, { unique: true });
db.orders.createIndex({ userId: 1, createdAt: -1 });
db.products.createIndex({ category: 1, price: 1 });

// Compound index
db.analytics.createIndex({ 
  userId: 1, 
  eventType: 1, 
  timestamp: -1 
});

// Text index for search
db.articles.createIndex({ 
  title: "text", 
  content: "text" 
});
```

### Query Optimization

Use the Performance Advisor in Atlas Console to:
- Identify slow queries
- Get index recommendations
- Analyze query patterns
- Optimize schema design

### Use Analytics Nodes

```hcl
analytics_instance_size = "M30"
analytics_node_count    = 1
```

Connect analytics tools to analytics nodes to avoid impacting production performance.

## Troubleshooting

### Connection Timeout

1. Check IP whitelist
2. Verify VPC peering/PrivateLink status
3. Check security group rules
4. Verify DNS resolution

### Slow Queries

1. Review Performance Advisor
2. Check indexes
3. Analyze explain plans
4. Consider read preferences

### Replication Lag

1. Check oplog size
2. Review write concern settings
3. Consider increasing instance size
4. Check network latency between regions

### Out of Storage

1. Review storage usage in Atlas Console
2. Identify large collections
3. Implement data archival
4. Consider increasing instance size

## Cost Management

### Right-Sizing

Start small and scale up:
- **Development**: M10 or M20
- **Small Production**: M20 or M30
- **Medium Production**: M30 or M40
- **Large Production**: M50+

### Cost Optimization Tips

1. **Use appropriate instance sizes**
2. **Optimize backup retention**
3. **Monitor and archive old data**
4. **Use analytics nodes for reporting**
5. **Consider reserved capacity for predictable workloads**
6. **Enable auto-scaling for variable workloads**

### Monitoring Costs

Use Atlas Billing page to:
- Track daily/monthly costs
- Set billing alerts
- Review cost by cluster
- Analyze cost trends

## Additional Resources

- [MongoDB Atlas Documentation](https://docs.atlas.mongodb.com/)
- [MongoDB Atlas Terraform Provider](https://registry.terraform.io/providers/mongodb/mongodbatlas/latest/docs)
- [MongoDB University](https://university.mongodb.com/) - Free courses
- [MongoDB Community Forums](https://www.mongodb.com/community/forums/)
- [MongoDB Performance Best Practices](https://docs.mongodb.com/manual/administration/performance/)

## Next Steps

1. Set up monitoring and alerts
2. Implement backup testing procedures
3. Configure application connection pooling
4. Set up development/staging environments
5. Document runbooks for common operations
6. Plan disaster recovery procedures
