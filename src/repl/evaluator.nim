# ISC License
# Copyright (c) 2025 RowDaBoat

import strutils
import tables

import input
import evaluation
import parser
import ../reploidvm/vm
import ../commands/commands


type Evaluator* = object
  commandsApi: CommandsApi
  commands: Table[string, Command]
  vm: ReploidVM


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
    .consumeSpaces()
    .matchKeywords(":")
    .consumeSpaces()
    .matchUpTo("=")


proc isDeclaration(lines: string): Parser =
  lines.parse()
    .matchKeywords("type", "proc", "template", "macro", "func", "method", "iterator", "converter")
    .consumeSpaces()


proc evaluateLines(self: var Evaluator, lines: string): Evaluation =
  if lines.isEmpty():
    return Evaluation(kind: Empty)

  let (isCommand, command, args) = self.getCommand(lines)
  if isCommand:
    return command.run(self.commandsApi, args)

  let importResult = lines.isImport()
  if importResult.ok:
    self.vm.declareImport(lines)
    let updateImportsResult = self.vm.updateImports()

    return Evaluation(
      kind: if updateImportsResult.isSuccess: Success else: Error,
      result: updateImportsResult[0]
    )

  let varDeclResult = lines.isVariableDeclaration()
  if varDeclResult.ok:
    let declarer = varDeclResult.tokens[0]
    let label = varDeclResult.tokens[1]
    let typ = varDeclResult.tokens[3].strip()
    let rest = varDeclResult.text

    self.vm.declareVar(declarer, label, typ, rest)
    let updateStateResult = self.vm.updateState()

    return Evaluation(
      kind: if updateStateResult.isSuccess: Success else: Error,
      result: updateStateResult[0]
    )

  let declResult = lines.isDeclaration()
  if declResult.ok:
    self.vm.declare(lines)
    let updateDeclarationsResult = self.vm.updateDeclarations()

    return Evaluation(
      kind: if updateDeclarationsResult.isSuccess: Success else: Error,
      result: updateDeclarationsResult[0]
    )

  let runResult = self.vm.runCommand(lines)

  return Evaluation(
    kind: if runResult.isSuccess: Success else: Error,
    result: runResult[0]
  )


proc newEvaluator*(
  commandsApi: CommandsApi,
  commands: Table[string, Command],
  vm: ReploidVM
): Evaluator = Evaluator(commandsApi: commandsApi, vm: vm, commands: commands)


proc eval*(self: var Evaluator, input: Input): Evaluation =
  case input.kind:
  of Lines: self.evaluateLines(input.lines)
  of Reset: Evaluation(kind: Empty)
  of Editor: Evaluation(kind: Empty)
  of Quit: Evaluation(kind: Quit)
  of EOF: Evaluation(kind: Quit)
