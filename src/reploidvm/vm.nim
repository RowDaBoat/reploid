# ISC License
# Copyright (c) 2025 RowDaBoat

import os
import dynlib
import sequtils
import strutils

import compiler
import temple


const nimExt* = ".nim"
const libExt* = ".lib"
const templateExt = ".nim.template"
const templatesPath = "templates"


const stateTemplate =             staticRead(templatesPath/"state" & templateExt)
const commandTemplate =           staticRead(templatesPath/"command" & templateExt)
const accessorsTemplate =         staticRead(templatesPath/"accessors" & templateExt)
const getAccessorSymbolTemplate = staticRead(templatesPath/"getaccessorsymbol" & templateExt)
const setAccessorSymbolTemplate = staticRead(templatesPath/"setaccessorsymbol" & templateExt)
const stateUpdaterTemplate =      staticRead(templatesPath/"stateupdater" & templateExt)
const loadStateTemplate =         staticRead(templatesPath/"loadstate" & templateExt)
const saveStateTemplate =         staticRead(templatesPath/"savestate" & templateExt)


type Initialize* = proc(oldStateLib: pointer) {.gcsafe, stdcall.}
type Run* = proc(state: pointer): string {.gcsafe, stdcall.}


type VariableDeclaration* = object
  declarer*: string
  name*: string
  typ*: string
  rest*: string


var stateId: int = 0
var commandId: int = 0

type ReploidVM* = object
  stateTemplate: string
  commandTemplate: string
  accessorsTemplate: string
  getAccessorSymbolTemplate: string
  setAccessorSymbolTemplate: string
  stateUpdaterTemplate: string
  loadStateTemplate: string
  saveStateTemplate: string

  compiler: Compiler
  imports: seq[string]
  newImports: seq[string]
  variables: seq[VariableDeclaration]
  newVariables: seq[VariableDeclaration]
  declarations: seq[string]
  newDeclarations: seq[string]
  states: seq[LibHandle]

  importsPath: string
  declarationsPath: string
  statePath: string
  commandPath: string


proc cased(value: string): string =
  result = value
  result[0] = result[0].toUpperAscii()


proc declaration(self: VariableDeclaration): string =
  self.declarer & " " & self.name & "* : " & self.typ & self.rest


proc accessors(self: ReploidVM, variable: VariableDeclaration): string =
  self.accessorsTemplate.replace(
    ("name", variable.name),
    ("casedName", variable.name.cased),
    ("type", variable.typ)
  )


proc loadOldGetAccessor(self: ReploidVM, variable: VariableDeclaration): string =
  self.getAccessorSymbolTemplate.replace(
    ("casedBindingName", "Old" & variable.name.cased),
    ("casedSymbolName", variable.name.cased),
    ("type", variable.typ),
    ("state", "oldStateLib")
  )


proc stateUpdater(self: ReploidVM, variable: VariableDeclaration): string =
  self.stateUpdaterTemplate.replace(
    ("toGet", "Old" & variable.name.cased),
    ("toSet", variable.name)
  )


proc loadGetAccessor(self: ReploidVM, variable: VariableDeclaration): string =
  self.getAccessorSymbolTemplate.replace(
    ("casedBindingName", variable.name.cased),
    ("casedSymbolName", variable.name.cased),
    ("type", variable.typ),
    ("state", "stateLib")
  )


proc loadSetAccessor(self: ReploidVM, variable: VariableDeclaration): string =
  self.setAccessorSymbolTemplate.replace(
    ("casedBindingName", variable.name.cased),
    ("casedSymbolName", variable.name.cased),
    ("type", variable.typ),
    ("state", "stateLib")
  )


proc loadState(self: ReploidVM, variable: VariableDeclaration): string =
  self.loadStateTemplate.replace(
    ("bindingName", variable.name),
    ("casedSymbolName", variable.name.cased),
  )


proc saveState(self: ReploidVM, variable: VariableDeclaration): string =
  self.saveStateTemplate.replace(
    ("bindingName", variable.name),
    ("casedSymbolName", variable.name.cased),
  )


proc generateStateSource(self: ReploidVM, variables: seq[VariableDeclaration]): string =
  let variableDeclarations = variables.mapIt(declaration(it)).join("\n")
  let accessorsDeclarations = variables.mapIt(self.accessors(it)).join("\n")
  let loadOldGetAccessors = self.variables.mapIt(self.loadOldGetAccessor(it)).join("\n")
  let updateState = self.variables.mapIt(self.stateUpdater(it)).join("\n")

  return self.stateTemplate.replace(
    ("variableDeclarations", variableDeclarations),
    ("accessorDeclarations", accessorsDeclarations),
    ("loadOldGetAccessors", loadOldGetAccessors),
    ("updateState", updateState)
  )


