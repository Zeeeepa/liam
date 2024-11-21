import { fileURLToPath } from 'url'
import { dirname } from 'path'
import { exec } from 'child_process'
import { runPreprocess } from '../runPreprocess.js'
import { resolve } from 'path'

export const buildCommand = async (
  inputPath: string,
  outDir: string,
) => {
  // convert
  runPreprocess(inputPath, outDir)

  const __filename = fileURLToPath(import.meta.url);
  const __dirname = dirname(__filename);
  const cliHtmlPath = resolve(__dirname, '../../../html')
  // cp -R html
  exec(`cp -R ${cliHtmlPath} ${outDir}/dist/`, (_error, _stdout, _stderr) => {})
}
