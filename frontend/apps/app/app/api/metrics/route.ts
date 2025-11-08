import { NextResponse } from 'next/server'

/**
 * Metrics Endpoint
 *
 * Basic metrics endpoint for monitoring and observability.
 * Returns runtime metrics in a simple JSON format.
 *
 * Usage:
 *   GET /api/metrics
 *
 * Response:
 *   200 OK
 *   {
 *     "uptime_seconds": 12345,
 *     "memory_usage": {
 *       "rss_mb": 145.2,
 *       "heap_used_mb": 89.5,
 *       "heap_total_mb": 120.0,
 *       "external_mb": 2.3
 *     },
 *     "process": {
 *       "pid": 1234,
 *       "node_version": "v20.10.0",
 *       "platform": "linux"
 *     },
 *     "timestamp": "2025-01-08T10:30:00.000Z"
 *   }
 *
 * Integration with Prometheus:
 *   This endpoint returns JSON format. For Prometheus metrics format,
 *   consider using a library like 'prom-client'.
 *
 * Security Note:
 *   This endpoint exposes system metrics. In production, consider:
 *   - Rate limiting
 *   - Authentication
 *   - IP whitelisting
 */
export async function GET() {
  const memoryUsage = process.memoryUsage()

  const metrics = {
    uptime_seconds: Math.floor(process.uptime()),
    memory_usage: {
      rss_mb: Math.round((memoryUsage.rss / 1024 / 1024) * 100) / 100,
      heap_used_mb:
        Math.round((memoryUsage.heapUsed / 1024 / 1024) * 100) / 100,
      heap_total_mb:
        Math.round((memoryUsage.heapTotal / 1024 / 1024) * 100) / 100,
      external_mb:
        Math.round((memoryUsage.external / 1024 / 1024) * 100) / 100,
    },
    process: {
      pid: process.pid,
      node_version: process.version,
      platform: process.platform,
      arch: process.arch,
    },
    timestamp: new Date().toISOString(),
  }

  return NextResponse.json(metrics, { status: 200 })
}

