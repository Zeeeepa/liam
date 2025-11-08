import { NextResponse } from 'next/server'
import { createClient } from '@liam-hq/db/supabase/server'

/**
 * Readiness Check Endpoint
 *
 * Comprehensive readiness check that verifies critical dependencies are available.
 * This is used by orchestrators (K8s, ECS) to determine if the service can accept traffic.
 *
 * Checks:
 * - Database connectivity (Supabase)
 * - Environment variables configured
 * - Critical services available
 *
 * Usage:
 *   GET /api/ready
 *
 * Response:
 *   200 OK - Service is ready to accept traffic
 *   503 Service Unavailable - Service is not ready
 *
 * Example Success Response:
 *   {
 *     "status": "ready",
 *     "timestamp": "2025-01-08T10:30:00.000Z",
 *     "checks": {
 *       "database": "ok",
 *       "environment": "ok"
 *     }
 *   }
 *
 * Example Failure Response:
 *   {
 *     "status": "not_ready",
 *     "timestamp": "2025-01-08T10:30:00.000Z",
 *     "checks": {
 *       "database": "failed",
 *       "environment": "ok"
 *     },
 *     "errors": ["Database connection timeout"]
 *   }
 */
export async function GET() {
  const checks: Record<string, string> = {}
  const errors: string[] = []
  let isReady = true

  try {
    // Check 1: Database connectivity
    const supabase = await createClient()
    const { error: dbError } = await supabase
      .from('projects')
      .select('id')
      .limit(1)
      .single()

    if (dbError && dbError.code !== 'PGRST116') {
      // PGRST116 is "no rows returned" which is fine
      checks.database = 'failed'
      errors.push(`Database error: ${dbError.message}`)
      isReady = false
    } else {
      checks.database = 'ok'
    }
  } catch (err) {
    checks.database = 'failed'
    errors.push(`Database connection failed: ${err instanceof Error ? err.message : 'Unknown error'}`)
    isReady = false
  }

  // Check 2: Environment variables
  const requiredEnvVars = [
    'NEXT_PUBLIC_SUPABASE_URL',
    'NEXT_PUBLIC_SUPABASE_ANON_KEY',
    'OPENAI_API_KEY',
  ]

  const missingEnvVars = requiredEnvVars.filter((key) => !process.env[key])

  if (missingEnvVars.length > 0) {
    checks.environment = 'failed'
    errors.push(`Missing environment variables: ${missingEnvVars.join(', ')}`)
    isReady = false
  } else {
    checks.environment = 'ok'
  }

  const response = {
    status: isReady ? 'ready' : 'not_ready',
    timestamp: new Date().toISOString(),
    checks,
    ...(errors.length > 0 && { errors }),
  }

  return NextResponse.json(response, { status: isReady ? 200 : 503 })
}

