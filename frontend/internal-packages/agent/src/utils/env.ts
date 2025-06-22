/**
 * Environment variable validation utilities for the Liam agent system
 */

export interface EnvironmentValidationResult {
  isValid: boolean
  errors: string[]
  warnings: string[]
}

/**
 * Validates Google API key format and availability
 */
export function validateGoogleApiKey(): {
  isValid: boolean
  error?: string
} {
  const apiKey = process.env.GOOGLE_API_KEY

  if (!apiKey) {
    return {
      isValid: false,
      error: 'GOOGLE_API_KEY environment variable is required but not set',
    }
  }

  if (!apiKey.startsWith('AIzaSy')) {
    return {
      isValid: false,
      error: 'GOOGLE_API_KEY appears to be invalid. Google API keys should start with "AIzaSy"',
    }
  }

  if (apiKey.length < 35 || apiKey.length > 45) {
    return {
      isValid: false,
      error: 'GOOGLE_API_KEY appears to be invalid. Expected length is 35-45 characters',
    }
  }

  return { isValid: true }
}

/**
 * Validates Trigger.dev configuration (auto-configured for local development)
 */
export function validateTriggerDevConfig(): {
  isValid: boolean
  errors: string[]
} {
  const errors: string[] = []
  const projectId = process.env.TRIGGER_PROJECT_ID
  const secretKey = process.env.TRIGGER_SECRET_KEY

  // For local development, we accept the auto-configured values
  if (!projectId) {
    errors.push('TRIGGER_PROJECT_ID environment variable is required but not set')
  } else if (projectId === 'dev-local-project') {
    // Auto-configured local development - this is valid
    return { isValid: true, errors: [] }
  } else if (!projectId.startsWith('proj_')) {
    errors.push('TRIGGER_PROJECT_ID should start with "proj_" for production or use "dev-local-project" for local development')
  }

  if (!secretKey) {
    errors.push('TRIGGER_SECRET_KEY environment variable is required but not set')
  } else if (secretKey === 'dev-local-secret') {
    // Auto-configured local development - this is valid
    return { isValid: true, errors: [] }
  } else if (!secretKey.startsWith('tr_dev_') && !secretKey.startsWith('tr_prod_')) {
    errors.push('TRIGGER_SECRET_KEY should start with "tr_dev_" or "tr_prod_" for production or use "dev-local-secret" for local development')
  }

  return {
    isValid: errors.length === 0,
    errors,
  }
}

/**
 * Validates Supabase configuration (auto-configured from local Supabase)
 */
export function validateSupabaseConfig(): {
  isValid: boolean
  errors: string[]
} {
  const errors: string[] = []
  const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL
  const anonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY
  const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY

  if (!supabaseUrl) {
    errors.push('NEXT_PUBLIC_SUPABASE_URL environment variable is required but not set')
  } else if (!supabaseUrl.startsWith('http')) {
    errors.push('NEXT_PUBLIC_SUPABASE_URL should be a valid URL starting with http')
  }

  // Allow auto-retrieval placeholders during setup
  if (!anonKey) {
    errors.push('NEXT_PUBLIC_SUPABASE_ANON_KEY environment variable is required but not set')
  } else if (anonKey === 'AUTO_RETRIEVED_FROM_SUPABASE_START') {
    // This is a placeholder that will be replaced during setup - valid for now
    return { isValid: true, errors: [] }
  } else if (!anonKey.startsWith('eyJ')) {
    errors.push('NEXT_PUBLIC_SUPABASE_ANON_KEY should be a valid JWT token or "AUTO_RETRIEVED_FROM_SUPABASE_START" during setup')
  }

  if (!serviceRoleKey) {
    errors.push('SUPABASE_SERVICE_ROLE_KEY environment variable is required but not set')
  } else if (serviceRoleKey === 'AUTO_RETRIEVED_FROM_SUPABASE_START') {
    // This is a placeholder that will be replaced during setup - valid for now
    return { isValid: true, errors: [] }
  } else if (!serviceRoleKey.startsWith('eyJ')) {
    errors.push('SUPABASE_SERVICE_ROLE_KEY should be a valid JWT token or "AUTO_RETRIEVED_FROM_SUPABASE_START" during setup')
  }

  return {
    isValid: errors.length === 0,
    errors,
  }
}

