# Supabase Connection Pooling Configuration Guide

## Overview
This guide explains how to configure connection pooling for the Smart NFC Attendance System to handle concurrent requests efficiently and prevent database connection exhaustion.

## What is Connection Pooling?

Connection pooling is a technique that maintains a pool of reusable database connections, reducing the overhead of creating new connections for each request. This is critical for:

- **Performance**: Reusing connections is faster than creating new ones
- **Scalability**: Handle more concurrent users with limited database connections
- **Reliability**: Prevent connection exhaustion under high load

## Supabase Connection Pooling

Supabase provides built-in connection pooling through **PgBouncer**, a lightweight connection pooler for PostgreSQL.

### Connection Modes

Supabase offers two connection modes:

1. **Session Mode** (Default)
   - Connection string: `postgresql://postgres:[password]@[host]:5432/postgres`
   - One server connection per client connection
   - Supports all PostgreSQL features
   - Use for: Admin operations, migrations, complex transactions

2. **Transaction Mode** (Pooled)
   - Connection string: `postgresql://postgres:[password]@[host]:6543/postgres`
   - Port 6543 uses PgBouncer
   - Connection released after each transaction
   - Use for: Application queries, high-concurrency scenarios

## Configuration for SNAS

### Mobile App Configuration

The mobile app uses the Supabase Flutter SDK, which automatically handles connection pooling through the Supabase API layer. No additional configuration is needed.

**Current Configuration** (in mobile app):
```dart
await Supabase.initialize(
  url: 'YOUR_SUPABASE_URL',
  anonKey: 'YOUR_SUPABASE_ANON_KEY',
);
```

The Supabase client automatically:
- Reuses HTTP connections
- Implements request queuing
- Handles connection timeouts
- Manages authentication tokens

### Admin Dashboard Configuration

For the Next.js admin dashboard, use the Supabase JavaScript client with connection pooling:

**Configuration** (in `lib/supabase.ts`):
```typescript
import { createClient } from '@supabase/supabase-js'

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL!
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!

export const supabase = createClient(supabaseUrl, supabaseAnonKey, {
  auth: {
    persistSession: true,
    autoRefreshToken: true,
  },
  db: {
    schema: 'public',
  },
  global: {
    headers: {
      'x-application-name': 'snas-admin-dashboard',
    },
  },
})
```

The Supabase JS client automatically handles connection pooling through the REST API.

### Direct Database Connections (Advanced)

If you need direct database access (e.g., for batch operations or custom scripts), use the pooled connection string:

**Pooled Connection String**:
```
postgresql://postgres:[password]@db.[project-ref].supabase.co:6543/postgres
```

**Example with Node.js** (`pg` library):
```javascript
const { Pool } = require('pg')

const pool = new Pool({
  host: 'db.[project-ref].supabase.co',
  port: 6543, // PgBouncer port
  database: 'postgres',
  user: 'postgres',
  password: '[password]',
  max: 20, // Maximum pool size
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
})
```

## Connection Pool Sizing

### Recommended Pool Sizes

For the SNAS system:

| Component | Recommended Pool Size | Reasoning |
|-----------|----------------------|-----------|
| Mobile App (via Supabase API) | N/A (handled by Supabase) | Each request is independent |
| Admin Dashboard | N/A (handled by Supabase) | Low concurrent user count |
| Background Jobs | 5-10 connections | Batch operations, reports |
| Database Migrations | 1 connection | Sequential execution |

### Supabase Default Limits

- **Free Tier**: 60 concurrent connections
- **Pro Tier**: 200 concurrent connections
- **Enterprise**: Custom limits

### Calculating Required Connections

For SNAS, estimate concurrent connections:

```
Concurrent Users = Peak Students × Attendance Rate
Example: 500 students × 20% = 100 concurrent requests

Required Connections = Concurrent Users / Request Duration
Example: 100 requests / 5 requests per second = 20 connections
```

**Recommendation**: Start with 50 connections, monitor usage, and scale as needed.

## Monitoring Connection Usage

### Query Current Connections

```sql
-- View active connections
SELECT 
  count(*) as total_connections,
  state,
  application_name
FROM pg_stat_activity
WHERE datname = 'postgres'
GROUP BY state, application_name
ORDER BY total_connections DESC;

-- View connection pool statistics (PgBouncer)
SELECT * FROM pgbouncer.stats;
SELECT * FROM pgbouncer.pools;
```

### Supabase Dashboard

1. Go to Supabase Dashboard → Database → Connection Pooling
2. View real-time connection usage
3. Monitor connection pool statistics

### Set Up Alerts

Configure alerts for:
- Connection pool exhaustion (> 80% usage)
- Long-running queries (> 5 seconds)
- Connection timeouts

## Best Practices

### 1. Use Connection Pooling for All Application Queries

✅ **Do**:
```typescript
// Use Supabase client (automatically pooled)
const { data, error } = await supabase
  .from('attendance_logs')
  .select('*')
```

