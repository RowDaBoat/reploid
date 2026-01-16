# ISC License
# Copyright (c) 2025 RowDaBoat

import os, vm, strutils, options
import nimscripter
import "$nim"/compiler / options as copts


type Initialize* = proc(oldStateLib: pointer) {.stdcall.}
type Run* = proc(state: pointer): (string, string) {.stdcall.}


type NimSVm* = ref object of Vm
  discard


proc newNimSVm*(tmpPath: string = getTempDir()): NimSVm =
  ## Creates a new Virtual Machine that uses nim script to run commands.
  ## **Strengths**: maximizes speed.
  ## **Weaknesses**: it does not allow integration with native code.
  result = NimSVm(
    tmpPath: tmpPath,
    importsBasePath: tmpPath / "imports",
    declarationsBasePath: tmpPath / "declarations",
    stateBasePath: tmpPath / "state",
    commandBasePath: tmpPath / "command"
  )


method updateImports*(self: NimSVm): (string, int) =
  let imports = self.imports & self.newImports
  let source = imports.join("\n")
  let checkSrcPath = self.importsBasePath & checkSuffix & nimExt

  checkSrcPath.writeFile(source)
  self.newImports = @[]

  type VMErrorMsg = ref object of CatchableError
    discard

  let errorHook = proc(config: ConfigRef; info: TLineInfo; msg: string; severity: Severity) {.gcsafe.} =
    if severity == Error and config.error_counter >= config.error_max:
      let fileName = config.m.fileInfos[info.fileIndex.int].fullPath.string
      let error = "$1($2, $3) Error: $4" % [fileName, $info.line, $(info.col + 1), msg]
      raise VMErrorMsg(msg: error)

  try:
    let intr = loadScript(NimScriptPath(checkSrcPath), vmErrorHook = errorHook)

    if intr.isNone:
      self.newImports = @[]
      return ("error", 1)
  except VMErrorMsg as e:
    self.newImports = @[]
    return (e.msg, 1)

  let srcPath = self.importsBasePath & nimExt
  srcPath.writeFile(source)
  self.imports.add(self.newImports)
  self.newImports = @[]
  return ("", 0)


method updateDeclarations*(self: NimSVm): (string, int) =
  raise newException(Exception, "Not imlpemented.")


method updateState*(self: NimSVm): (string, int) =
  raise newException(Exception, "Not imlpemented.")


method runCommand*(self: NimSVm, command: string): (string, int) =
  raise newException(Exception, "Not imlpemented.")


proc clean*(self: NimSVm) =
  ## TODO: Method?
  ## Cleans up the vm, unloading all state libraries.
  self.newImports = @[]
  self.imports = @[]
  self.newDeclarations = @[]
  self.declarations = @[]
  self.newVariables = @[]
  self.variables = @[]
