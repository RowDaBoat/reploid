import os
import dynlib
import sequtils
import strutils

import compiler
import temple


const nimExt = ".nim"
const libExt = ".lib"
const templateExt = ".nim.template"

const tempPath = "tmp"
const statePath = tempPath/"state"
const commandPath = tempPath/"command"
const templatesPath = "templates"
const stateTemplatePath = templatesPath/"state" & templateExt
const commandTemplatePath = templatesPath/"command" & templateExt
const accessorsTemplatePath = templatesPath/"accessors" & templateExt
const getAccessorSymbolTemplatePath = templatesPath/"getaccessorsymbol" & templateExt
const setAccessorSymbolTemplatePath = templatesPath/"setaccessorsymbol" & templateExt
const stateUpdaterTemplatePath = templatesPath/"stateupdater" & templateExt
const loadStateTemplatePath = templatesPath/"loadstate" & templateExt
const saveStateTemplatePath = templatesPath/"savestate" & templateExt
const stateSourcePath = statePath & nimExt
const commandSourcePath = commandPath & nimExt
const commandLibraryPath = commandPath & libExt


type Initialize* = proc(oldStateLib: pointer) {.gcsafe, stdcall.}
type Run* = proc(state: pointer) {.gcsafe, stdcall.}


type VariableDeclaration* = object
  declarer*: string
  name*: string
  typ*: string


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
  variables: seq[VariableDeclaration]
  newVariables: seq[VariableDeclaration]
  states: seq[LibHandle]


proc cased(value: string): string =
  result = value
  result[0] = result[0].toUpperAscii()


proc declaration(self: VariableDeclaration): string =
  self.declarer & " " & self.name & "* : " & self.typ


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


proc generateStateSource*(self: ReploidVM, variables: seq[VariableDeclaration]): string =
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


proc generateCommandSource*(self: ReploidVM, command: string): string =
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


proc newReploidVM*(compiler: Compiler): ReploidVM =
  ReploidVM(
    compiler: compiler,
    stateTemplate: readFile(stateTemplatePath),
    commandTemplate: readFile(commandTemplatePath),
    accessorsTemplate: readFile(accessorsTemplatePath),
    getAccessorSymbolTemplate: readFile(getAccessorSymbolTemplatePath),
    setAccessorSymbolTemplate: readFile(setAccessorSymbolTemplatePath),
    stateUpdaterTemplate: readFile(stateUpdaterTemplatePath),
    loadStateTemplate: readFile(loadStateTemplatePath),
    saveStateTemplate: readFile(saveStateTemplatePath)
  )


proc declareVar*(self: var ReploidVM, declarer: string, name: string, typ: string) =
  let declaration = VariableDeclaration(declarer: declarer, name: name, typ: typ)
  self.newVariables.add(declaration)


proc rebuildState*(self: var ReploidVM): string =
  let newVariables = self.variables & self.newVariables
  let source = self.generateStateSource(newVariables)
  let stateLibraryPath = statePath & $self.states.len & libExt

  stateSourcePath.writeFile(source)
  discard self.compiler.compileLibrary(stateSourcePath, stateLibraryPath)

  let newState = loadLib(stateLibraryPath)
  let initialize = cast[Initialize](newState.symAddr("initialize"))

  if self.states.len > 0:
    initialize(self.states[^1])

  self.states.add(newState)
  self.variables = newVariables
  self.newVariables = @[]


# DONE: manage dynamic libraries
# DONE: cleanup on exit
# TODO: error handling
# TODO: declare let
# TODO: support type declarations
# TODO: parametrize tmp and template paths
proc runCommand*(self: var ReploidVM, command: string) =
  let source = self.generateCommandSource(command)

  commandSourcePath.writeFile(source)
  discard self.compiler.compileLibrary(commandSourcePath, commandLibraryPath)

  let commandLib = loadLib(commandLibraryPath)
  let run = cast[Run](commandLib.symAddr("run"))
  run(self.states[^1])
  unloadLib(commandLib)

proc clean*(self: var ReploidVM) =
  for state in self.states:
    unloadLib(state)

  self.states = @[]
  self.variables = @[]
  self.newVariables = @[]
