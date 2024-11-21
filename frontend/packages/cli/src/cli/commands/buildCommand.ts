import { build } from 'vite'
import { runPreprocess } from '../runPreprocess.js'

export const buildCommand = async (
  inputPath: string,
  publicDir: string,
  root: string,
  outDir: string,
) => {
  console.error('=====1nputPath')
  console.error(inputPath)
  console.error('=====publicDir')
  console.error(publicDir)
  console.error('=====root')
  console.error(root)
  console.error('=====outDir')
  console.error(outDir)
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
