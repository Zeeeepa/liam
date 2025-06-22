import { BaseGeminiAgent } from '../base/geminiAgent'
import type { BasePromptVariables } from '../../utils/types'
import { buildAgentPrompt } from './prompts'

export class DatabaseSchemaBuildAgent extends BaseGeminiAgent {
  constructor() {
    // Configure Gemini 2.5 Pro for database schema building with precision
    super({
      model: 'gemini-2.5-pro',
      temperature: 0.1, // Low temperature for precise schema generation
      maxOutputTokens: 8192,
    })
  }

  async generate(variables: BasePromptVariables): Promise<string> {
    const formattedPrompt = await buildAgentPrompt.format(variables)
    const validatedPrompt = this.validateAndFormatPrompt(formattedPrompt)
    
    return this.invokeModel(validatedPrompt)
  }
}
