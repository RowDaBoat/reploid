# ISC License
# Copyright (c) 2025 RowDaBoat

type EvaluationKind* = enum Empty, Success, Error Quit

type Evaluation* = object
  kind*: EvaluationKind
  result*: string
