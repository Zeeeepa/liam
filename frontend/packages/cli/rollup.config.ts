import commonjs from '@rollup/plugin-commonjs'
import resolve from '@rollup/plugin-node-resolve'
import typescript from '@rollup/plugin-typescript'
import type { RollupOptions } from 'rollup'
import execute from 'rollup-plugin-execute'

const config: RollupOptions = {
  input: 'bin/cli.ts',
  output: {
    file: 'dist-cli/bin/cli.js',
    format: 'esm',
  },
  plugins: [
    resolve({
      preferBuiltins: true,
      extensions: ['.mjs', '.js', '.json', '.node', '.ts'],
    }),
    commonjs(),
    typescript({
      outputToFilesystem: true,
      tsconfig: './tsconfig.node.json',
    }),
    execute('chmod +x dist-cli/bin/cli.js'),
  ],
  external: ['commander', 'vite'],
}

export default config
