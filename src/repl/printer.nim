# ISC License
# Copyright (c) 2025 RowDaBoat

import styledoutput
import evaluation
import strutils


type Printer* = object
  output: Output


proc formatError(error: string): string =
  let start = error.find(" Error: ")
  result = if start == -1: error else: error[(start + 1)..^1]


proc printWithFormat(output: Output, lines: string, error: bool = false) =
  if lines.len == 0:
    return

  for line in lines.split("\n"):
    let errorStart = line.find(" Error: ")
    let warningStart = line.find(" Warning: ")
    let notUsedStart = line.find(" Warning: imported and not used: ")
    let showIfTypedLine = line.find(" template/generic instantiation of `showIfTyped` from here")

    if notUsedStart != -1 or showIfTypedLine != -1:
      discard
    elif warningStart != -1:
      output.warning(line[(warningStart + 1)..^1])
    elif errorStart != -1:
      output.error(line[(errorStart + 1)..^1])
    elif error:
      output.error(line)
    else:
      output.okResult(line)

    output.write("\n")


proc newPrinter*(output: Output): Printer =
  Printer(output: output)


proc print*(self: Printer, evaluation: Evaluation) =
  case evaluation.kind:
  of Success:
    self.output.printWithFormat(evaluation.result)
  of Error:
    self.output.printWithFormat(evaluation.result, true)
  of Quit:
    discard
  of Empty:
    discard
