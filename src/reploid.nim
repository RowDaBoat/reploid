# ISC License
# Copyright (c) 2025 RowDaBoat

import strformat
import os
import tables
import cliquet
import sequtils
import reploidvm/compiler
import reploidvm/vm
import repl/reader
import repl/evaluator
import repl/printer
import repl/welcome
import repl/styledoutput
import repl/evaluation
import commands/commands
import commands/source
import commands/quit


type Configuration = object
  help    {.help: "Show this help message".}            : bool
  nim     {.help: "Path to the nim compiler".}          : string
  welcome {.help: "Show welcome message".}              : bool
  flags   {.help: "Flags to pass to the nim compiler".} : seq[string]
  config  {.help: "Configuration file to use".}         : string
  history {.help: "History file to use".}               : string
  colors  {.help: "Display colors".}                    : bool
  imports {.help: "Preload imports"}                    : seq[string]


proc preloadImports(vm: var ReploidVM, imports: seq[string], output: Output) =
  for toPreload in imports:
    vm.declareImport(toPreload)

  let updateResult = vm.updateImports()
  if not updateResult.isSuccess:
    output.error(fmt"Failed to preload imports: {updateResult[0]}")


proc defaultConfig*(): Configuration =
  let reploidDir = getHomeDir()/".reploid"
  result = Configuration(
    nim: "nim",
    welcome: true,
    flags: @[],
    config: reploidDir/"config",
    history: reploidDir/"history",
    colors: true,
    help: false
  )


proc defaultCommands*(): Table[string, Command] = commands(
  command("source", "<imports|declarations|state|command> shows the source of imports, declarations, the current state, or the last command", sourceCmd),
  command("quit", "quits reploid", quitCmd)
)


proc reploid*(
  configuration: Configuration = defaultConfig(),
  commands: Table[string, Command] = defaultCommands()
) =
  let output = newOutput(colors = configuration.colors)
  let compiler = newNimCompiler(configuration.nim, configuration.flags)

  if configuration.welcome:
    output.welcome(configuration.nim)

  if compiler.path[1] != 0:
    output.error(fmt"Error: '{configuration.nim}' not found, make sure '{configuration.nim}' is in PATH")
    return

  var vm = newReploidVM(compiler)

  var commandsApi = CommandsApi(
    output: output,
    compiler: compiler,
    vm: vm
  )
  var reader = newReader(output, historyFile = configuration.history)
  var evaluator = newEvaluator(commandsApi, commands, vm)
  var printer = newPrinter(output)
  var quit = false

  vm.preloadImports(configuration.imports, output)

  while not quit:
    let input = reader.read()
    let evaluation = evaluator.eval(input)
    printer.print(evaluation)
    quit = evaluation.kind == Quit

  reader.cleanup()


proc createDirs(path: string) =
  var pathToCheck = path
  var paths: seq[string] 

  while not dirExists(pathToCheck):
    paths.add(pathToCheck)
    (pathToCheck, _) = pathToCheck.splitPath

  for i in countdown(paths.high, 0):
    createDir(paths[i])


proc prepareConfigFile(cli: var Cliquet[Configuration], config: Configuration) =
  let configFilePath = config.config
  let output = newOutput(colors = config.colors)

  if not fileExists(configFilePath):
    try:
      configFilePath.parentDir.createDirs()
      writeFile(configFilePath, cli.generateConfig())
    except:
      output.error(fmt"Failed to create config file '{configFilePath}', check permissions and try again.")
      quit(1)


proc prepareHistoryFile(cli: var Cliquet[Configuration], config: Configuration) =
  createDirs(config.history.parentDir)


proc helpAndQuit(cli: var Cliquet[Configuration]) =
  echo cli.generateUsage()
  echo ""
  echo cli.generateHelp()
  quit(0)


when isMainModule:
  var cli = initCliquet(default = defaultConfig())
  let args = commandLineParams()
  discard cli.parseOptions(args)

  let preConfiguration = cli.config()
  prepareConfigFile(cli, preConfiguration)
  let configFileContents = preConfiguration.config.readFile()
  cli.parseConfig(configFileContents)
  let configuration = cli.config()
  prepareHistoryFile(cli, preConfiguration)

  let output = newOutput(colors = configuration.colors)
  let unmetRequirements = cli.unmetRequirments()

  for requirement in unmetRequirements:
    output.error(fmt"'{requirement}' has to be provided as an option or in the '{configuration.config}' configuration file.")

  for unknown in cli.unknownOptions():
    output.warning(fmt"'{unknown}' is an unknown option.")

  for unknown in cli.unknownConfigs():
    output.warning(fmt"'{unknown}' is an unknown configuration in the '{configuration.config}' configuration file.")

  if unmetRequirements.len > 0 or configuration.help:
    cli.helpAndQuit();

  reploid(configuration)
