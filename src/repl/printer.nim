# ISC License
# Copyright (c) 2025 RowDaBoat

import std/[paths, strutils, sequtils, tables]
import styledoutput, evaluation, parser
import ../vm/vm


type OutputDisplay* = enum clean, full


type Printer* = object
  output: Output
  tempPath:string
  sourceFileNames: seq[string]
  sourceFileReplacements: Table[string, string]
  muted: seq[string]
  outputDisplay: OutputDisplay


type Style = enum None = 0, Hint = 1, Warning = 2, Error = 3, Muted = 4


proc isMuted(self: Printer, line: string): bool =
  for muted in self.muted:
    if muted in line:
      return true


proc matchCompilerOutput(text: string, sources: seq[string]): Parser =
  parse(text)
    .matchUpTo(sources)
    .matchText(sources)
    .matchSymbols("(")
    .matchInteger()
    .matchSymbols(",")
    .consumeSpaces()
    .matchInteger()
    .matchSymbols(")")
    .consumeSpaces()
    .matchKeywords("Hint", "Warning", "Error")


proc styleIfCompilerOutput(self: Printer, line: string, path: string): (string, Style) =
  let pathStartIndex = line.find(path)

  if pathStartIndex == -1:
    return (line, None)

  var prev = line[0 ..< pathStartIndex]

  if prev.endsWith("/private"):
    prev = prev[0..<prev.len - "/private".len]

  let post = line[pathStartIndex + path.len..^1]
  let matchCompilerOut = matchCompilerOutput(post, self.sourceFileNames)

  if not matchCompilerOut.ok:
    echo "matchCompilerOut: ", matchCompilerOut.expected
    return (line, None)

  var replacement = self.sourceFileReplacements[matchCompilerOut.tokens[1]]

  let outType = matchCompilerOut.tokens[^1]
  let style = case outType:
    of "Hint": Hint
    of "Warning": Warning
    of "Error": Error
    else: None

  let replacedLine = prev & replacement & " " & matchCompilerOut.tokens[^1] & matchCompilerOut.text
  result = (replacedLine, style)


proc processLine(self: Printer, line: string): (string, Style) =
  var line = line
  var style = None

  if self.isMuted(line):
    return ("", Muted)

  let path = self.tempPath
  var replacementStyle: Style = None
  (line, replacementStyle) = self.styleIfCompilerOutput(line, path)
  style = max(style, replacementStyle)
  result = (line, style)


proc printOk(self: Printer, lines: string) =
  if lines.len == 0:
    return

  if self.outputDisplay == OutputDisplay.full:
    self.output.okResult(lines & "\n")
    return

  for line in lines.split("\n"):
    var (line, style) = self.processLine(line)

    case style:
    of None:    self.output.okResult(line & "\n")
    of Hint:    self.output.info(line & "\n")
    of Warning: self.output.warning(line & "\n")
    of Error:   self.output.error(line & "\n")
    of Muted:   discard


proc printError(self: Printer, lines: string) =
  if lines.len == 0:
    return

  if self.outputDisplay == OutputDisplay.full:
    self.output.error(lines & "\n")
    return

  for line in lines.split("\n"):
    var (line, style) = self.processLine(line)

    case style:
    of None:    self.output.error(line & "\n")
    of Hint:    self.output.info(line & "\n")
    of Warning: self.output.warning(line & "\n")
    of Error:   self.output.error(line & "\n")
    of Muted:   discard


proc file(path: Path): string =
  path.extractFilename.string

proc newPrinter*(output: Output, vm: Vm, outputDisplay: OutputDisplay): Printer =
  ## Creates a new Printer object with the given output and vm.
  ## The vm is used to filter its temporary paths from the output.
  let sourceHintReplacements = @[
      (vm.importsPath.file, "[Imports]"),
      (vm.importsCheckPath.file, "[Imports]"),
      (vm.declarationsPath.file, "[Declarations]"),
      (vm.declarationsCheckPath.file, "[Declarations]"),
      (vm.statePath.file, "[State]"),
      (vm.commandPath.file, "[Command]"),
    ]
  let sourceFileNames = sourceHintReplacements.mapIt(it[0])

  return Printer(
    output: output,
    outputDisplay: outputDisplay,
    muted: @[
      "template/generic instantiation of `showIfTyped` from here",
      "Warning: imported and not used:"
    ],
    tempPath: vm.tmpPath,
    sourceFileNames: sourceFileNames,
    sourceFileReplacements: sourceHintReplacements.toTable
  )


proc print*(self: Printer, evaluation: Evaluation) =
  ## Prints the given evaluation to the output.
  ## 
  ## **`Success`:** prints the result with the ok result color scheme.
  ## **`Error`:** prints the result with the error color scheme.
  ## **`Quit`, `Empty`:** do nothing.
  ##
  ## Replaces paths on hints, warnings and errors that correspond to the vm's temporary paths with contextual information.
  ## It also mutes some error and warning messages from the compiler that are not relevant to the user.
  case evaluation.kind:
  of Success: self.printOk(evaluation.result)
  of Error:   self.printError(evaluation.result)
  of Quit:    discard
  of Empty:   discard
