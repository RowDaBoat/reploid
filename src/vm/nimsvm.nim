# ISC License
# Copyright (c) 2025 RowDaBoat

import os
import vm


type Initialize* = proc(oldStateLib: pointer) {.stdcall.}
type Run* = proc(state: pointer): (string, string) {.stdcall.}


type NimSVm* = ref object of Vm
  discard

proc newNimSVm*(tmpPath: string = getTempDir()): NimSVm =
  ## Creates a new Virtual Machine that uses nim script to run commands.
  ## **Strengths**: maximizes speed.
  ## **Weaknesses**: it does not allow integration with native code.
  result = NimSVm()


method updateImports*(self: NimSVm): (string, int) =
  raise newException(Exception, "Not imlpemented.")


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
