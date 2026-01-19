import std/paths


const nimExt* = ".nim"
const checkSuffix* = "check"


type DeclarerKind* = enum Const, Let, Var


type VariableDeclaration* = object
  declarer*: DeclarerKind
  name*: string
  typ*: string
  initializer*: string


type Vm* = ref object of RootObj
  tmpPath*: string
  importsBasePath*: string
  declarationsBasePath*: string
  commandBasePath*: string
  stateBasePath*: string

  imports*: seq[string]
  newImports*: seq[string]
  variables*: seq[VariableDeclaration]
  newVariables*: seq[VariableDeclaration]
  declarations*: seq[string]
  newDeclarations*: seq[string]


proc `$`*(self: DeclarerKind): string =
  case self:
  of DeclarerKind.Const: "const"
  of DeclarerKind.Let: "let"
  of DeclarerKind.Var: "var"


proc isSuccess*(toCheck: (string, int)): bool =
  ## Checks if the given result is successful.
  toCheck[1] == 0


proc importsPath*(self: Vm): Path =
  ## Temporary path where the vm stores its imports.
  Path(self.importsBasePath & nimExt)


proc importsCheckPath*(self: Vm): Path =
  ## Temporary path where the vm writes the last imports that were validated.
  Path(self.importsBasePath & checkSuffix & nimExt)


proc declarationsPath*(self: Vm): Path =
  ## Temporary path where the vm stores its declarations.
  Path(self.declarationsBasePath & nimExt)


proc declarationsCheckPath*(self: Vm): Path =
  ## Temporary path where the vm writes the last declarations that were validated.
  Path(self.declarationsBasePath & checkSuffix & nimExt)


proc commandPath*(self: Vm): Path =
  ## Temporary path where the vm stored the last command.
  Path(self.commandBasePath & nimExt)


proc statePath*(self: Vm): Path =
  ## Temporary path where the vm stored the last state.
  Path(self.stateBasePath & nimExt)


proc declareImport*(self: Vm, declaration: string) =
  ## Declares a new import.
  ## This will not be effective until `updateImports` is called.
  self.newImports.add("import " & declaration)


proc declareVar*(self: Vm, declarer: DeclarerKind, name: string, typ: string = "", initializer: string = "") =
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


proc declare*(self: Vm, declaration: string) =
  ## Declares a new `proc`, `template`, `macro`, `iterator`, etc. and/or `type`.
  ## This will not be effective until `updateDeclarations` is called.
  self.newDeclarations.add(declaration)


method updateImports*(self: Vm): (string, int) {.base.} =
  ## Updates the imports.
  ## Compiles all declared imports and returns a success or an error.
  quit "UpdateImports not implemented on " & $self.type & ", this is a bug."


method updateState*(self: Vm): (string, int) {.base.} =
  ## Updates the state's structure, initializes the new variables while keeping the values of the previous state.
  ## Compiles all variable declarations, and returns a success or an error.
  quit "UpdateState not implemented on " & $self.type & ", this is a bug."


method updateDeclarations*(self: Vm): (string, int) {.base.} =
  ## Updates the declarations.
  ## Compiles all declarations and returns a success or an error.
  quit "UpdateDeclarations not implemented on " & $self.type & ", this is a bug."

method runCommand*(self: Vm, command: string): (string, int) {.base.} =
  ## Runs a command.
  ## Compiles the command, runs it, and returns a success or an error.
  quit "RunCommand not implemented on " & $self.type & ", this is a bug."


method clean*(self: Vm) {.base.} =
  ## Cleans up the vm state.
  self.newImports = @[]
  self.imports = @[]
  self.newDeclarations = @[]
  self.declarations = @[]
  self.newVariables = @[]
  self.variables = @[]
