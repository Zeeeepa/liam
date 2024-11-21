import { exec } from 'node:child_process'
import { dirname } from 'node:path'
import { resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import { runPreprocess } from '../runPreprocess.js'

export const buildCommand = async (inputPath: string, outDir: string) => {
  // convert
  runPreprocess(inputPath, outDir)

  const __filename = fileURLToPath(import.meta.url)
  const __dirname = dirname(__filename)
  const cliHtmlPath = resolve(__dirname, '../html')
  exec(`mkdir -p ${outDir}/`, (_error, _stdout, _stderr) => {})
  // cp -R html
  exec(`cp -R ${cliHtmlPath}/* ${outDir}/`, (_error, _stdout, _stderr) => {})
}
