# ISC License
# Copyright (c) 2025 RowDaBoat

import terminal
import options
import noise/styler


type
  ColorScheme* = object
    fg*: Option[(ForegroundColor, bool)]
    bg*: Option[(BackgroundColor, bool)]


type Output* = object
  nim*: ColorScheme
  promptMessage*: ColorScheme
  promptSymbol*: ColorScheme
  okResult*: ColorScheme
  info*: ColorScheme
  warning*: ColorScheme
  error*: ColorScheme


proc colorScheme*(
  fgColor: ForegroundColor = fgDefault,
  fgBright: bool = false,
  bgColor: BackgroundColor = bgDefault,
  bgBright: bool = false
): ColorScheme =
  ColorScheme(
    fg: if fgColor != fgDefault: some((fgColor, fgBright)) else: none[(ForegroundColor, bool)](),
    bg: if bgColor != bgDefault: some((bgColor, bgBright)) else: none[(BackgroundColor, bool)]()
  )


proc newOutput*(
  colored: bool = true,
  nim: ColorScheme = colorScheme(fgYellow, true),
  promptMessage: ColorScheme = colorScheme(fgYellow, false),
  promptSymbol: ColorScheme = colorScheme(),
  okResult: ColorScheme = colorScheme(fgCyan, false),
  info: ColorScheme = colorScheme(),
  warning: ColorScheme = colorScheme(fgYellow, false),
  error: ColorScheme = colorScheme(fgRed, false),
): Output =
  if not colored:
    let noColor = colorScheme()
    return Output(
      nim: noColor, promptMessage: noColor, promptSymbol: noColor,
      okResult: noColor, info: noColor, warning: noColor, error: noColor
    )
  else:
    return Output(
      nim: nim, promptMessage: promptMessage, promptSymbol: promptSymbol,
      okResult: okResult, info: info, warning: warning, error: error
    )


proc write*(self: Output, message: string, color: ColorScheme = colorScheme(), newline = true) =
  let fg = color.fg
  let bg = color.bg

  if fg.isSome:
    stdout.setForegroundColor(fg.get[0], fg.get[1])

  if bg.isSome:
    stdout.setBackgroundColor(bg.get[0], bg.get[1])

  stdout.write(message & (if newline: "\n" else: ""))
  stdout.resetAttributes()
  stdout.flushFile()


proc nim*(self: Output, message: string, newline = true) =
  self.write(message, self.nim, newline)


proc promptMessage*(self: Output, message: string, newline = true) =
  self.write(message, self.promptMessage, newline)


proc promptSymbol*(self: Output, message: string, newline = true) =
  self.write(message, self.promptSymbol, newline)


proc okResult*(self: Output, message: string, newline = true) =
  self.write(message, self.okResult, newline)


proc info*(self: Output, message: string, newline = true) =
  self.write(message, self.info, newline)


proc warning*(self: Output, message: string, newline = true) =
  self.write(message, self.warning, newline)


proc error*(self: Output, message: string, newline = true) =
  self.write(message, self.error, newline)


proc styledPrompt*(self: Output, message: string, symbol: string): Styler =
  var styler = Styler.init()
  var messageFg = self.promptMessage.fg
  var messageBg = self.promptMessage.bg
  var symbolFg = self.promptSymbol.fg
  var symbolBg = self.promptSymbol.bg

  if messageFg.isSome:
    styler.addCmd(messageFg.get[0])

  if messageBg.isSome:
    styler.addCmd(messageBg.get[0])

  styler.addCmd(message)
  styler.addCmd(TerminalCmd.resetStyle)

  if symbolFg.isSome:
    styler.addCmd(symbolFg.get[0])

  if symbolBg.isSome:
    styler.addCmd(symbolBg.get[0])

  styler.addCmd(symbol)
  styler.addCmd(TerminalCmd.resetStyle)

  return styler
