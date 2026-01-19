# ISC License
# Copyright (c) 2025 RowDaBoat

import std/paths, tables, sequtils, strutils
import evaluation, styledoutput
import ../vm/vm


type CommandsApi* = object
  output*: Output
  vm*: Vm


type CommandProc* = proc(api: var CommandsApi, args: seq[string]): Evaluation


type Command* = object
  name*: string
  help*: string
  run*: CommandProc


proc toSource(path: Path): string =
  path.string & ":\n" &
  readFile(path.string)


proc buildHelpLine(name: string, help: string, maxWidth: int): string =
  "  " & name & ":" & " ".repeat(maxWidth - name.len) & "  " & help


proc buildHelpCommand(commands: seq[Command]): Command =
  result.name = "help"
  var maxWidth = commands.mapIt(it.name.len).max()
  maxWidth = max(maxWidth, result.name.len)

  let helpText = "Commands:\n" & commands
    .mapIt(buildHelpLine(it.name, it.help, maxWidth))
    .join("\n") & "\n" &
    buildHelpLine(result.name, "show this help message", maxWidth)

  result.help = "shows this help message"
  result.run = proc(commandsApi: var CommandsApi, args: seq[string]): Evaluation =
    Evaluation(kind: Success, result: helpText)


proc command*(name: string, help: string, run: CommandProc): Command =
  ## Creates a new command with a help and run proc.
  Command(name: name, help: help, run: run)


proc commands*(commands: varargs[Command]): Table[string, Command] = 
  ## Creates a commands table.
  result = commands
    .mapIt((it.name, it))
    .toTable()

  let helpCommand = buildHelpCommand(commands.toSeq)
  result[helpCommand.name] = helpCommand


proc sourceCmd*(commandsApi: var CommandsApi, args: seq[string]): Evaluation =
  ## Shows the generated source code for each component of Reploid's vm.
  ## - **imports**: the declared imports.
  ## - **declarations**: type, proc, template, macro, func, method, iterator, and converter declarations.
  ## - **state**: variable declarations that hold the state of the vm, including internal getters and setters.
  ## - **command**: the last command that was run.
  if args.len == 0:
    return Evaluation(kind: Success, result: "Usage: source <imports|declarations|state|command>")

  case args[0]:
  of "imports":
    return Evaluation(kind: Success, result: commandsApi.vm.importsPath.toSource)
  of "declarations":
    return Evaluation(kind: Success, result: commandsApi.vm.declarationsPath.toSource)
  of "command":
    return Evaluation(kind: Success, result: commandsApi.vm.commandPath.toSource)
  of "state":
    return Evaluation(kind: Success, result: commandsApi.vm.statePath.toSource)
  else:
    return Evaluation(kind: Error, result: "Invalid source: " & args[0])


proc quitCmd*(commandsApi: var CommandsApi, args: seq[string]): Evaluation =
  Evaluation(kind: Quit)
