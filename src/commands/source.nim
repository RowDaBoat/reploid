# ISC License
# Copyright (c) 2025 RowDaBoat

import commands
import ../repl/evaluation
import ../vm/vm


proc toSource(path: string): string =
  path & ":\n" &
  readFile(path)


proc sourceCmd*(commandsApi: var CommandsApi, args: seq[string]): Evaluation =
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
