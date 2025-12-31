# ISC License
# Copyright (c) 2025 RowDaBoat

import os
import dynlib
import sequtils
import strutils
import compiler
import temple
import strformat
import tables


const nimExt* = ".nim"
const libExt* =
  when defined(windows): ".dll"
  elif defined(macosx): ".dylib"
  else: ".so"
const templateExt = ".nim.template"
const templatesPath = "templates"


const stateTemplate =             staticRead(templatesPath/"state" & templateExt)
const commandTemplate =           staticRead(templatesPath/"command" & templateExt)
const varDeclarationTemplate =    staticRead(templatesPath/"vardeclaration" & templateExt)
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
  varDeclarationTemplate: string
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


proc varDeclaration(self: ReploidVM, variable: VariableDeclaration): string =
  self.varDeclarationTemplate.replace(
    ("declarer", $variable.declarer),
    ("name", variable.name),
    ("type", if variable.typ.len > 0: " : " & variable.typ else: ""),
    ("initializer", if variable.initializer.len > 0: " = " & variable.initializer else: "")
  )


proc getAccessor(self: ReploidVM, variable: VariableDeclaration): string =
  fmt"genGetter({variable.name}, typeof({variable.name}))"


proc setAccessor(self: ReploidVM, variable: VariableDeclaration): string =
  fmt"genSetter({variable.name}, typeof({variable.name}))"


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
    .mapIt(self.varDeclaration(it))
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


proc inferTypes(self: var ReploidVM, output: string) =
  const tag = ":reploid var decl:"
  let varTypes = output.splitLines()
    .mapIt((it.find(tag), it))
    .filterIt(it[0] != -1)
    .mapIt(it[1][(it[0] + tag.len)..^1])
    .mapIt(it.split(":"))
    .mapIt((it[0], it[1]))
    .toTable()

  for i in 0 ..< self.newVariables.len:
    if self.newVariables[i].typ.len == 0:
      self.newVariables[i].typ = varTypes[self.newVariables[i].name]


proc newReploidVM*(compiler: Compiler, tempPath: string = getTempDir()): ReploidVM =
  ## Creates a new ReploidVM with the given compiler and temporary path.
  result = ReploidVM(
    compiler: compiler,

    stateTemplate: stateTemplate,
    commandTemplate: commandTemplate,
    varDeclarationTemplate: varDeclarationTemplate,
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
  ## Checks if the given result is successful.
  toCheck[1] == 0


proc declareImport*(self: var ReploidVM, declaration: string) =
  ## Declares a new import.
  ## This will not be effective until `updateImports` is called.
  self.newImports.add("import " & declaration)


proc declareVar*(self: var ReploidVM, declarer: DeclarerKind, name: string, typ: string = "", initializer: string = "") =
  ## Declares a new variable.
  ## This will not be effective until `updateState` is called.
  ## `declarer`: declarer of the variable, corresponding to `const`, `let` or `var`.
  ## `name`: name of the variable.
  ## `typ`: type of the variable.
  ## `initializer`: initial value of the variable.
  ## one or both of `typ` and `initializer` are required.
  ## **Note: code in `initializer` should never side-effect, as it will be executed each time `updateState` is called.**
  if typ.len == 0 and initializer.len == 0:
    raise newException(Exception, "Type or initializer is required for variable declaration: " & name)

  let declaration = VariableDeclaration(declarer: declarer, name: name, typ: typ, initializer: initializer)
  self.newVariables.add(declaration)


proc declare*(self: var ReploidVM, declaration: string) =
  ## Declares a new `proc`, `template`, `macro`, `iterator`, etc. and/or `type`.
  ## This will not be effective until `updateDeclarations` is called.
  self.newDeclarations.add(declaration)


proc updateImports*(self: var ReploidVM): (string, int) =
  ## Updates the imports.
  ## Compiles all declared imports and returns a success or an error.
  let imports = self.imports & self.newImports
  let source = imports.join("\n")
  let checkSrcPath = self.importsPath & "check" & nimExt
  let checkLibPath = self.importsPath & "check" & libExt

  checkSrcPath.writeFile(source)
  result = self.compiler.compileLibrary(checkSrcPath, checkLibPath)

  if not result.isSuccess:
    self.newImports = @[]
    result[0] = result[0].strip()
    return

  let srcPath = self.importsPath & nimExt
  srcPath.writeFile(source)
  self.imports.add(self.newImports)
  self.newImports = @[]
  result[0] = ""


proc updateDeclarations*(self: var ReploidVM): (string, int) =
  ## Updates the declarations.
  ## Compiles all declarations and returns a success or an error.
  let declarations = self.declarations & self.newDeclarations
  let source = declarations.join("\n\n")
  let checkSrcPath = self.declarationsPath & "check" & nimExt
  let checkLibPath = self.declarationsPath & "check" & libExt

  checkSrcPath.writeFile(source)
  result = self.compiler.compileLibrary(checkSrcPath, checkLibPath)

  if not result.isSuccess:
    self.newDeclarations = @[]
    result[0] = result[0].strip()
    return

  let srcPath = self.declarationsPath & nimExt
  srcPath.writeFile(source)
  self.declarations.add(self.newDeclarations)
  self.newDeclarations = @[]
  result[0] = ""


proc updateState*(self: var ReploidVM): (string, int) =
  ## Updates the state's structure, initializes the new variables while keeping the values of the previous state.
  ## Compiles all variable declarations, and returns a success or an error.
  let newVariables = self.variables & self.newVariables
  let source = self.generateStateSource(newVariables)
  let srcPath = self.statePath & nimExt
  let libPath = self.statePath & $stateId & libExt

  srcPath.writeFile(source)
  result = self.compiler.compileLibrary(srcPath, libPath)

  if not result.isSuccess:
    self.newVariables = @[]
    result[0] = result[0].strip()
    return

  self.inferTypes(result[0])
  let inferredVariables = self.variables & self.newVariables

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
  self.variables = inferredVariables
  self.newVariables = @[]
  result[0] = ""


proc runCommand*(self: var ReploidVM, command: string): (string, int) =
  ## Runs a command.
  ## Compiles the command, runs it, and returns a success or an error.
  let srcPath = self.commandPath & nimExt
  let source = self.generateCommandSource(command)
  srcPath.writeFile(source)

  let libPath = self.commandPath & $commandId & libExt
  result = self.compiler.compileLibrary(srcPath, libPath)

  if not result.isSuccess:
    result[0] = result[0].strip()
    return

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
  ## Returns the source code of the imports.
  self.importsPath & nimExt & ":\n" &
  readFile(self.importsPath & nimExt)


proc declarationsSource*(self: ReploidVM): string =
  ## Returns the source code of the declarations.
  self.declarationsPath & nimExt & ":\n" &
  readFile(self.declarationsPath & nimExt)


proc commandSource*(self: ReploidVM): string =
  ## Returns the source code of the command.
  self.commandPath & nimExt & ":\n" &
  readFile(self.commandPath & nimExt)


proc stateSource*(self: ReploidVM): string =
  ## Returns the source code of the state.
  self.statePath & nimExt & ":\n" &
  readFile(self.statePath & nimExt)


proc clean*(self: var ReploidVM) =
  ## Cleans up the vm, unloading all state libraries.
  for state in self.states:
    unloadLib(state)

  self.newImports = @[]
  self.imports = @[]
  self.newDeclarations = @[]
  self.declarations = @[]
  self.newVariables = @[]
  self.variables = @[]
  self.states = @[]
