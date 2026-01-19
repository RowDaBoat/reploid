# ISC License
# Copyright (c) 2025 RowDaBoat

import os, strutils, options
import "$nim"/compiler/[ast, vmdef, vm, nimeval, llstream, options]
import nimscripter
import ../[vm, temple]
import sequtils, tables


const templateExt = ".nim.template"
const templatesPath = "templates"

const commandTemplate =        staticRead(templatesPath/"command" & templateExt)
const varDeclarationTemplate = staticRead(templatesPath/"vardeclaration" & templateExt)


type VMErrorMsg = ref object of CatchableError
  discard


type NimSVm* = ref object of Vm
  commandTemplate: string
  varDeclarationTemplate: string
  runIntr: Interpreter
  checkIntr: Interpreter


proc printState(self: NimSVm, message: string) =
  echo message

  for variable in self.variables:
    let symbol = self.runIntr.selectUniqueSymbol(variable.name)
    let value = self.runIntr.getGlobalValue(symbol)
    if value.kind == nkIntLit:
      echo "  ", $symbol, " = ", $value.intVal


proc varDeclaration(self: NimSVm, variable: VariableDeclaration): string =
  self.varDeclarationTemplate.replace(
    ("declarer", $variable.declarer),
    ("name", variable.name),
    ("type", if variable.typ.len > 0: " : " & variable.typ else: ""),
    ("initializer", if variable.initializer.len > 0: " = " & variable.initializer else: "")
  )


proc generateStateSource(self: NimSVm, variables: seq[VariableDeclaration]): string =
  variables.mapIt(self.varDeclaration(it)).join("\n")


proc generateCommandSource(self: NimSVm, command: string): string =
  self.commandTemplate.replace(
    ("command", command)
  )


proc errorHook(config: ConfigRef; info: TLineInfo; msg: string; severity: Severity) {.gcsafe.} =
  if severity == Error and config.error_counter >= config.error_max:
    let fileName = config.m.fileInfos[info.fileIndex.int].fullPath.string
    let error = "$1($2, $3) Error: $4" % [fileName, $info.line, $(info.col + 1), msg]
    raise VMErrorMsg(msg: error)


proc exec(intr: Interpreter, file: string): (string, int) =
  try:
    intr.evalscript(llStreamOpen(readFile(file)))
  except VMErrorMsg as e:
    return (e.msg, 1)

  return ("", 0)


proc getStdPaths(): seq[string] =
  let std = findNimStdLibCompileTime()
  result = @[std]

  for path in walkDirRec(std, yieldFilter = {pcDir}):
    result.add(path)


proc newNimSVm*(tmpPath: string = getTempDir()): NimSVm =
  ## Creates a new Virtual Machine that uses nim script to run commands.
  ## **Strengths**: maximizes speed.
  ## **Weaknesses**: it does not allow integration with native code.
  let stdPaths = getStdPaths()
  let commandBasePath = tmpPath / "command"

  var runIntr = createInterpreter(commandBasePath & nimExt, stdPaths)
  runIntr.registerErrorHook(errorHook)

  var checkIntr = createInterpreter(tmpPath / "check" & nimExt, stdPaths)
  checkIntr.registerErrorHook(errorHook)

  result = NimSVm(
    commandTemplate: commandTemplate,
    varDeclarationTemplate: varDeclarationTemplate,
    runIntr: runIntr,
    checkIntr: checkIntr,

    tmpPath: tmpPath,
    importsBasePath: tmpPath / "imports",
    declarationsBasePath: tmpPath / "declarations",
    stateBasePath: tmpPath / "state",
    commandBasePath: commandBasePath
  )


method updateImports*(self: NimSVm): (string, int) =
  let imports = self.imports & self.newImports
  let source = imports.join("\n")
  let checkSrcPath = self.importsBasePath & checkSuffix & nimExt

  checkSrcPath.writeFile(source)
  result = exec(self.checkIntr, checkSrcPath)

  if not result.isSuccess:
    self.newImports = @[]
    result[0] = result[0].strip()
    return

  let srcPath = self.importsBasePath & nimExt
  srcPath.writeFile(source)
  self.imports.add(self.newImports)
  self.newImports = @[]


