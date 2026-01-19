# ISC License
# Copyright (c) 2025 RowDaBoat

import strutils, tables
import input, evaluation, parser, commands
import ../vm/vm


type Evaluator* = object
  commandsApi: CommandsApi
  commands: Table[string, Command]
  vm: Vm


proc isEmpty(lines: string): bool =
  lines.strip().len == 0


proc getCommand(self: Evaluator, lines: string): (bool, Command, seq[string]) =
  let split = lines.splitWhitespace()
  let command = split[0]
  let args = split[1..^1]

  return if command in self.commands:
    (true, self.commands[command], args)
  else:
    (false, Command(), @[])


proc isImport(lines: string): Parser =
  lines.parse()
    .matchKeywords("import")
    .consumeSpaces()


proc isVariableDeclaration(lines: string): Parser =
  lines.parse()
    .matchKeywords("var", "let", "const")
    .consumeSpaces()
    .matchLabel()


proc isDeclaration(lines: string): Parser =
  lines.parse()
    .matchKeywords("type", "proc", "template", "macro", "func", "method", "iterator", "converter")
    .consumeSpaces()


proc toDeclarerKind(text: string): DeclarerKind =
  case text:
  of "const": return DeclarerKind.Const
  of "let": return DeclarerKind.Let
  of "var": return DeclarerKind.Var


proc processCommand(self: var Evaluator, lines: string, evaluation: var Evaluation): bool =
  let (isCommand, command, args) = self.getCommand(lines)

  if not isCommand:
    return false

  evaluation = command.run(self.commandsApi, args)
  return true


proc processImport(self: var Evaluator, lines: string, evaluation: var Evaluation): bool =
  let importResult = lines.isImport()

  if not importResult.ok:
    return false

  self.vm.declareImport(importResult.text)

  let updateImportsResult = self.vm.updateImports()

  evaluation = Evaluation(
    kind: if updateImportsResult.isSuccess: Success else: Error,
    result: updateImportsResult[0]
  )
  return true


proc getTypeAndInitializer(parser: Parser): (string, string) =
  var typeParser = parser
    .consumeSpaces()
    .matchSymbols(":", "=")

  if not typeParser.ok:
    return ("", "")

  if typeParser.tokens[^1] == "=":
    return ("", typeParser.text.strip())

  typeParser = typeParser
    .matchUpTo("=")

  if not typeParser.ok:
    return (typeParser.text.strip(), "")

  let typ = typeParser.tokens[^1].strip()
  let init = typeParser.text[1..^1].strip()
  return (typ, init)


proc processVariableDeclaration(self: var Evaluator, lines: string, evaluation: var Evaluation): bool =
  var varDeclResult = lines.isVariableDeclaration()

  if not varDeclResult.ok:
    return false

  let declarer = varDeclResult.tokens[0].toDeclarerKind()
  let label = varDeclResult.tokens[1]
  let (typ, initializer) = varDeclResult.getTypeAndInitializer()

  if typ.len == 0 and initializer.len == 0:
    evaluation = Evaluation(kind: Error, result: "A type and/or an initializer are required to declare a variable.")
    return true

  self.vm.declareVar(declarer, label, typ, initializer)

  let updateStateResult = self.vm.updateState()

  evaluation = Evaluation(
    kind: if updateStateResult.isSuccess: Success else: Error,
    result: updateStateResult[0]
  )
  return true


proc processOtherDeclaration(self: var Evaluator, lines: string, evaluation: var Evaluation): bool =
  let declResult = lines.isDeclaration()
  if not declResult.ok:
    return false

  self.vm.declare(lines)
  let updateDeclarationsResult = self.vm.updateDeclarations()

  evaluation = Evaluation(
    kind: if updateDeclarationsResult.isSuccess: Success else: Error,
    result: updateDeclarationsResult[0]
  )
  return true


proc processRunCommand(self: var Evaluator, lines: string): Evaluation =
  let runResult = self.vm.runCommand(lines)

  return Evaluation(
    kind: if runResult.isSuccess: Success else: Error,
    result: runResult[0]
  )


proc evaluateLines(self: var Evaluator, lines: string): Evaluation =
  if lines.isEmpty():
    return Evaluation(kind: Empty)

  var evaluation = Evaluation(kind: Empty)

  if self.processCommand(lines, evaluation):
    return evaluation
  elif self.processImport(lines, evaluation):
    return evaluation
  elif self.processVariableDeclaration(lines, evaluation):
    return evaluation
  elif self.processOtherDeclaration(lines, evaluation):
    return evaluation
  else:
    return self.processRunCommand(lines)


proc newEvaluator*(
  commandsApi: CommandsApi,
  commands: Table[string, Command],
  vm: Vm
): Evaluator =
  ## Creates a new Evaluator object with the given commands and VM.
  ## 
  ## **Commands:**
  ## `commands` is a table associating built-in command names with their implementations.
  ## The `commandsApi` object contains the output, compiler and vm exposed to each command.
  ## 
  ## **Vm:**
  ## `vm` is the Vm object that contains the state, declarations, imports, and runs nim code.
  Evaluator(commandsApi: commandsApi, vm: vm, commands: commands)


proc eval*(self: var Evaluator, input: Input): Evaluation =
  ## Evaluates the given input, returning an Evaluation object.
  ## 
  ## **`Lines`:**
  ## If the input kind is `Lines`, the lines are evaluated as declarations, nim code, or built-in commands from the commands table.
  ## Evaluating to what the declaration, nim code, or built-in command evaluate to.
  ## 
  ## **`Reset`:** a reset input will clear the current line and start a new one. It evaluates to an `Empty` evaluation.
  ## **`Quit` and `EOF`:** both will be evaluated to a `Quit` evaluation, exiting the REPL.
  case input.kind:
  of Lines: self.evaluateLines(input.lines)
  of Reset: Evaluation(kind: Empty)
  of Quit: Evaluation(kind: Quit)
  of EOF: Evaluation(kind: Quit)
