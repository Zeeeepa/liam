import { BaseGeminiAgent } from '../base/geminiAgent'
import type { BasePromptVariables } from '../../utils/types'
import { qaDDLGenerationPrompt } from './prompts'

/**
 * QA DDL Generation Agent
 *
 * TODO: This LLM-based DDL generation is a temporary solution.
 * In the future, DDL will be generated mechanically without LLM.
 * 
 * Now using Google Gemini API instead of OpenAI for DDL generation.
 */
export class QADDLGenerationAgent extends BaseGeminiAgent {
  constructor() {
    // Configure Gemini for precise DDL generation
    super({
      model: 'gemini-1.5-pro',
      temperature: 0.0, // Very low temperature for precise SQL generation
      maxOutputTokens: 4096, // DDL statements are typically shorter
    })
  }

  async generate(variables: BasePromptVariables): Promise<string> {
    const formattedPrompt = await qaDDLGenerationPrompt.format(variables)
    const validatedPrompt = this.validateAndFormatPrompt(formattedPrompt)
    
    return this.invokeModel(validatedPrompt)
  }
}
