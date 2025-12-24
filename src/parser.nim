# ISC License
# Copyright (c) 2025 RowDaBoat

import strutils


type Parser* = object
  ok*: bool
  text*: string
  tokens*: seq[string]
  expected*: string


proc match(line: string, patterns: varargs[string]): (bool, string) =
  for pattern in patterns:
    if line.startsWith(pattern):
      return (true, line[pattern.len .. ^1])

  return (false, line)


proc startsAsLabel(text: string): bool =
  text.len > 0 and text[0].isAlphaNumeric or text[0] == '_'

proc parse*(text: string): Parser =
  Parser(ok: true, text: text, tokens: @[], expected: "")


proc matchKeywords*(self: Parser, texts: varargs[string]): Parser =
  if not self.ok:
    return self

  result = self

  for text in texts:
    let (matched, rest) = self.text.match(text)

    if matched and not rest.startsAsLabel:
      result.text = rest
      result.tokens.add(text)
      return

  result.ok = false
  result.expected = texts.join(", ")


proc consumeSpaces*(self: Parser): Parser =
  result = self
  result.text = result.text.strip(leading = true, trailing = false)


proc matchLabel*(self: Parser): Parser =
  if not self.ok:
    return self

  result = self
  var token = ""
  var next = result.text[0]

  while result.text.startsAsLabel:
    token &= next
    result.text = result.text[1..^1]
    next = result.text[0]

  if token.len == 0:
    result.ok = false
    result.expected = "a label"
  else:
    result.tokens.add(token)


proc matchUpTo*(self: Parser, texts: varargs[string]): Parser =
  if not self.ok:
    return self

  result = self
  var min = self.text.len
  var matchingText = ""

  for text in texts:
    let found = self.text.find(text)

    if found >= 0 and found < min:
      min = found
      matchingText = text

  let token = self.text[0 ..< min]
  let rest = self.text[min..^1]

  if token.len == 0:
    result.ok = false
    result.expected = "unexpected " & matchingText
  else:
    result.text = rest
    result.tokens.add(token)
    return

