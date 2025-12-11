# ISC License
# Copyright (c) 2025 RowDaBoat

import strutils
import osproc

type Compiler* = object
  nim: string

const compileLibraryCommand = [
    "c",
    "--app:lib",
    "--noMain",
    "--verbosity=0",
    "--hints=off",
    "--path=./",
    "--passL:-w",
    "--define:release",
    "--opt:none"
]

proc newNimCompiler*(nim: string): Compiler =
  Compiler(nim: nim)


proc compileLibrary*(self: Compiler, source: string, output: string): (string, int) =
  let libraryFlags = " " & compileLibraryCommand.join(" ")
  let sourceAndOutput = " -o:" & output & " " & source
  let command = self.nim & libraryFlags & sourceAndOutput
  result = execCmdEx(command)
