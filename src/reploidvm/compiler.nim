# ISC License
# Copyright (c) 2025 RowDaBoat

import sequtils
import strutils
import strformat
import osproc


type Compiler* = object
  nim: string
  flags: string


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
  ].join(" ")


proc newNimCompiler*(nim: string, flags: seq[string]): Compiler =
  let jointFlags = flags.mapIt("-d:" & it).join(" ")
  Compiler(nim: nim, flags: jointFlags)


proc version*(self: Compiler): (string, int) =
  execCmdEx(fmt"{self.nim} --version")


proc path*(self: Compiler): (string, int) =
  let whichCmd = when defined(Windows):
      fmt"where {self.nim}"
    else:
      fmt"which {self.nim}"

  return execCmdEx(whichCmd)


proc compileLibrary*(self: Compiler, source: string, output: string): (string, int) =
  let compileLibraryWithFlags = " " & compileLibraryCommand & " " & self.flags
  let sourceAndOutput = " -o:" & output & " " & source
  let command = self.nim & compileLibraryWithFlags & sourceAndOutput
  result = execCmdEx(command)
