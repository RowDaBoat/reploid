# ISC License
# Copyright (c) 2025 RowDaBoat

import output
import welcome
import reader
import evaluator


if isMainModule:
  let output = newOutput()
  output.welcome("nim")

  var reader = newReader(output)
  var evaluator = newEvaluator(output)
  var finished = false

  while not finished:
    let input = reader.read()
    finished = evaluator.eval(input)
