import unittest, osproc, strutils

import inim

suite "Nimscript Backend Tests":

  setup:
    initApp("nim", "", true, nimsBackend = true)

  teardown:
    discard

  test "Verify flags with '--' prefix work":
    var o = execCmdEx("""echo 'echo "SUCCESS"' | bin/inim --useNims""").output.strip()
    echo "[", o, "]"
    check o == "SUCCESS"
