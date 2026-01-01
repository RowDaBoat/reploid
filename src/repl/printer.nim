# ISC License
# Copyright (c) 2025 RowDaBoat

import styledoutput
import evaluation
import strutils
import parser
import ../vm/vm


type Printer* = object
  output: Output
  pathHintReplacements: seq[(string, string)]
  muted: seq[string]


type Style = enum None = 0, Hint = 1, Warning = 2, Error = 3, Muted = 4


proc isMuted(self: Printer, line: string): bool =
  for muted in self.muted:
    if muted in line:
      return true


proc matchCompilerOutput(text: string): Parser =
  parse(text)
    .matchSymbols("(")
    .matchInteger()
    .matchSymbols(",")
    .consumeSpaces()
    .matchInteger()
    .matchSymbols(")")
    .consumeSpaces()
    .matchKeywords("Hint", "Warning", "Error")


proc replaceVmPaths(self: Printer, line: string, path: string, replacement: string): (string, string, string, Style) =
  let pathStartIndex = line.find(path)

  if pathStartIndex == -1:
    return ("", "", line, None)

  var prev = line[0..<pathStartIndex]

  if prev.endsWith("/private"):
    prev = prev[0..<prev.len - "/private".len]

  let post = line[pathStartIndex + path.len..^1]
  let matchCompilerOut = matchCompilerOutput(post)

  if not matchCompilerOut.ok:
    return ("", "", line, None)

  let outType = matchCompilerOut.tokens[^1]
  let style = case outType:
    of "Hint": Hint
    of "Warning": Warning
    of "Error": Error
    else: None

  result = (
    prev,
    replacement & " " & matchCompilerOut.tokens[^1],
    matchCompilerOut.text,
    style
  )


proc processLine(self: Printer, line: string): (string, Style) =
  var line = line
  var style = None

  if self.isMuted(line):
    return ("", Muted)

  for (path, replacement) in self.pathHintReplacements:
    var (prev, replacement, post, replacementStyle) = self.replaceVmPaths(line, path, replacement)
    style = max(style, replacementStyle)
    line = prev & replacement & post

  result = (line, style)


proc printOk(self: Printer, lines: string) =
  if lines.len == 0:
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

  for line in lines.split("\n"):
    var (line, style) = self.processLine(line)

    case style:
    of None:    self.output.error(line & "\n")
    of Hint:    self.output.info(line & "\n")
    of Warning: self.output.warning(line & "\n")
    of Error:   self.output.error(line & "\n")
    of Muted:   discard


proc newPrinter*(output: Output, vm: Vm): Printer =
  ## Creates a new Printer object with the given output and vm.
  ## The vm is used to filter its temporary paths from the output.
  Printer(
    output: output,
    muted: @[
      "template/generic instantiation of `showIfTyped` from here",
      "Warning: imported and not used:"
    ],
    pathHintReplacements: @[
      (vm.importsPath, "[Imports]"),
      (vm.importsCheckPath, "[Imports]"),
      (vm.declarationsPath, "[Declarations]"),
      (vm.declarationsCheckPath, "[Declarations]"),
      (vm.statePath, "[State]"),
      (vm.commandPath, "[Command]"),
    ]
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
