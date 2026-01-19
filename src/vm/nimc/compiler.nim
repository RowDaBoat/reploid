# ISC License
# Copyright (c) 2025 RowDaBoat

import sequtils, strutils, strformat, osproc


type Compiler* = object
  nim: string
  flags: string


const compileLibraryCommand = [
    "c",
    "--app:lib",
    "--noMain",
    "--verbosity=0",
    "--path=./",
    "--passL:-w",
    "--define:release",
    "--opt:none"
  ].join(" ")


proc newNimCompiler*(nim: string, flags: seq[string]): Compiler =
  ## Creates a new Nim compiler with the given compiler binary and flags.
  let jointFlags = flags.mapIt("-d:" & it).join(" ")
  Compiler(nim: nim, flags: jointFlags)


proc version*(self: Compiler): (string, int) =
  ## Gets the version of the Nim compiler.
  execCmdEx(fmt"{self.nim} --version")


proc path*(self: Compiler): (string, int) =
  ## Get the path where the Nim compiler is located.
  let whichCmd = when defined(Windows):
      fmt"where {self.nim}"
    else:
      fmt"which {self.nim}"

  return execCmdEx(whichCmd)


proc compileLibrary*(self: Compiler, source: string, output: string): (string, int) =
  ## Compile a library with the configured flags, from the given source code to the given output path.
  let compileLibraryWithFlags = " " & compileLibraryCommand & " " & self.flags
  let sourceAndOutput = " -o:" & output & " " & source
  let command = self.nim & compileLibraryWithFlags & sourceAndOutput
  result = execCmdEx(command)
