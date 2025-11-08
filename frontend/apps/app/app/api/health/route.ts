import { NextResponse } from 'next/server'

/**
 * Health Check Endpoint
 *
 * Simple health check that returns 200 OK if the service is running.
 * This is used by load balancers, orchestrators, and monitoring systems
 * to verify the service is responsive.
 *
 * Usage:
 *   GET /api/health
 *
 * Response:
 *   200 OK - Service is healthy
 *   {
 *     "status": "ok",
 *     "timestamp": "2025-01-08T10:30:00.000Z",
 *     "uptime": 12345
 *   }
 */
export async function GET() {
  return NextResponse.json(
    {
      status: 'ok',
      timestamp: new Date().toISOString(),
      uptime: process.uptime(),
    },
    { status: 200 },
  )
}

