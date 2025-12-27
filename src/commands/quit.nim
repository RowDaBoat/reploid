# ISC License
# Copyright (c) 2025 RowDaBoat

import commands
import ../repl/evaluation


proc quitReploid*(commandsApi: var CommandsApi, args: seq[string]): Evaluation =
  Evaluation(kind: Quit)
