# ElastiCache Redis Module - Usage Guide

## Overview

The ElastiCache Redis module creates a fully-managed Redis cluster with:
- ✅ Multi-AZ high availability
- ✅ Automatic failover
- ✅ Encryption at rest and in transit
- ✅ CloudWatch monitoring and alarms
- ✅ Automated backups
- ✅ Integrated with security groups

## Quick Start

### Step 1: Redis is Already in Security Groups!

The `security-groups` module now **automatically creates** a Redis security group that allows:
- ECS tasks → Redis (port 6379)
- Lambda → Redis (port 6379)
- Redis → Redis (for replication)

No extra configuration needed!

### Step 2: Add Redis to Your Environment

```hcl
# In environments/dev/main.tf

# Security groups (already includes Redis SG)
module "security_groups" {
  source = "../../modules/security-groups"
  
  project_name   = var.project_name
  environment    = var.environment
  vpc_id         = module.vpc.vpc_id
  vpc_cidr_block = module.vpc.vpc_cidr_block
  
  # Optional: customize Redis port
  redis_port = 6379  # default
  
  common_tags = local.common_tags
}

# ElastiCache Redis
module "redis" {
  source = "../../modules/elasticache-redis"

  project_name      = var.project_name
  environment       = var.environment
  subnet_ids        = module.vpc.private_db_subnet_ids  # Use DB subnets
  security_group_id = module.security_groups.redis_security_group_id

  # Node configuration
  node_type       = "cache.t3.micro"  # Dev: small, Prod: larger
  num_cache_nodes = 1                 # Dev: 1, Prod: 2+ for HA

  # Encryption (recommended for production)
  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  auth_token                 = var.redis_auth_token  # Required if transit encryption enabled

  # Monitoring
  enable_cloudwatch_alarms = true

  common_tags = local.common_tags
}
```

### Step 3: Add Variable for Auth Token

```hcl
# In environments/dev/variables.tf

variable "redis_auth_token" {
  description = "Auth token for Redis (16-128 chars)"
  type        = string
  sensitive   = true
  default     = null  # Set in terraform.tfvars
}
```

### Step 4: Configure in tfvars

```hcl
# In environments/dev/terraform.tfvars (DO NOT COMMIT!)

redis_auth_token = "your-super-secret-token-here-min-16-chars"
```

### Step 5: Use Redis in Your Services

```hcl
# ECS Service with Redis
module "ecs_backend" {
  source = "../../modules/ecs-service"
  
  # ... other config ...
  
  environment_variables = [
    {
      name  = "REDIS_HOST"
      value = module.redis.primary_endpoint_address
    },
    {
      name  = "REDIS_PORT"
      value = tostring(module.redis.port)
    }
  ]
  
  secrets = [
    {
      name      = "REDIS_PASSWORD"
      valueFrom = "arn:aws:secretsmanager:region:account:secret:redis-token"
    }
  ]
}

# Lambda with Redis
module "lambda_api" {
  source = "../../modules/lambda"
  
  # ... other config ...
  
  vpc_config = {
    subnet_ids         = module.vpc.private_app_subnet_ids
    security_group_ids = [module.security_groups.lambda_security_group_id]
  }
  
  environment_variables = {
    REDIS_HOST = module.redis.primary_endpoint_address
    REDIS_PORT = tostring(module.redis.port)
  }
}
```

## Environment-Specific Configurations

### Development

```hcl
module "redis" {
  source = "../../modules/elasticache-redis"

  project_name      = var.project_name
  environment       = "dev"
  subnet_ids        = module.vpc.private_db_subnet_ids
  security_group_id = module.security_groups.redis_security_group_id

  # Small, single node for dev
  node_type       = "cache.t3.micro"
  num_cache_nodes = 1

  # Minimal backups
  snapshot_retention_limit = 1

  # Encryption optional in dev
  at_rest_encryption_enabled = false
  transit_encryption_enabled = false
  auth_token                 = null

  # Reduced monitoring
  enable_cloudwatch_alarms = false

  common_tags = local.common_tags
}
```