❌ **Don't**:
```typescript
// Don't create new connections for each query
const client = new Client({ connectionString: directConnectionString })
await client.connect()
// ... query
await client.end()
```

### 2. Close Connections Properly

Always close connections when done:
```javascript
// For direct connections
try {
  const client = await pool.connect()
  // ... use client
} finally {
  client.release() // Return to pool
}
```

### 3. Set Appropriate Timeouts

```javascript
// Query timeout
const result = await pool.query({
  text: 'SELECT * FROM attendance_logs WHERE ...',
  timeout: 5000, // 5 seconds
})

// Connection timeout
const pool = new Pool({
  connectionTimeoutMillis: 2000, // 2 seconds
})
```

### 4. Handle Connection Errors

```javascript
pool.on('error', (err, client) => {
  console.error('Unexpected error on idle client', err)
  // Don't exit the process, just log the error
})
```

### 5. Use Read Replicas (Pro/Enterprise)

For read-heavy workloads, use Supabase read replicas:
```typescript
const supabaseRead = createClient(readReplicaUrl, anonKey)

// Use for read operations
const { data } = await supabaseRead
  .from('attendance_logs')
  .select('*')
```

## Performance Optimization Tips

### 1. Batch Operations

Instead of multiple individual queries:
```typescript
// ❌ Bad: Multiple queries
for (const log of logs) {
  await supabase.from('attendance_logs').insert(log)
}

// ✅ Good: Single batch insert
await supabase.from('attendance_logs').insert(logs)
```

### 2. Use Prepared Statements

For repeated queries with different parameters:
```javascript
const query = {
  name: 'get-student-attendance',
  text: 'SELECT * FROM attendance_logs WHERE student_id = $1',
  values: [studentId],
}
```

### 3. Implement Request Queuing

For high-concurrency scenarios:
```typescript
import PQueue from 'p-queue'

const queue = new PQueue({ concurrency: 10 })

// Queue requests
const results = await Promise.all(
  requests.map(req => queue.add(() => processRequest(req)))
)
```

### 4. Cache Frequently Accessed Data

Implement caching for:
- Classroom data (rarely changes)
- User profiles (rarely changes)
- Recent attendance logs (cache for 5 minutes)

See mobile app `CacheService` for implementation example.

## Troubleshooting

### Issue: "Too many connections" Error

**Symptoms**: 
```
FATAL: sorry, too many clients already
```

**Solutions**:
1. Use pooled connection string (port 6543)
2. Reduce pool size in application
3. Upgrade Supabase plan for more connections
4. Implement connection retry logic

### Issue: Slow Query Performance

**Symptoms**: Queries taking > 200ms

**Solutions**:
1. Check query execution plan: `EXPLAIN ANALYZE SELECT ...`
2. Verify indexes are being used
3. Optimize queries (see Task 16.2)
4. Use materialized views for complex queries

### Issue: Connection Timeouts

**Symptoms**: Requests timing out after 10-30 seconds

**Solutions**:
1. Increase connection timeout
2. Optimize slow queries
3. Check network connectivity
4. Verify Supabase service status

## Testing Connection Pooling

### Load Test Script

```javascript
// test-connection-pool.js
const { createClient } = require('@supabase/supabase-js')

const supabase = createClient(url, key)

async function simulateConcurrentRequests(count) {
  const start = Date.now()
  
  const requests = Array(count).fill(null).map((_, i) => 
    supabase.rpc('mark_attendance', {
      p_classroom_id: classroomId,
      p_secret_token: token,
      p_latitude: 37.7749,
      p_longitude: -122.4194,
    })
  )
  
  const results = await Promise.allSettled(requests)
  const duration = Date.now() - start
  
  console.log(`${count} requests completed in ${duration}ms`)
  console.log(`Average: ${duration / count}ms per request`)
  console.log(`Success: ${results.filter(r => r.status === 'fulfilled').length}`)
  console.log(`Failed: ${results.filter(r => r.status === 'rejected').length}`)
}

// Test with increasing load
simulateConcurrentRequests(10)
simulateConcurrentRequests(50)
simulateConcurrentRequests(100)
```

## Summary

Connection pooling is automatically handled by Supabase for the SNAS system:

✅ **Mobile App**: Uses Supabase Flutter SDK (automatic pooling)
✅ **Admin Dashboard**: Uses Supabase JS client (automatic pooling)
✅ **Database**: PgBouncer enabled on port 6543
✅ **Caching**: Implemented in mobile app for offline support

**No additional configuration required** for standard usage. For advanced scenarios (direct database access, batch jobs), use the pooled connection string on port 6543.

## References

- [Supabase Connection Pooling Docs](https://supabase.com/docs/guides/database/connecting-to-postgres#connection-pooler)
- [PgBouncer Documentation](https://www.pgbouncer.org/usage.html)
- [PostgreSQL Connection Pooling Best Practices](https://www.postgresql.org/docs/current/runtime-config-connection.html)

