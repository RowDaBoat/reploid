# ISC License
# Copyright (c) 2025 RowDaBoat

import unittest
import ../src/vm/vm
import ../src/vm/compiler
import strutils

suite "Reploid's Virtual Machine should:":
  setup:
    let nim = newNimCompiler("nim", @[])
    var vm = newVm(nim)
    var result: (string, int)

  teardown:
    vm.clean()


  test "run a simple command":
    result = vm.runCommand("echo \"Protobot.\"")
    check result == ("", 0)


  test "return an int value":
    let value = 100001
    result = vm.runCommand($value)
    check result == ("'" & $value & "' type: int", 0)


  test "return a string value":
    let value = "Protobot."
    result = vm.runCommand('"' & value & '"')
    check result == ("'" & value & "' type: string", 0)


  test "declare a variable":
    vm.declareVar(DeclarerKind.Var, "x", "int", "20")

    result = vm.updateState()
    assert result[1] == 0, "Failed to update state: " & result[0]

    result = vm.runCommand("x")
    check result == ("'20' type: int", 0)


  test "update the value of a variable":
    vm.declareVar(DeclarerKind.Var, "x", "int", "20")

    result = vm.updateState()
    assert result[1] == 0, "Failed to update state: " & result[0]

    result = vm.runCommand("inc x")
    assert result[1] == 0, "Failed to run command: " & result[0]

    result = vm.runCommand("x")
    check result == ("'21' type: int", 0)


  test "update many times the value of a variable":
    let start = 20
    vm.declareVar(DeclarerKind.Var, "x", "int", $start)

    result = vm.updateState()
    check result == ("", 0)

    for i in 0 ..< 5:
      result = vm.runCommand("inc x")
      check result == ("", 0)

      result = vm.runCommand("x")
      check result == ("'" & $(start + i + 1) & "' type: int", 0)


  test "initialize a string variable":
    let value = "Protobot."
    vm.declareVar(DeclarerKind.Var, "x", "string", "\"" & value & "\"")

    result = vm.updateState()
    assert result[1] == 0, "Failed to update state: " & result[0]

    result = vm.runCommand("x")
    check result == ("'" & value & "' type: string", 0)


  test "import a library":
    vm.declareImport("strutils")

    result = vm.updateImports()
    assert result[1] == 0, "Failed to update imports: " & result[0]

    result = vm.runCommand("@[\"Imports\", \"are\", \"working.\"].join(\" \")")
    check result == ("'Imports are working.' type: string", 0)


  test "properly handle reference objects":
    vm.declareImport("test/localcode")
    result = vm.updateImports()
    assert result[1] == 0, "Failed to update imports: " & result[0]

    result = vm.runCommand("newTest(\"Test\", 10)")
    check result == ("'[name: Test count: 10]' type: Test", 0)


  test "not crash when using a ref object":
    vm.declare("""
      type R = ref object
    """.unindent(6))

    vm.declare("""
      type O = object
        r: R
        s: seq[int]
    """.unindent(6))
    result = vm.updateDeclarations()
    assert result[1] == 0, "Failed to update declarations: " & result[0]

    vm.declareVar(DeclarerKind.Var, "o", "O", "")
    result = vm.updateState()
    assert result[1] == 0, "Failed to update state: " & result[0]

    vm.declareVar(DeclarerKind.Var, "u", "O", "")
    result = vm.updateState()
    check result[1] == 0


  test "infer types of a simple variable":
    vm.declareVar(DeclarerKind.Var, "x", initializer = "\"Protobot.\"")
    result = vm.updateState()
    assert result[1] == 0, "Failed to update state: " & result[0]

    result = vm.runCommand("x")
    check result == ("'Protobot.' type: string", 0)
