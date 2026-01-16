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


proc startsAsLabelOrNumber(text: string): bool =
  text.len > 0 and (text[0].isAlphaNumeric or text[0] == '_')


proc startsAsSymbol(text: string): bool =
  let notAlphaNumeric = not text[0].isAlphaNumeric
  let notUnderscore = text[0] != '_'
  let notWhitespace = not text[0].isSpaceAscii
  text.len > 0 and notAlphaNumeric and notUnderscore and notWhitespace


proc parse*(text: string): Parser =
  Parser(ok: true, text: text, tokens: @[], expected: "")


proc matchText*(self: Parser, texts: varargs[string]): Parser =
  if not self.ok:
    return self

  result = self

  for text in texts:
    let (matched, rest) = self.text.match(text)

    if matched:
      result.text = rest
      result.tokens.add(text)
      return

  result.ok = false
  result.expected = "expected: " & texts.join(", ") & ", got '" & self.text & "'"


proc matchKeywords*(self: Parser, texts: varargs[string]): Parser =
  if not self.ok:
    return self

  result = self

  for text in texts:
    let (matched, rest) = self.text.match(text)

    if matched and not rest.startsAsLabelOrNumber:
      result.text = rest
      result.tokens.add(text)
      return

  result.ok = false
  result.expected = "expected: " & texts.join(", ") & ", got '" & self.text & "'"


proc matchSymbols*(self: Parser, texts: varargs[string]): Parser =
  if not self.ok:
    return self

  result = self

  for text in texts:
    let (matched, rest) = self.text.match(text)

    if matched and not rest.startsAsSymbol:
      result.text = rest
      result.tokens.add(text)
      return

  result.ok = false
  result.expected = "expected: " & texts.join(", ") & ", got '" & self.text & "'"


proc matchInteger*(self: Parser): Parser =
  if not self.ok:
    return self

  result = self
  result.ok = false
  var current = 0

  while self.text[current].isDigit:
    current += 1
    result.ok = true

  result.tokens.add(self.text[0 ..< current])
  result.text = self.text[current..^1]

  if not result.ok:
    result.expected = "expected: an integer number, got '" & self.text & "'"


proc consumeSpaces*(self: Parser): Parser =
  result = self
  result.text = result.text.strip(leading = true, trailing = false)


proc matchLabel*(self: Parser): Parser =
  if not self.ok:
    return self

  result = self
  var token = ""

  while result.text.len > 0 and result.text.startsAsLabelOrNumber:
    token &= result.text[0]
    result.text = result.text[1..^1]

  if token.len == 0:
    result.ok = false
    result.expected = "expected: a label, got '" & self.text & "'"
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

  if min == self.text.len:
    result.ok = false
    result.expected = "expected: " & texts.join(", ") & ", got '" & self.text & "'"
  else:
    result.text = rest
    result.tokens.add(token)
    return

