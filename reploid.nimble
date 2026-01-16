# Package

skipDirs      = @["tests"]
version       = "0.0.1"
author        = "RowDaBoat"
description   = "Reploid: A Nim REPL"
license       = "ISC"
installDirs   = @["src"]
installExt    = @["nim", "template"]
bin           = @["reploid"]

srcDir        = "src"

requires "https://github.com/RowDaBoat/cliquet.git#master"
requires "https://github.com/jangko/nim-noise.git#master"
requires "https://github.com/beef331/nimscripter.git#master"

task test, "Run the test suite":
  exec "nim r test/nimcvm.nim"
  exec "nim r test/nimsvm.nim"

task docs, "Generate documentation":
  when defined(windows):
    exec "rmdir /S /Q docs"
  else:
    exec "rm -rf docs"
  exec "nim doc --project --git.url:git@github.com:RowDaBoat/reploid.git --index:on --outdir:docs src/reploid.nim"