method updateDeclarations*(self: NimSVm): (string, int) =
  let declarations = self.declarations & self.newDeclarations
  let incl = "include " & self.importsBasePath & "\n\n"
  let source = incl & declarations.join("\n\n")
  let checkSrcPath = self.declarationsBasePath & checkSuffix & nimExt

  checkSrcPath.writeFile(source)
  result = exec(self.checkIntr, checkSrcPath)

  if not result.isSuccess:
    self.newDeclarations = @[]
    result[0] = result[0].strip()
    return

  let srcPath = self.declarationsBasePath & nimExt
  srcPath.writeFile(source)
  self.declarations.add(self.newDeclarations)
  self.newDeclarations = @[]
  result[0] = ""


proc saveState(self: NimSVm): seq[(string, PSym, PNode)] =
  for variable in self.variables:
    let symbol = self.runIntr.selectUniqueSymbol(variable.name)
    let value = self.runIntr.getGlobalValue(symbol)
    result.add((variable.name, symbol, value))


proc loadState(self: NimSVm, state: seq[(string, PSym, PNode)]) =
  for (name, _, value) in state:
    let symbol = self.runIntr.selectUniqueSymbol(name)
    self.runIntr.setGlobalValue(symbol, value)


proc inferTypes(self: NimSVm, output: string) =
  for i in 0 ..< self.newVariables.len:
    let symbol = self.runIntr.selectUniqueSymbol(self.newVariables[i].name)
    if not symbol.isNil and not symbol.typ.isNil and not symbol.typ.sym.isNil:
      self.newVariables[i].typ = symbol.typ.sym.name.s


method updateState*(self: NimSVm): (string, int) =
  let newVariables = self.variables & self.newVariables
  let stateSource = self.generateStateSource(newVariables)
  let stateSrcPath = self.stateBasePath & nimExt
  let previousStateSource = stateSrcPath.readFile()

  stateSrcPath.writeFile(stateSource)

  let commandSource = self.generateCommandSource("discard")
  let commandSourcePath = self.commandBasePath & nimExt
  let previousCommandSource = commandSourcePath.readFile()

  commandSourcePath.writeFile(commandSource)

  let state = self.saveState()

  result = self.runIntr.exec(commandSourcePath)

  if not result.isSuccess:
    stateSrcPath.writeFile(previousStateSource)
    commandSourcePath.writeFile(previousCommandSource)
    discard self.runIntr.exec(commandSourcePath)

    self.newVariables = @[]
    result[0] = result[0].strip()
    return

  self.loadState(state)
  self.inferTypes(result[0])

  let inferredVariables = self.variables & self.newVariables

  self.variables = inferredVariables
  self.newVariables = @[]
  result[0] = ""


method runCommand*(self: NimSVm, command: string): (string, int) =
  let stateSource = self.generateStateSource(self.variables)
  let stateSrcPath = self.stateBasePath & nimExt

  stateSrcPath.writeFile(stateSource)

  let commandSource = self.generateCommandSource(command)
  let commandSourcePath = self.commandBasePath & nimExt
  let previousCommandSource = commandSourcePath.readFile()
  let state = self.saveState()

  commandSourcePath.writeFile(commandSource)
  result = self.runIntr.exec(commandSourcePath)

  if not result.isSuccess:
    commandSourcePath.writeFile(previousCommandSource)
    discard self.runIntr.exec(commandSourcePath)

    self.newVariables = @[]
    result[0] = result[0].strip()
    return

  self.loadState(state)

  let run = self.runIntr.selectRoutine("run")
  let resultNode = self.runIntr.callRoutine(run, [])

  let output = resultNode[0].strVal
  let error = resultNode[1].strVal

  result = if error.len == 0:
    (output, 0)
  else:
    (error, 1)
