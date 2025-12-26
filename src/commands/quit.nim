import commands
import ../repl/evaluation

proc quitReploid*(commandsApi: var CommandsApi, args: seq[string]): Evaluation =
  Evaluation(kind: Quit)
