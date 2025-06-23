import { HarmBlockThreshold, HarmCategory } from '@google/generative-ai'

/**
 * Gemini Configuration Utilities
 * 
 * This module provides configuration utilities for Google's Gemini models,
 * specifically designed to disable all safety settings for unrestricted content generation.
 */

/**
 * Safety settings configuration that disables all safety filters
 * This allows for unrestricted content generation as requested
 */
export const UNRESTRICTED_SAFETY_SETTINGS = [
  {
    category: HarmCategory.HARM_CATEGORY_HARASSMENT,
    threshold: HarmBlockThreshold.BLOCK_NONE,
  },
  {
    category: HarmCategory.HARM_CATEGORY_HATE_SPEECH,
    threshold: HarmBlockThreshold.BLOCK_NONE,
  },
  {
    category: HarmCategory.HARM_CATEGORY_SEXUALLY_EXPLICIT,
    threshold: HarmBlockThreshold.BLOCK_NONE,
  },
  {
    category: HarmCategory.HARM_CATEGORY_DANGEROUS_CONTENT,
    threshold: HarmBlockThreshold.BLOCK_NONE,
  },
]

/**
 * Default Gemini model configurations for different use cases
 */
export const GEMINI_MODELS = {
  // Latest high-performance model for complex reasoning tasks
  PRO: 'gemini-2.5-pro',
  // High-performance model (previous version)
  PRO_LEGACY: 'gemini-1.5-pro-latest',
  // Fast model for simple tasks
  FLASH: 'gemini-1.5-flash-latest',
  // Experimental model with latest features
  EXPERIMENTAL: 'gemini-2.0-flash-exp',
} as const

/**
 * Generation configuration for optimal performance
 */
export const DEFAULT_GENERATION_CONFIG = {
  temperature: 0.7,
  topP: 0.8,
  topK: 40,
  maxOutputTokens: 8192,
}

/**
 * Get the appropriate Gemini model based on the original OpenAI model
 * Now defaults to Gemini 2.5 Pro for maximum performance
 */
export function mapOpenAIModelToGemini(openAIModel: string): string {
  switch (openAIModel) {
    case 'o3':
    case 'gpt-4':
    case 'gpt-4-turbo':
      return GEMINI_MODELS.PRO // Now uses Gemini 2.5 Pro
    case 'gpt-4o':
    case 'gpt-4o-mini':
      return GEMINI_MODELS.PRO // Upgraded to Gemini 2.5 Pro for better performance
    case 'gpt-3.5-turbo':
      return GEMINI_MODELS.FLASH
    default:
      return GEMINI_MODELS.PRO // Default to Gemini 2.5 Pro
  }
}
