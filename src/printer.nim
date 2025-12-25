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


proc newPrinter*(output: Output): Printer =
  Printer(output: output)


proc print*(self: Printer, evaluation: Evaluation) =
  case evaluation.kind:
  of Success:
    self.output.okResult(evaluation.result)
  of Error:
    self.output.error(evaluation.result.formatError)
  of Quit:
    discard
  of Empty:
    discard
