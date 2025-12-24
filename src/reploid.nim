# ISC License
# Copyright (c) 2025 RowDaBoat

import strformat
import styledoutput
import sequtils
import welcome
import compiler
import reploidvm/vm
import reader
import evaluator
import printer
import evaluation
import cliquet
import os


type Configuration = object
  help    {.help: "Show this help message".}            : bool
  nim     {.help: "Path to the nim compiler".}          : string
  welcome {.help: "Show welcome message".}              : bool
  flags   {.help: "Flags to pass to the nim compiler".} : seq[string]
  config  {.help: "Configuration file to use".}         : string
  history {.help: "History file to use".}               : string
  colors  {.help: "Display colors".}                    : bool

# DONE: manage dynamic libraries
# DONE: cleanup on exit
# DONE: integrate command line args using cliquet
# DONE: integrate rc configuration file
# DONE: add declarations for procs and types
# DONE: declare let, var, const
# DONE: support type declarations
# DONE: parametrize tmp paths
# DONE: import templates in compile time
# DONE: integrate ReploidVM
# TODO: success and error output
# TODO: integrate commands
# TODO: integrate tcc
# TODO: properly support let and const
# TODO: rewrite tests
# TODO: write docs
# TODO: options:
# TODO:   "prelude": "Nim scripts to preload"
# TODO:   "showTypes": "Show var types when printing var without echo"
# TODO:   "noAutoIndent": "Disable automatic indentation"
# TODO:   "withTools": "Load handy tools"
# TODO:   "backend": "Backend to use [script, static, dynamic]"

proc reploid(configuration: Configuration) =
  let output = newOutput(colors = configuration.colors)
  let compiler = newNimCompiler(configuration.nim, configuration.flags)

  if configuration.welcome:
    output.welcome(configuration.nim)

  if compiler.path[1] != 0:
    output.error(fmt"Error: '{configuration.nim}' not found, make sure '{configuration.nim}' is in PATH")
    return

  var vm = newReploidVM(compiler)
  var reader = newReader(output, historyFile = configuration.history)
  var evaluator = newEvaluator(vm)
  var printer = newPrinter(output)
  var quit = false

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
  let reploidDir = getHomeDir()/".reploid"
  let configFile = reploidDir/"config"
  let historyFile = reploidDir/"history"

  var cli = initCliquet(
    default = Configuration(
      nim: "nim",
      welcome: true,
      flags: @[],
      config: configFile,
      history: historyFile,
      colors: true,
      help: false
    )
  )

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
