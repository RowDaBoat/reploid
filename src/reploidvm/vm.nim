# ISC License
# Copyright (c) 2025 RowDaBoat

import os
import dynlib
import sequtils
import strutils
import compiler
import temple


const nimExt* = ".nim"
const libExt* =
  when defined(windows): ".dll"
  elif defined(macosx): ".dylib"
  else: ".so"
const templateExt = ".nim.template"
const templatesPath = "templates"


const stateTemplate =             staticRead(templatesPath/"state" & templateExt)
const commandTemplate =           staticRead(templatesPath/"command" & templateExt)
const getAccessorTemplate =       staticRead(templatesPath/"getaccessor" & templateExt)
const setAccessorTemplate =       staticRead(templatesPath/"setaccessor" & templateExt)
const getAccessorSymbolTemplate = staticRead(templatesPath/"getaccessorsymbol" & templateExt)
const setAccessorSymbolTemplate = staticRead(templatesPath/"setaccessorsymbol" & templateExt)
const stateUpdaterTemplate =      staticRead(templatesPath/"stateupdater" & templateExt)
const loadStateTemplate =         staticRead(templatesPath/"loadstate" & templateExt)
const saveStateTemplate =         staticRead(templatesPath/"savestate" & templateExt)


type Initialize* = proc(oldStateLib: pointer) {.stdcall.}
type Run* = proc(state: pointer): string {.stdcall.}
type DeclarerKind* = enum Const, Let, Var


type VariableDeclaration* = object
  declarer*: DeclarerKind
  name*: string
  typ*: string
  initializer*: string


var stateId: int = 0
var commandId: int = 0

type ReploidVM* = object
  stateTemplate: string
  commandTemplate: string
  getAccessorTemplate: string
  setAccessorTemplate: string
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


proc `$`(self: DeclarerKind): string =
  case self:
  of DeclarerKind.Const: "const"
  of DeclarerKind.Let: "let"
  of DeclarerKind.Var: "var"


proc varDeclaration(self: VariableDeclaration): string =
  var initializer = if self.initializer.len > 0: " = " & self.initializer else: ""
  $self.declarer & " " & self.name & "* : " & self.typ & initializer


proc getAccessor(self: ReploidVM, variable: VariableDeclaration): string =
  self.getAccessorTemplate.replace(
    ("name", variable.name),
    ("casedName", variable.name.cased),
    ("type", variable.typ)
  )


proc setAccessor(self: ReploidVM, variable: VariableDeclaration): string =
  self.setAccessorTemplate.replace(
    ("name", variable.name),
    ("casedName", variable.name.cased),
    ("type", variable.typ)
  )

proc accessors(self: ReploidVM, variable: VariableDeclaration): string =
    result = self.getAccessor(variable)

    if variable.declarer == DeclarerKind.Var:
      result &= "\n" & self.setAccessor(variable)

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
    ("declarer", if variable.declarer == DeclarerKind.Var: "var" else: "let"),
    ("bindingName", variable.name),
    ("casedSymbolName", variable.name.cased),
  )


proc saveState(self: ReploidVM, variable: VariableDeclaration): string =
  self.saveStateTemplate.replace(
    ("bindingName", variable.name),
    ("casedSymbolName", variable.name.cased),
  )


proc generateStateSource(self: ReploidVM, variables: seq[VariableDeclaration]): string =
  let oldVariables = self.variables

  let variableDeclarations = variables
    .mapIt(varDeclaration(it))
    .join("\n")

  let accessorsDeclarations = variables
    .mapIt(self.accessors(it))
    .join("\n")

  let loadOldGetAccessors = oldVariables
    .filterIt(it.declarer == DeclarerKind.Var)
    .mapIt(self.loadOldGetAccessor(it))
    .join("\n")

  let updateState = oldVariables
    .filterIt(it.declarer == DeclarerKind.Var)
    .mapIt(self.stateUpdater(it))
    .join("\n")

  return self.stateTemplate.replace(
    ("variableDeclarations", variableDeclarations),
    ("accessorDeclarations", accessorsDeclarations),
    ("loadOldGetAccessors", loadOldGetAccessors),
    ("updateState", updateState)
  )


proc generateCommandSource(self: ReploidVM, command: string): string =
  let variables = self.variables

  let loadGetAccessors = variables
    .mapIt(self.loadGetAccessor(it))
    .join("\n")

  let loadSetAccessors = variables
    .filterIt(it.declarer == DeclarerKind.Var)
    .mapIt(self.loadSetAccessor(it))
    .join("\n")

  let loadState = variables
    .mapIt(self.loadState(it))
    .join("\n")

  let saveState = variables
    .filterIt(it.declarer == DeclarerKind.Var)
    .mapIt(self.saveState(it))
    .join("\n")

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
    getAccessorTemplate: getAccessorTemplate,
    setAccessorTemplate: setAccessorTemplate,
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
  (result.statePath & nimExt).writeFile("")
  (result.commandPath & nimExt).writeFile("")

proc isSuccess*(toCheck: (string, int)): bool =
  toCheck[1] == 0


proc declareImport*(self: var ReploidVM, declaration: string) =
  self.newImports.add("import " & declaration)


proc declareVar*(self: var ReploidVM, declarer: DeclarerKind, name: string, typ: string, initializer: string = "") =
  let declaration = VariableDeclaration(declarer: declarer, name: name, typ: typ, initializer: initializer)
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
  let nimMain = cast[proc(){.cdecl.}](newState.symAddr("NimMain"))
  let initialize = cast[Initialize](newState.symAddr("initialize"))


  if nimMain.isNil:
    raise newException(Exception, "Failed to get 'NimMain' symbol from state library: " & libPath)

  if initialize.isNil:
    raise newException(Exception, "Failed to get 'initialize' symbol from state library: " & libPath)

  nimMain()

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

  let commandLib = loadLib(libPath)

  if commandLib.isNil:
    raise newException(Exception, "Failed to load command library: " & libPath)

  inc commandId
  let runPointer = commandLib.symAddr("run")

  if runPointer.isNil:
    raise newException(Exception, "Failed to get 'run' symbol from command library: " & libPath)

  block:
    let run = cast[Run](runPointer)
    result[0] = "" & run(if self.states.len == 0: nil else: self.states[^1])

  unloadLib(commandLib)


proc importsSource*(self: ReploidVM): string =
  self.importsPath & nimExt & ":\n" &
  readFile(self.importsPath & nimExt)


proc declarationsSource*(self: ReploidVM): string =
  self.declarationsPath & nimExt & ":\n" &
  readFile(self.declarationsPath & nimExt)


proc commandSource*(self: ReploidVM): string =
  self.commandPath & nimExt & ":\n" &
  readFile(self.commandPath & nimExt)


proc stateSource*(self: ReploidVM): string =
  self.statePath & nimExt & ":\n" &
  readFile(self.statePath & nimExt)


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
