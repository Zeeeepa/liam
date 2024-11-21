import commonjs from '@rollup/plugin-commonjs'
import resolve from '@rollup/plugin-node-resolve'
import typescript from '@rollup/plugin-typescript'
import execute from 'rollup-plugin-execute';

export default {
  input: 'bin/cli.ts',
  output: {
    file: 'dist-cli/bin/cli/index.js',
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
    execute('chmod +x dist-cli/bin/cli/index.js'),
  ],
  external: ['commander', 'vite'],
}
