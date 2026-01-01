# ISC License
# Copyright (c) 2025 RowDaBoat

import strutils
import sequtils

proc extractIndentation(text: string, position: int): string =
  var lineStart = position
  result = ""

  while lineStart > 0 and text[lineStart - 1] != '\n':
    lineStart -= 1
  
  var whitespaces = lineStart

  while whitespaces < position and text[whitespaces] in {' ', '\t'}:
    whitespaces += 1

  result = text[lineStart ..< whitespaces]


proc applyIndentation(indentation: string, lines: seq[string], endsInNewline: bool): string =
  let trailingNewline = if endsInNewline: "\n" else: ""

  let firstLine = lines[0]
  let indentedLines = lines[1..^1].mapIt("\n" & indentation & it)
  return firstLine & indentedLines.join("") & trailingNewline


proc replaceWithIndentation(text: string, tag: string, value: string): string =
  result = ""
  var i = 0
  let lines = value.splitLines()
  let endsInNewline = value.endsWith("\n")
  let bracedTag = "{" & tag & "}"

  while i < text.len:
    let foundIndex = text.find(bracedTag, i)
    if foundIndex == -1:
      result &= text[i..^1]
      break

    result &= text[i..<foundIndex]
    
    let indentation = extractIndentation(text, foundIndex)
    result &= applyIndentation(indentation, lines, endsInNewline)
    i = foundIndex + bracedTag.len


proc replace*(tmpl: string, replacements: varargs[(string, string)]): string =
  result = tmpl

  for (tag, value) in replacements:
    result = result.replaceWithIndentation(tag, value)
