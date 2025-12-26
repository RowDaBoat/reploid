# ISC License
# Copyright (c) 2025 RowDaBoat

type InputKind* = enum Lines, Reset, Quit, Editor, EOF


type Input* = object
    case kind*: InputKind
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
