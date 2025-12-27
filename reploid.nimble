# Package

skipDirs      = @["tests"]
version       = "0.0.1"
author        = "RowDaBoat"
description   = "Reploid: A Nim REPL"
license       = "ISC"
installDirs   = @["src"]
installExt    = @["reploid"]
bin           = @["reploid"]

srcDir        = "src"

requires "https://github.com/RowDaBoat/cliquet.git#master"
requires "https://github.com/jangko/nim-noise.git#master"
