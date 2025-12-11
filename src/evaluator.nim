# ISC License
# Copyright (c) 2025 RowDaBoat

import input
import strutils
import evaluation


type Evaluator* = object
  discard

proc evaluateLines*(lines: string): Evaluation =
  if lines == "":
    return Evaluation(kind: Empty)

  if "error" in lines:
    return Evaluation(kind: Error, result: lines)

  return Evaluation(kind: Success, result: lines)

proc newEvaluator*(): Evaluator =
  Evaluator()


proc eval*(self: Evaluator, input: Input): Evaluation =
  case input.kind:
  of Lines:
    return evaluateLines(input.lines)
  of Reset:
    return Evaluation(kind: Empty)
  of Editor:
    return Evaluation(kind: Empty)
  of Quit:
    return Evaluation(kind: Quit)
  of EOF:
    return Evaluation(kind: Quit)