### Staging

```hcl
module "redis" {
  source = "../../modules/elasticache-redis"

  project_name      = var.project_name
  environment       = "staging"
  subnet_ids        = module.vpc.private_db_subnet_ids
  security_group_id = module.security_groups.redis_security_group_id

  # Moderate size, single node
  node_type       = "cache.t3.small"
  num_cache_nodes = 1

  # Standard backups
  snapshot_retention_limit = 5

  # Encryption enabled
  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  auth_token                 = var.redis_auth_token

  # Full monitoring
  enable_cloudwatch_alarms = true

  common_tags = local.common_tags
}
```

### Production

```hcl
module "redis" {
  source = "../../modules/elasticache-redis"

  project_name      = var.project_name
  environment       = "production"
  subnet_ids        = module.vpc.private_db_subnet_ids
  security_group_id = module.security_groups.redis_security_group_id

  # Production-grade, Multi-AZ
  node_type       = "cache.r6g.large"
  num_cache_nodes = 2  # or 3 for higher availability

  # High availability
  automatic_failover_enabled = true
  multi_az_enabled          = true

  # Extended backups
  snapshot_retention_limit = 30

  # Full encryption
  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  auth_token                 = var.redis_auth_token

  # Full monitoring
  enable_cloudwatch_alarms = true
  cpu_threshold            = 75
  memory_threshold         = 85

  common_tags = local.common_tags
}
```

## Advanced Configurations

### Custom Parameters

```hcl
module "redis" {
  source = "../../modules/elasticache-redis"
  
  # ... other config ...
  
  parameter_group_family = "redis7"
  
  parameters = [
    {
      name  = "maxmemory-policy"
      value = "allkeys-lru"
    },
    {
      name  = "timeout"
      value = "300"
    },
    {
      name  = "tcp-keepalive"
      value = "300"
    }
  ]
}
```

### With SNS Notifications

```hcl
# Create SNS topic for Redis alerts
resource "aws_sns_topic" "redis_alerts" {
  name = "${var.project_name}-${var.environment}-redis-alerts"
}

module "redis" {
  source = "../../modules/elasticache-redis"
  
  # ... other config ...
  
  notification_topic_arn = aws_sns_topic.redis_alerts.arn
}
```

## Application Code Examples

### Node.js with ioredis

```javascript
const Redis = require('ioredis');

const redis = new Redis({
  host: process.env.REDIS_HOST,
  port: process.env.REDIS_PORT,
  password: process.env.REDIS_PASSWORD, // Auth token
  tls: process.env.REDIS_TLS === 'true' ? {} : undefined,
  retryStrategy: (times) => {
    const delay = Math.min(times * 50, 2000);
    return delay;
  }
});

redis.on('connect', () => console.log('Redis connected'));
redis.on('error', (err) => console.error('Redis error:', err));

// Usage
await redis.set('key', 'value');
const value = await redis.get('key');
```

### Python with redis-py

```python
import redis
import os

redis_client = redis.Redis(
    host=os.environ['REDIS_HOST'],
    port=int(os.environ['REDIS_PORT']),
    password=os.environ.get('REDIS_PASSWORD'),
    ssl=os.environ.get('REDIS_TLS') == 'true',
    decode_responses=True
)

# Usage
redis_client.set('key', 'value')
value = redis_client.get('key')
```

### Go with go-redis

```go
package main

import (
    "github.com/go-redis/redis/v8"
    "os"
)

func main() {
    rdb := redis.NewClient(&redis.Options{
        Addr:     os.Getenv("REDIS_HOST") + ":" + os.Getenv("REDIS_PORT"),
        Password: os.Getenv("REDIS_PASSWORD"),
        DB:       0,
    })

    // Usage
    err := rdb.Set(ctx, "key", "value", 0).Err()
    val, err := rdb.Get(ctx, "key").Result()
}
```

## Monitoring

### Key Metrics to Watch

1. **CPU Utilization** - Should stay < 75%
2. **Memory Usage** - Should stay < 85%
3. **Evictions** - Should be minimal (increase memory if high)
4. **Swap Usage** - Should be 0 (indicates memory pressure)
5. **Cache Hits vs Misses** - Higher hit rate is better

