import resolve from '@rollup/plugin-node-resolve';
import commonjs from '@rollup/plugin-commonjs';
import typescript from '@rollup/plugin-typescript';

export default {
  input: 'bin/cli.ts',
  output: {
    file: 'dist-cli/bin/cli.js',
    format: 'esm',  // ECMAScript モジュール形式で出力
  },
  plugins: [
    resolve({
      preferBuiltins: true,
      extensions: ['.mjs', '.js', '.json', '.node', '.ts']
    }),
    commonjs(),
    typescript({
        tsconfig: './tsconfig.node.json' // TypeScript設定ファイルのパス
    })
  ],
  external: ['commander', 'vite']
};