proc generateCommandSource(self: ReploidVM, command: string): string =
  let loadGetAccessors = self.variables.mapIt(self.loadGetAccessor(it)).join("\n")
  let loadSetAccessors = self.variables.mapIt(self.loadSetAccessor(it)).join("\n")
  let loadState = self.variables.mapIt(self.loadState(it)).join("\n")
  let saveState = self.variables.mapIt(self.saveState(it)).join("\n")

  self.commandTemplate.replace(
    ("loadGetAccessors", loadGetAccessors),
    ("loadSetAccessors", loadSetAccessors),
    ("loadState", loadState),
    ("command", command),
    ("saveState", saveState)
  )


proc newReploidVM*(compiler: Compiler, tempPath: string = getTempDir()): ReploidVM =
  result = ReploidVM(
    compiler: compiler,

    stateTemplate: stateTemplate,
    commandTemplate: commandTemplate,
    accessorsTemplate: accessorsTemplate,
    getAccessorSymbolTemplate: getAccessorSymbolTemplate,
    setAccessorSymbolTemplate: setAccessorSymbolTemplate,
    stateUpdaterTemplate: stateUpdaterTemplate,
    loadStateTemplate: loadStateTemplate,
    saveStateTemplate: saveStateTemplate,

    importsPath: tempPath / "imports",
    declarationsPath: tempPath / "declarations",
    statePath: tempPath / "state",
    commandPath: tempPath / "command"
  )
  (result.importsPath & nimExt).writeFile("")
  (result.declarationsPath & nimExt).writeFile("")


proc isSuccess*(toCheck: (string, int)): bool =
  toCheck[1] == 0


proc declareImport*(self: var ReploidVM, declaration: string) =
  self.newImports.add(declaration)


proc declareVar*(self: var ReploidVM, declarer: string, name: string, typ: string, rest: string) =
  let declaration = VariableDeclaration(declarer: declarer, name: name, typ: typ, rest: rest)
  self.newVariables.add(declaration)


proc declare*(self: var ReploidVM, declaration: string) =
  self.newDeclarations.add(declaration)


proc updateImports*(self: var ReploidVM): (string, int) =
  let imports = self.imports & self.newImports
  let source = imports.join("\n")
  let srcPath = self.importsPath & nimExt
  let libPath = self.importsPath & libExt

  srcPath.writeFile(source)
  result = self.compiler.compileLibrary(srcPath, libPath)

  if result.isSuccess:
    self.imports.add(self.newImports)

  self.newImports = @[]


proc updateDeclarations*(self: var ReploidVM): (string, int) =
  let declarations = self.declarations & self.newDeclarations
  let source = declarations.join("\n\n")
  let srcPath = self.declarationsPath & nimExt
  let libPath = self.declarationsPath & libExt

  srcPath.writeFile(source)
  result = self.compiler.compileLibrary(srcPath, libPath)

  if result.isSuccess:
    self.declarations.add(self.newDeclarations)

  self.newDeclarations = @[]


proc updateState*(self: var ReploidVM): (string, int) =
  let newVariables = self.variables & self.newVariables
  let source = self.generateStateSource(newVariables)
  let srcPath = self.statePath & nimExt
  let libPath = self.statePath & $stateId & libExt

  srcPath.writeFile(source)

  result = self.compiler.compileLibrary(srcPath, libPath)

  if not result.isSuccess:
    self.newVariables = @[]
    return result

  let newState = loadLib(libPath)
  let initialize = cast[Initialize](newState.symAddr("initialize"))

  if self.states.len > 0:
    initialize(self.states[^1])

  inc stateId
  self.states.add(newState)
  self.variables = newVariables
  self.newVariables = @[]


proc runCommand*(self: var ReploidVM, command: string): (string, int) =
  let srcPath = self.commandPath & nimExt
  let source = self.generateCommandSource(command)
  srcPath.writeFile(source)

  let libPath = self.commandPath & $commandId & libExt
  result = self.compiler.compileLibrary(srcPath, libPath)

  if not result.isSuccess:
    return result

  inc commandId
  let commandLib = loadLib(libPath)
  let run = cast[Run](commandLib.symAddr("run"))
  result[0] = run(if self.states.len == 0: nil else: self.states[^1])
  unloadLib(commandLib)


proc importsSource*(self: ReploidVM): string =
  readFile(self.importsPath & nimExt)


proc declarationsSource*(self: ReploidVM): string =
  readFile(self.declarationsPath & nimExt)


proc clean*(self: var ReploidVM) =
  for state in self.states:
    unloadLib(state)

  self.newImports = @[]
  self.imports = @[]
  self.newDeclarations = @[]
  self.declarations = @[]
  self.newVariables = @[]
  self.variables = @[]
  self.states = @[]
