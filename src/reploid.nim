# ISC License
# Copyright (c) 2025 RowDaBoat

import output
import welcome
import reader
import evaluator
import printer
import evaluation

if isMainModule:
  let output = newOutput()
  output.welcome("nim")

  var reader = newReader(output)
  var evaluator = newEvaluator()
  var printer = newPrinter(output)
  var evaluation = Evaluation()

  while evaluation.kind != Quit:
    let input = reader.read()
    evaluation = evaluator.eval(input)
    printer.print(evaluation)
