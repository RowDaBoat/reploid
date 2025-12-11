# ISC License
# Copyright (c) 2025 RowDaBoat

import compiler
import vm

let nimCompiler = newNimCompiler("nim")
var reploidVM = newReploidVM(nimCompiler)

reploidVM.declareVar("var", "x", "int")
discard reploidVM.rebuildState()

for i in 0 ..< 2:
  reploidVM.runCommand("""
x += 1
echo "Counting x: ", x
"""
  )

reploidVM.declareVar("var", "y", "int")
discard reploidVM.rebuildState()

for i in 0 ..< 8:
  reploidVM.runCommand("""
x += 1
y += 1
echo "Counting x: ", x
echo "Counting y: ", y
"""
    )

reploidVM.clean()
