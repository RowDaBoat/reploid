# ISC License
# Copyright (c) 2025 RowDaBoat

import vm
import compiler

let nimCompiler = newNimCompiler("nim", @[])
var reploidVM = newReploidVM(nimCompiler)
var result: (string, int)

echo "Running a basic command:"
reploidVM.declareVar("var", "x", "int", "")
discard reploidVM.updateState()

for i in 0 ..< 2:
  result = reploidVM.runCommand("""
x += 1
echo "Counting x: ", x
"""
    )
  assert result.isSuccess, "Failed to run command: " & result[0]

reploidVM.declareVar("var", "y", "int", "")
discard reploidVM.updateState()

for i in 0 ..< 8:
  result = reploidVM.runCommand("""
x += 1
y += 1
echo "Counting x: ", x
echo "Counting y: ", y
"""
    )
  assert result.isSuccess, "Failed to run command: " & result[0]

reploidVM.clean()
echo ""

echo "Running an import..."
reploidVM.declareImport("import strutils")
result = reploidVM.updateImports()
assert result.isSuccess, "Failed to update imports: " & result[0]
echo "Imports updated successfully."

echo "Updating state..."
reploidVM.declareVar("var", "name", "string", "")

result = reploidVM.updateState()
assert result.isSuccess, "Failed to update state: " & result[0]
echo "State updated successfully."

echo "Running a command..."
var source = """
name = "Protobot"; echo name, " has ", name.count('o'), " o's."
"""
result = reploidVM.runCommand(source)
assert result.isSuccess, "Failed to run command: " & result[0]
echo "Command run successfully."

reploidVM.clean()
echo ""
