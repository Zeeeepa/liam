import { ChatGoogleGenerativeAI } from '@langchain/google-genai'
import { createLangfuseHandler } from '../../utils/telemetry'
import type { BasePromptVariables, ChatAgent } from '../../utils/types'
import {
  DEFAULT_GENERATION_CONFIG,
  GEMINI_MODELS,
  UNRESTRICTED_SAFETY_SETTINGS,
  mapOpenAIModelToGemini,
} from '../../utils/geminiConfig'

/**
 * Base Gemini Agent Configuration
 */
export interface GeminiAgentConfig {
  model?: string
  temperature?: number
  maxOutputTokens?: number
  enableSafetySettings?: boolean
}

/**
 * Base Gemini Agent Class
 * 
 * This class provides a foundation for all Gemini-based agents with:
 * - Disabled safety settings for unrestricted content generation
 * - Proper telemetry integration with Langfuse
 * - Consistent configuration across all agents
 * - Error handling and fallback mechanisms
 */
export abstract class BaseGeminiAgent<T = string> implements ChatAgent<T> {
  protected model: ChatGoogleGenerativeAI

  constructor(config: GeminiAgentConfig = {}) {
    const {
      model = GEMINI_MODELS.PRO,
      temperature = DEFAULT_GENERATION_CONFIG.temperature,
      maxOutputTokens = DEFAULT_GENERATION_CONFIG.maxOutputTokens,
      enableSafetySettings = false, // Disabled by default as requested
    } = config

    this.model = new ChatGoogleGenerativeAI({
      model,
      temperature,
      maxOutputTokens,
      // Disable all safety settings for unrestricted content generation
      safetySettings: enableSafetySettings ? undefined : UNRESTRICTED_SAFETY_SETTINGS,
      // Additional generation configuration
      topP: DEFAULT_GENERATION_CONFIG.topP,
      topK: DEFAULT_GENERATION_CONFIG.topK,
      // Telemetry integration
      callbacks: [createLangfuseHandler()],
    })
  }

  /**
   * Abstract method that must be implemented by concrete agent classes
   */
  abstract generate(variables: BasePromptVariables): Promise<T>

  /**
   * Get the underlying Gemini model instance
   * Useful for advanced operations or custom configurations
   */
  protected getModel(): ChatGoogleGenerativeAI {
    return this.model
  }

  /**
   * Create a new instance with structured output capabilities
   * This method provides compatibility with OpenAI's withStructuredOutput
   */
  protected withStructuredOutput<S>(schema: any) {
    // Note: Gemini's structured output implementation may differ from OpenAI
    // This method provides a compatibility layer
    return this.model.withStructuredOutput(schema)
  }

  /**
   * Migrate from OpenAI model configuration
   * Helper method to ease transition from existing OpenAI agents
   */
  static fromOpenAIConfig(openAIModel: string, config: Partial<GeminiAgentConfig> = {}): GeminiAgentConfig {
    return {
      model: mapOpenAIModelToGemini(openAIModel),
      ...config,
    }
  }
}

/**
 * Factory function to create Gemini agents with OpenAI compatibility
 */
export function createGeminiAgent<T = string>(
  AgentClass: new (config?: GeminiAgentConfig) => BaseGeminiAgent<T>,
  openAIModel?: string,
  config: Partial<GeminiAgentConfig> = {},
): BaseGeminiAgent<T> {
  const geminiConfig = openAIModel 
    ? BaseGeminiAgent.fromOpenAIConfig(openAIModel, config)
    : config

  return new AgentClass(geminiConfig)
}
