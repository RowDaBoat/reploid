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
  var quit = false

  while not quit:
    let input = reader.read()
    let evaluation = evaluator.eval(input)
    printer.print(evaluation)
    quit = evaluation.kind == Quit

  reader.cleanup()
