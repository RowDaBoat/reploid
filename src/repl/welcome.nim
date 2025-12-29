# ISC License
# Copyright (c) 2025 RowDaBoat

import osproc, strformat, strutils
import styledoutput


const NimblePkgVersion* {.strdefine.} = ""


type Welcome* = object
  nim: string
  color: bool


proc reploidNameAndVersion(output: Output) =
  let prefix = when not defined(Windows): "👑 " else: ""
  let version = if NimblePkgVersion.len > 0: " v" & NimblePkgVersion else: ""
  output.nim(prefix & "Reploid" & version & "\n")


proc nimVersion(output: Output, nim: string) =
  let (nimVersion, status) = execCmdEx(fmt"{nim} --version")
  if status == 0:
    output.okResult(nimVersion.splitLines()[0] & "\n")
  else:
    output.error(fmt"'{nim}' compiler not found." & "\n")


proc path(output: Output, nim: string) =
  let whichCmd = when defined(Windows):
      fmt"where {nim}"
    else:
      fmt"which {nim}"

  let (path, status) = execCmdEx(whichCmd)
  if status == 0:
    output.okResult("at " & path.strip() & "\n")
  else:
    output.error("\n")


proc welcome*(output: Output, nim: string) =
  output.nim("┬─┐┌─┐┌─┐┬  ┌─┐┬┌┬┐ "); output.reploidNameAndVersion()
  output.nim("├┬┘├┤ ├─┘│  │ ││ ││ "); output.nimVersion(nim)
  output.nim("┴└─└─┘┴  ┴─┘└─┘┴─┴┘ "); output.path(nim)
