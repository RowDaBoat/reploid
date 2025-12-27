# ISC License
# Copyright (c) 2025 RowDaBoat

import commands
import ../repl/evaluation
import ../reploidvm/vm


proc importsSource*(commandsApi: var CommandsApi, args: seq[string]): Evaluation =
  Evaluation(kind: Success, result: commandsApi.vm.importsSource)
