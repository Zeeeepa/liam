import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { Command } from 'commander'
import { buildCommand } from './commands/index.js'

const __filename = fileURLToPath(import.meta.url)
const __dirname = path.dirname(__filename)
const root = path.resolve(__dirname, '../../..')
const publicDir = path.join(process.cwd(), 'public')
const outDir = path.join(process.cwd(), 'dist')

const program = new Command()

program.name('liam').description('CLI tool for Liam').version('0.0.0')

const erdCommand = new Command('erd').description('ERD commands')
program.addCommand(erdCommand)

erdCommand
  .command('build')
  .description('Run Vite build')
  .option('--input <path>', 'Path to the .sql file')
  .action((options) => buildCommand(options.input, publicDir, root, outDir))

export { program }