/**
 * Validates optional service configurations
 */
export function validateOptionalServices(): {
  warnings: string[]
} {
  const warnings: string[] = []

  // Langfuse validation
  const langfusePublicKey = process.env.LANGFUSE_PUBLIC_KEY
  const langfuseSecretKey = process.env.LANGFUSE_SECRET_KEY

  if (!langfusePublicKey || !langfuseSecretKey) {
    warnings.push('Langfuse not configured - AI observability features will be disabled')
  } else {
    if (!langfusePublicKey.startsWith('pk_lf_')) {
      warnings.push('LANGFUSE_PUBLIC_KEY format appears incorrect (should start with "pk_lf_")')
    }
    if (!langfuseSecretKey.startsWith('sk_lf_')) {
      warnings.push('LANGFUSE_SECRET_KEY format appears incorrect (should start with "sk_lf_")')
    }
  }

  // Sentry validation
  const sentryDsn = process.env.SENTRY_DSN
  if (!sentryDsn) {
    warnings.push('Sentry not configured - error tracking will be disabled')
  } else if (!sentryDsn.startsWith('https://')) {
    warnings.push('SENTRY_DSN format appears incorrect (should be a valid HTTPS URL)')
  }

  // Resend validation
  const resendApiKey = process.env.RESEND_API_KEY
  if (!resendApiKey) {
    warnings.push('Resend not configured - email notifications will be disabled')
  } else if (!resendApiKey.startsWith('re_')) {
    warnings.push('RESEND_API_KEY format appears incorrect (should start with "re_")')
  }

  return { warnings }
}

/**
 * Comprehensive environment validation
 */
export function validateEnvironment(): EnvironmentValidationResult {
  const errors: string[] = []
  const warnings: string[] = []

  // Validate mandatory services
  const googleValidation = validateGoogleApiKey()
  if (!googleValidation.isValid && googleValidation.error) {
    errors.push(googleValidation.error)
  }

  const triggerValidation = validateTriggerDevConfig()
  if (!triggerValidation.isValid) {
    errors.push(...triggerValidation.errors)
  }

  const supabaseValidation = validateSupabaseConfig()
  if (!supabaseValidation.isValid) {
    errors.push(...supabaseValidation.errors)
  }

  // Validate optional services
  const optionalValidation = validateOptionalServices()
  warnings.push(...optionalValidation.warnings)

  return {
    isValid: errors.length === 0,
    errors,
    warnings,
  }
}

/**
 * Logs environment validation results in a user-friendly format
 */
export function logEnvironmentValidation(): void {
  const validation = validateEnvironment()

  console.log('\n🔍 Environment Validation Results:')
  console.log('=====================================')

  if (validation.isValid) {
    console.log('✅ All mandatory environment variables are properly configured!')
  } else {
    console.log('❌ Environment validation failed:')
    validation.errors.forEach((error, index) => {
      console.log(`   ${index + 1}. ${error}`)
    })
  }

  if (validation.warnings.length > 0) {
    console.log('\n⚠️  Warnings (optional features):')
    validation.warnings.forEach((warning, index) => {
      console.log(`   ${index + 1}. ${warning}`)
    })
  }

  console.log('\n📖 For setup instructions, see: requirements.md')
  console.log('=====================================\n')
}

/**
 * Throws an error if environment validation fails
 * Use this in critical startup paths
 */
export function requireValidEnvironment(): void {
  const validation = validateEnvironment()
  
  if (!validation.isValid) {
    const errorMessage = [
      '❌ Environment validation failed. Please fix the following issues:',
      ...validation.errors.map((error, index) => `   ${index + 1}. ${error}`),
      '',
      '📖 For setup instructions, see: requirements.md',
    ].join('\n')
    
    throw new Error(errorMessage)
  }
}
