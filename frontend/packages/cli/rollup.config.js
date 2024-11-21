import commonjs from '@rollup/plugin-commonjs'
import resolve from '@rollup/plugin-node-resolve'
import typescript from '@rollup/plugin-typescript'

export default {
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
      tsconfig: './tsconfig.node.json',
    }),
  ],
  external: ['commander', 'vite'],
}
