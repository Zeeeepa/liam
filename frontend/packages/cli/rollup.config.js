import typescript from '@rollup/plugin-typescript';

export default {
  input: 'src/cli/index.ts', // ここにCLIのエントリーポイントのパスを指定
  output: {
    file: 'dist-cli/bin/cli.js', // 出力ファイルのパス
    format: 'cjs', // CommonJS形式で出力
  },
  plugins: [
    typescript({
      tsconfig: './tsconfig.node.json' // TypeScript設定ファイルのパス
    })
  ]
};
