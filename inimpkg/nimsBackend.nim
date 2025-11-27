import std/strutils
import std/os
import nimscripter

const errorPrefix = "Script Error: "

type NimsBackend* = object
  addins: VMAddins

proc nimsBackend*(): NimsBackend =
  #exportTo(module, help)
  let addins = implNimScriptModule(module)
  NimsBackend(addins: addins)

proc formatResult(exitCode: int, output: string): (string, int) =
  let hasFailed = exitCode != 0
  let isScriptError = hasFailed and output.startsWith(errorPrefix)

  result = if isScriptError:
    (output[errorPrefix.len..^1], exitCode)
  else:
    (output, exitCode)

proc runCode*(self: NimsBackend, source: string): (string, int) =
  let tempFile = getTempDir() / "nimrepl_capture.txt"
  let oldStdout = stdout
  let outFile = open(tempFile, fmWrite)
  stdout = outFile
  var exitCode = 0

  try:
    let interpreterOpt = loadScript(
      NimScriptPath(source),
      self.addins,
      searchPaths = @[ getCurrentDir() ]
    )
    if interpreterOpt.isNone:
      exitCode = 1
  except:
    exitCode = 1
  finally:
    stdout = oldStdout
    outFile.close()

  result = formatResult(exitCode, readFile(tempFile))
