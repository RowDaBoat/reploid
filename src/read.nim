import noise
import strutils

type Reader* = object
  noise: Noise
  prompt: string
  indentation: string


type ReadResultKind* = enum Lines, Reset, Quit, Editor, EOF


type ReadResult* = object
    case kind*: ReadResultKind
    of Lines:
      lines*: string
    of Reset:
      discard
    of Quit:
      discard
    of Editor:
      discard
    of EOF:
      discard


const IndentTriggers* = [
      ",", "=", ":",
      "var", "let", "const", "type", "import",
      "object", "RootObj", "enum"
  ]


proc setMainPrompt*(self: var Reader) =
  self.noise.setPrompt(Styler.init(self.prompt))


proc setMultilinePrompt*(self: var Reader) =
  let prompt = ".".repeat(self.prompt.len - 1) & " "
  self.noise.setPrompt(Styler.init(prompt))


proc setIndentation*(self: var Reader, indentationLevels: int) =
  let indentation = self.indentation.repeat(indentationLevels)
  self.noise.preloadBuffer(indentation, collapseWhitespaces = false)

proc indent*(line: string): bool =
  if line.len == 0:
    return

  for trigger in IndentTriggers:
    if line.strip().endsWith(trigger):
      result = true


proc unindent*(indentation: int, line: string): bool =
  indentation > 0 and line.strip.len == 0


proc newReader*(prompt: string = "reploid> ", indentation: string = "  "): Reader =
  Reader(
    noise: Noise.init(),
    prompt: prompt,
    indentation: indentation
  )


proc readSingleLine(self: var Reader): ReadResult =
  var ok = false

  try:
    ok = self.noise.readLine()
  except EOFError:
    return ReadResult(kind: EOF)

  if not ok:
    case self.noise.getKeyType():
    of ktCtrlC:
      return ReadResult(kind: Reset)
    of ktCtrlD:
      return ReadResult(kind: Quit)
    of ktCtrlX:
      return ReadResult(kind: Editor)
    else:
      return ReadResult(kind: Lines, lines: "")

  return ReadResult(kind: Lines, lines: self.noise.getLine())

proc read*(self: var Reader): ReadResult =
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

  result = ReadResult(kind: Lines, lines: lines.join("\n"))


if isMainModule:
  var reader = newReader("reploid> ")

  while true:
    let result = reader.read()
    case result.kind:
    of Lines:
      if result.lines != "":
        echo result.lines
    of Reset:
      discard
    of Quit:
      break
    of Editor:
      discard
    of EOF:
      break