### CloudWatch Alarms

The module automatically creates alarms for:
- ✅ High CPU utilization (default: 75%)
- ✅ High memory usage (default: 90%)
- ✅ Evictions (default: > 1000)
- ✅ Swap usage (default: > 50MB)

### Viewing Logs

```bash
# Slow log
aws logs tail /aws/elasticache/myapp-dev/redis/slow-log --follow

# Engine log
aws logs tail /aws/elasticache/myapp-dev/redis/engine-log --follow
```

## Common Use Cases

### Session Storage

```javascript
// Store session
await redis.setex(`session:${sessionId}`, 3600, JSON.stringify(sessionData));

// Get session
const sessionData = JSON.parse(await redis.get(`session:${sessionId}`));
```

### Caching

```javascript
// Cache with TTL
const cacheKey = `user:${userId}`;
let user = await redis.get(cacheKey);

if (!user) {
  user = await db.getUser(userId);
  await redis.setex(cacheKey, 300, JSON.stringify(user)); // 5 min cache
}
```

### Rate Limiting

```javascript
const key = `ratelimit:${userId}:${endpoint}`;
const current = await redis.incr(key);

if (current === 1) {
  await redis.expire(key, 60); // 1 minute window
}

if (current > 100) {
  throw new Error('Rate limit exceeded');
}
```

### Pub/Sub

```javascript
// Publisher
await redis.publish('notifications', JSON.stringify(message));

// Subscriber
redis.subscribe('notifications', (err, count) => {
  console.log(`Subscribed to ${count} channels`);
});

redis.on('message', (channel, message) => {
  console.log(`Received on ${channel}:`, message);
});
```

## Troubleshooting

### Connection Issues

**Problem**: Can't connect to Redis
**Check**:
1. Security group allows traffic from your service
2. Service is in correct subnets
3. Auth token is correct (if encryption enabled)

```bash
# Test from ECS task (use ECS Exec)
redis-cli -h $REDIS_HOST -p $REDIS_PORT -a $REDIS_PASSWORD ping
```

### High Memory Usage

**Problem**: Memory usage is high, evictions occurring
**Solutions**:
1. Increase node size: `cache.t3.micro` → `cache.t3.small`
2. Add more nodes for cluster mode
3. Adjust `maxmemory-policy`
4. Review data TTLs

### Performance Issues

**Problem**: Slow response times
**Check**:
1. CPU utilization (< 75%)
2. Network throughput
3. Number of connections
4. Slow log for expensive operations

```bash
# View slow log
aws elasticache get-cache-cluster --cache-cluster-id myapp-dev-redis-001
```

## Best Practices

### ✅ DO:
1. **Use encryption** in production (at-rest and in-transit)
2. **Enable Multi-AZ** for production workloads
3. **Set appropriate TTLs** on all keys
4. **Monitor evictions** and adjust memory accordingly
5. **Use connection pooling** in your application
6. **Set up CloudWatch alarms**

### ❌ DON'T:
1. Don't store large values (> 1MB) in Redis
2. Don't use Redis as primary data store
3. Don't disable backups in production
4. Don't use `KEYS *` in production (use `SCAN` instead)
5. Don't ignore eviction warnings

## Cost Optimization

### Development
- Use `cache.t3.micro` or `cache.t4g.micro`
- Single node (no replication)
- Minimal backup retention
- Disable encryption if not needed

### Production
- Use Reserved Instances for predictable workloads
- Monitor actual usage and right-size nodes
- Use `cache.r6g.*` instances (Graviton2) for cost savings
- Consider cluster mode for very large datasets

## Summary

The Redis module is now fully integrated:
- ✅ Security groups automatically configured
- ✅ ECS and Lambda can access Redis
- ✅ Encryption and auth token support
- ✅ CloudWatch monitoring enabled
- ✅ Multi-AZ high availability
- ✅ Automated backups

Just add the module to your environment and start caching!
