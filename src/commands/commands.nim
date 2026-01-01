# ISC License
# Copyright (c) 2025 RowDaBoat

import tables
import sequtils
import strutils
import ../repl/evaluation
import ../vm/compiler
import ../vm/vm
import ../repl/styledoutput


type CommandsApi* = object
  output*: Output
  compiler*: Compiler
  vm*: Vm


type CommandProc* = proc(api: var CommandsApi, args: seq[string]): Evaluation


type Command* = object
  name*: string
  help*: string
  run*: CommandProc


proc command*(name: string, help: string, run: CommandProc): Command =
  Command(name: name, help: help, run: run)


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


proc commands*(commands: varargs[Command]): Table[string, Command] = 
  result = commands
    .mapIt((it.name, it))
    .toTable()

  let helpCommand = buildHelpCommand(commands.toSeq)
  result[helpCommand.name] = helpCommand
