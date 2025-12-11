# ISC License
# Copyright (c) 2025 RowDaBoat

import input
import output #TODO: remove
import strutils


type Evaluator* = object
  output: Output#[TODO: remove]#


proc newEvaluator*(output: Output#[TODO: remove]#): Evaluator =
  Evaluator(output: output)


proc eval*(self: Evaluator, input: Input): bool =
  case input.kind:
  of Lines:
    if input.lines != "":
      if "error" in input.lines: #TODO: remove
        self.output.error(input.lines)
      else:
        self.output.okResult(input.lines)
      return false
  of Reset:
    return false
  of Editor:
    return false
  of Quit:
    return true
  of EOF:
    return true
