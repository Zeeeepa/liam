import { GoogleGenerativeAI } from '@google/generative-ai'
import { expect, test } from 'vitest'

const API_KEY = process.env.GEMINI_API_KEY
const genAI = new GoogleGenerativeAI(API_KEY || '')
const model = genAI.getGenerativeModel({ model: 'gemini-2.0-flash-exp' })

// LLM にプロンプトを投げ、消費トークン情報も取得
async function getLLMResponse(
  prompt: string,
): Promise<{ text: string; promptTokenCount: number; candidatesTokenCount: number }> {
  console.log(`🚀 投げるプロンプト: \n"${prompt}"\n`)

  const response = await model.generateContent(prompt)
  const promptTokenCount = response.response.usageMetadata?.promptTokenCount ?? 0
  const candidatesTokenCount = response.response.usageMetadata?.candidatesTokenCount ?? 0
  const text = response.response.text()

  console.log(`✅ プロンプト処理 - 入力トークン数: ${promptTokenCount}, 出力トークン数: ${candidatesTokenCount}`)
  console.log(`   ▶️  出力: "${text}"\n`)

  return { text, promptTokenCount, candidatesTokenCount }
}

// LLM に評価をさせ、消費トークン情報も取得
async function evaluateElementPresence(
  response: string,
  element: string,
  shouldInclude: boolean,
): Promise<{ isCorrect: boolean; promptTokenCount: number; candidatesTokenCount: number }> {
  const evalPrompt = `
  以下の文章に "${element}" という要素が **含まれていれば"YES",含まれていなければ"NO"と答えてください**

  文章は以下です
  -----
  ${response}
  -----
  文章は以上です
  `

  console.log(`🚀 投げる評価プロンプト: \n"${evalPrompt}"\n`)

  const evalResponse = await model.generateContent(evalPrompt)
  const promptTokenCount = evalResponse.response.usageMetadata?.promptTokenCount ?? 0
  const candidatesTokenCount = evalResponse.response.usageMetadata?.candidatesTokenCount ?? 0
  const answer = evalResponse.response.text().trim().toUpperCase()
  const isCorrect = (shouldInclude && answer.includes('YES')) || (!shouldInclude && answer.includes('NO'))

  console.log(`✅ 評価処理 - 要素: "${element}"`)
  console.log(`   ▶️  出力: "${evalResponse.response.text()}"`)
  console.log(`   🔹 判定: ${isCorrect ? '✅ 正しい' : '❌ 誤り'}`)
  console.log(`   🔢 消費トークン: 入力=${promptTokenCount}, 出力=${candidatesTokenCount}\n`)

  return { isCorrect, promptTokenCount, candidatesTokenCount }
}

// テスト実行
test('Gemini の応答に期待する要素が含まれるかを LLM に評価させ、トークン数を記録', async () => {
  const userPrompt = '日本の漫画家の藤本タツキの代表作を4個挙げて'

  // 1回目: プロンプト処理
  const { text: response, promptTokenCount: promptTokens1, candidatesTokenCount: candidatesTokens1 } =
    await getLLMResponse(userPrompt)

  // 2回目: 評価処理
  const expectedIncludedElements = ['チェンソーマン', 'ルックバック'] // これらが含まれるべき
  const expectedExcludedElements = ['みどりのマキバオー', '北斗の拳'] // これらは含まれてはいけない

  let totalPromptTokens = promptTokens1
  let totalCandidatesTokens = candidatesTokens1

  for (const element of expectedIncludedElements) {
    const { isCorrect, promptTokenCount, candidatesTokenCount } = await evaluateElementPresence(response, element, true)
    expect(isCorrect).toBe(true)
    totalPromptTokens += promptTokenCount
    totalCandidatesTokens += candidatesTokenCount
  }

  for (const element of expectedExcludedElements) {
    const { isCorrect, promptTokenCount, candidatesTokenCount } = await evaluateElementPresence(response, element, false)
    expect(isCorrect).toBe(true)
    totalPromptTokens += promptTokenCount
    totalCandidatesTokens += candidatesTokenCount
  }

  // トークン数の合計をログ出力
  console.log(`✅ 1回目（プロンプト処理）消費トークン: 入力=${promptTokens1}, 出力=${candidatesTokens1}`)
  console.log(`✅ 2回目（評価処理）合計消費トークン: 入力=${totalPromptTokens - promptTokens1}, 出力=${totalCandidatesTokens - candidatesTokens1}`)
  console.log(`✅ 総消費トークン: ${totalPromptTokens + totalCandidatesTokens}\n`)
}, 100000)
