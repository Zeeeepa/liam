import { build } from 'vite'
import { runPreprocess } from '../runPreprocess.js'

export const buildCommand = async (
  inputPath: string,
  publicDir: string,
  root: string,
  outDir: string,
) => {
  runPreprocess(inputPath, publicDir)
  await build({
    publicDir,
    root,
    build: {
      outDir,
      emptyOutDir: false,
    },
  })
}
