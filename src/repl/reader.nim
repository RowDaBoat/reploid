# ISC License
# Copyright (c) 2025 RowDaBoat

import noise
import strutils
import input
import styledoutput


type Reader* = object
  noise: Noise
  output: Output
  promptMessage: string
  promptSymbol: string
  indentation: string
  historyFile: string


const IndentTriggers = [
      ",", "=", ":",
      "var", "let", "const", "type", "import",
      "object", "RootObj", "enum"
  ]


proc setMainPrompt(self: var Reader) =
  let prompt = self.output.styledPrompt(self.promptMessage, self.promptSymbol & " ")
  self.noise.setPrompt(prompt)


proc setMultilinePrompt(self: var Reader) =
  let promptMessage = ".".repeat(self.promptMessage.len + self.promptSymbol.len - 1)
  let prompt = self.output.styledPrompt(promptMessage, ". ")
  self.noise.setPrompt(prompt)


proc setIndentation(self: var Reader, indentationLevels: int) =
  let indentation = self.indentation.repeat(indentationLevels)
  self.noise.preloadBuffer(indentation, collapseWhitespaces = false)

proc indent(line: string): bool =
  if line.len == 0:
    return

  for trigger in IndentTriggers:
    if line.strip().endsWith(trigger):
      result = true


proc unindent(indentation: int, line: string): bool =
  indentation > 0 and line.strip.len == 0


proc loadHistory(self: var Reader) =
  if self.historyFile != "":
    discard self.noise.historyLoad(self.historyFile)


proc saveHistory(self: var Reader) =
  if self.historyFile != "":
    discard self.noise.historySave(self.historyFile)


proc addHistory(self: var Reader, line: string) =
  self.noise.historyAdd(line)


proc readSingleLine(self: var Reader): Input =
  var ok = false

  try:
    ok = self.noise.readLine()
  except EOFError:
    return Input(kind: EOF)

  if not ok:
    case self.noise.getKeyType():
    of ktCtrlC:
      return Input(kind: Reset)
    of ktCtrlD:
      return Input(kind: Quit)
    of ktCtrlX:
      return Input(kind: Editor)
    else:
      return Input(kind: Lines, lines: "")

  let line = self.noise.getLine()
  self.addHistory(line)
  return Input(kind: Lines, lines: line)


proc newReader*(
  output: Output,
  promptMessage: string = "reploid",
  promptSymbol: string = ">",
  indentation: string = "  ",
  historyFile: string = ""
): Reader =
  var noise = Noise.init()

  result = Reader(
    noise: noise,
    output: output,
    promptMessage: promptMessage,
    promptSymbol: promptSymbol,
    indentation: indentation,
    historyFile: historyFile
  )
  result.loadHistory()


proc read*(self: var Reader): Input =
  var complete = false
  var indentation = 0
  var lines: seq[string] = @[]

  self.setMainPrompt()

  while not complete:
    var singleLineResult = readSingleLine(self)

    if singleLineResult.kind != Lines:
      return singleLineResult

    let line = singleLineResult.lines

    if indent(line):
      indentation += 1

    if unindent(indentation, line):
      indentation -= 1

    if line.strip.len > 0:
      lines.add(line)

    self.setMultilinePrompt()
    self.setIndentation(indentation)
    complete = indentation == 0

  result = Input(kind: Lines, lines: lines.join("\n"))


proc cleanup*(self: var Reader) =
  self.saveHistory()
