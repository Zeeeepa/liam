import { ChatGoogleGenerativeAI } from '@langchain/google-genai'
import { createLangfuseHandler } from '../../utils/telemetry'
import type { BasePromptVariables, ChatAgent } from '../../utils/types'

/**
 * Base Gemini Agent class that provides Google Generative AI integration
 * This replaces the OpenAI ChatOpenAI implementation across all agents
 */
export abstract class BaseGeminiAgent implements ChatAgent {
  protected model: ChatGoogleGenerativeAI

  constructor(options?: {
    model?: string
    temperature?: number
    maxOutputTokens?: number
  }) {
    // Validate Google API key
    if (!process.env.GOOGLE_API_KEY) {
      throw new Error(
        'GOOGLE_API_KEY environment variable is required. Please set your Google Gemini API key.'
      )
    }

    // Validate API key format
    if (!process.env.GOOGLE_API_KEY.startsWith('AIzaSy')) {
      throw new Error(
        'Invalid GOOGLE_API_KEY format. Google API keys should start with "AIzaSy".'
      )
    }

    this.model = new ChatGoogleGenerativeAI({
      model: options?.model || 'gemini-1.5-pro',
      apiKey: process.env.GOOGLE_API_KEY,
      temperature: options?.temperature ?? 0.1,
      maxOutputTokens: options?.maxOutputTokens ?? 8192,
      callbacks: [createLangfuseHandler()],
      // Additional safety settings for production use
      safetySettings: [
        {
          category: 'HARM_CATEGORY_HARASSMENT',
          threshold: 'BLOCK_MEDIUM_AND_ABOVE',
        },
        {
          category: 'HARM_CATEGORY_HATE_SPEECH',
          threshold: 'BLOCK_MEDIUM_AND_ABOVE',
        },
        {
          category: 'HARM_CATEGORY_SEXUALLY_EXPLICIT',
          threshold: 'BLOCK_MEDIUM_AND_ABOVE',
        },
        {
          category: 'HARM_CATEGORY_DANGEROUS_CONTENT',
          threshold: 'BLOCK_MEDIUM_AND_ABOVE',
        },
      ],
    })
  }

  /**
   * Generate response using Gemini API
   * This method should be implemented by concrete agent classes
   */
  abstract generate(variables: BasePromptVariables): Promise<string>

  /**
   * Protected method to invoke the model with proper error handling
   */
  protected async invokeModel(prompt: string): Promise<string> {
    try {
      const response = await this.model.invoke(prompt)
      
      if (!response.content) {
        throw new Error('Empty response from Gemini API')
      }

      return response.content as string
    } catch (error) {
      // Enhanced error handling for common Gemini API issues
      if (error instanceof Error) {
        if (error.message.includes('API_KEY_INVALID')) {
          throw new Error(
            'Invalid Google API key. Please check your GOOGLE_API_KEY environment variable.'
          )
        }
        if (error.message.includes('QUOTA_EXCEEDED')) {
          throw new Error(
            'Google API quota exceeded. Please check your billing and usage limits.'
          )
        }
        if (error.message.includes('SAFETY')) {
          throw new Error(
            'Content was blocked by Gemini safety filters. Please modify your request.'
          )
        }
        if (error.message.includes('RATE_LIMIT_EXCEEDED')) {
          throw new Error(
            'Rate limit exceeded. Please wait before making another request.'
          )
        }
      }
      
      // Re-throw with context
      throw new Error(`Gemini API error: ${error instanceof Error ? error.message : 'Unknown error'}`)
    }
  }

  /**
   * Utility method to validate and format prompts for Gemini
   */
  protected validateAndFormatPrompt(prompt: string): string {
    if (!prompt || prompt.trim().length === 0) {
      throw new Error('Prompt cannot be empty')
    }

    // Ensure prompt is within reasonable length limits
    if (prompt.length > 100000) {
      console.warn('Prompt is very long, consider truncating for better performance')
    }

    return prompt.trim()
  }

  /**
   * Get model information for debugging/logging
   */
  public getModelInfo(): {
    model: string
    provider: string
    temperature: number
    maxOutputTokens: number
  } {
    return {
      model: this.model.model,
      provider: 'Google Gemini',
      temperature: this.model.temperature ?? 0.1,
      maxOutputTokens: this.model.maxOutputTokens ?? 8192,
    }
  }
}

