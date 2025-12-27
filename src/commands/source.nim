# ISC License
# Copyright (c) 2025 RowDaBoat

import commands
import ../repl/evaluation
import ../reploidvm/vm


proc sourceCmd*(commandsApi: var CommandsApi, args: seq[string]): Evaluation =
  if args.len == 0:
    return Evaluation(kind: Success, result: "Usage: source <imports|declarations|state|command>")

  case args[0]:
  of "imports":
    return Evaluation(kind: Success, result: commandsApi.vm.importsSource)
  of "declarations":
    return Evaluation(kind: Success, result: commandsApi.vm.declarationsSource)
  of "command":
    return Evaluation(kind: Success, result: commandsApi.vm.commandSource)
  of "state":
    return Evaluation(kind: Success, result: commandsApi.vm.stateSource)
  else:
    return Evaluation(kind: Error, result: "Invalid source: " & args[0])
