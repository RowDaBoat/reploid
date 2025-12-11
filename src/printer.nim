# ISC License
# Copyright (c) 2025 RowDaBoat

import output
import evaluation


type Printer* = object
  output: Output


proc newPrinter*(output: Output): Printer =
  Printer(output: output)


proc print*(self: Printer, evaluation: Evaluation) =
  case evaluation.kind:
  of Success:
    self.output.okResult(evaluation.result)
  of Error:
    self.output.error(evaluation.result)
  of Quit:
    discard
  of Empty:
    discard
