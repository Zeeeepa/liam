import path from 'node:path'
import { Command } from 'commander'
import { buildCommand } from './commands/index.js'

const distDir = path.join(process.cwd(), 'dist')

const program = new Command()

program.name('liam').description('CLI tool for Liam').version('0.0.0')

const erdCommand = new Command('erd').description('ERD commands')
program.addCommand(erdCommand)

erdCommand
  .command('build')
  .description('Run Vite build')
  .option('--input <path>', 'Path to the .sql file')
  .action((options) => buildCommand(options.input, distDir))

export { program }
