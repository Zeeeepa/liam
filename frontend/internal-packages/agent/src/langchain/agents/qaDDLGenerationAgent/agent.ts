import { BaseGeminiAgent, type GeminiAgentConfig } from '../base/geminiAgent'
import { mapOpenAIModelToGemini } from '../../utils/geminiConfig'
import type { BasePromptVariables } from '../../utils/types'
import { qaDDLGenerationPrompt } from './prompts'

/**
 * QA DDL Generation Agent
 *
 * Now powered by Google's Gemini for enhanced DDL generation capabilities.
 * Uses Gemini with disabled safety settings for unrestricted content generation.
 * 
 * TODO: This LLM-based DDL generation is a temporary solution.
 * In the future, DDL will be generated mechanically without LLM.
 */
export class QADDLGenerationAgent extends BaseGeminiAgent {
  constructor(config?: GeminiAgentConfig) {
    // Use Gemini equivalent of gpt-4o for DDL generation
    const geminiConfig = {
      model: mapOpenAIModelToGemini('gpt-4o'),
      ...config,
    }
    super(geminiConfig)
  }

  async generate(variables: BasePromptVariables): Promise<string> {
    const formattedPrompt = await qaDDLGenerationPrompt.format(variables)
    const response = await this.model.invoke(formattedPrompt)
    return response.content as string
  }
}
