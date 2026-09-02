import std/[strutils, terminal]
import std/[logging]
export logging except log, debug, info, notice, warn, error, fatal
import common


var
  glevel {.threadvar.}: Level          ## global log filter
  handlers {.threadvar.}: seq[Logger] ## handlers with their own log levels

type
  NimbleConsoleLogger = ref object of Logger
    showColor*: bool
    useStderr*: bool ## If true, writes to stderr; otherwise, writes to stdout
    flushThreshold*: Level ## Only messages that are at or above this
                           ## threshold will be flushed immediately

const foregrounds: array[lvlDebug..lvlFatal, ForegroundColor] = [
  fgDefault, fgDefault, fgDefault, fgYellow, fgRed, fgRed
]

func genPaddings(): array[lvlDebug..lvlFatal, string] =
  for l in lvlDebug..lvlFatal:
    result[l] = "...".align(LevelNames[l].len).alignLeft(7)

const paddings = genPaddings()

proc newNimbleConsoleLogger*(levelThreshold = lvlAll, fmtStr = "",
    useStderr = true, flushThreshold = lvlAll): NimbleConsoleLogger =
  new result
  result.fmtStr = fmtStr
  result.levelThreshold = levelThreshold
  result.flushThreshold = flushThreshold
  result.useStderr = useStderr

method log*(logger: NimbleConsoleLogger, level: Level, args: varargs[string, `$`]) {.raises: [].} =
  ## Whether the message is logged depends on both the NimbleConsoleLogger's
  ## ``levelThreshold`` field and the global log filter set using the
  ## `setLogFilter proc<#setLogFilter,Level>`_.
  ##
  ## **Note:** Only error and fatal messages will cause the output buffer
  ## to be flushed immediately by default. Set ``flushThreshold`` when creating
  ## the logger to change this.
  #
  if level >= glevel and level >= logger.levelThreshold:
    let fmtStr = if level == lvlNotice: "" else: logger.fmtStr
    let msg = substituteLog(fmtStr, level, args)
    try:
      let handle = if  logger.useStderr: stderr else: stdout
      let name = LevelNames[level].alignLeft(6)
      if logger.showColor:
        let color = foregrounds[level]
        case level:
        of lvlNotice:
          if logger.levelThreshold < lvlNotice:
            styledWrite(handle, color, styleBright, name, " ")
        of lvlDebug:
          styledWrite(handle, color, styleDim, name, " ")
        else:
          styledWrite(handle, color, name, " ")
      else:
        if level != lvlNotice or logger.levelThreshold < lvlNotice:
          write(handle, name, " ")
      if level == lvlNotice and logger.levelThreshold >= lvlNotice:
        writeLine(handle, msg)
      else:
        let padding = paddings[level]
        var i = 0
        for l in msg.strip().splitLines():
          writeLine(handle, if i == 0: "" else: padding, l)
          inc i
      if level >= logger.flushThreshold:
        flushFile(handle)
    except IOError:
      discard

proc addHandler*(handler: Logger) =
  handlers.add(handler)

proc removeHandler*(handler: Logger) =
  for i, hnd in handlers:
    if hnd == handler:
      handlers.delete(i)
      return

proc getHandlers*(): seq[Logger] =
  return handlers

proc setLogFilter*(lvl: Level) =
  ## .. warning:: The global log filter is a thread-local variable. If logging
  ##   is being performed in multiple threads, this proc should be called in each
  ##   thread unless it is intended that different threads should log at different
  ##   logging levels.
  ##
  glevel = lvl

proc getLogFilter*(): Level =
  return glevel

proc logLoop(level: Level, args: varargs[string, `$`]) =
  for logger in items(handlers):
    if level >= logger.levelThreshold:
      log(logger, level, args)

template logImpl(level: Level, args: varargs[string, `$`]) =
  bind logLoop
  bind `%`
  bind glevel
  if level >= glevel:
    when defined(logLineNo):
      let pos = instantiationInfo()
      let logArgs = @["[" & pos.filename & ":" & $pos.line & "]"] & @args
      try: logLoop(level, logArgs)
      except: discard
    else:
      try: logLoop(level, args)
      except: discard

template log*(level: Level, args: varargs[string, `$`]) =
  bind logImpl
  logImpl(level, args)

template debug*(args: varargs[string, `$`]) =
  bind logImpl
  logImpl(lvlDebug, args)
template info*(args: varargs[string, `$`]) =
  bind logImpl
  logImpl(lvlInfo, args)
template notice*(args: varargs[string, `$`]) =
  bind logImpl
  logImpl(lvlNotice, args)
template warn*(args: varargs[string, `$`]) =
  bind logImpl
  logImpl(lvlWarn, args)
template error*(args: varargs[string, `$`]) =
  bind logImpl
  logImpl(lvlError, args)
template fatal*(args: varargs[string, `$`]) =
  bind logImpl
  logImpl(lvlFatal, args)

template error*(e: (ref CatchableError)) =
  bind logImpl
  logImpl(lvlError, e.msg)
  if e.parent != nil:
    logImpl(lvlError, (ref CatchableError)(e.parent))

template error*(e: ref NimbleError) =
  bind logImpl
  procCall logImpl(lvlError,(ref CatchableError)(e))
  logImpl(lvlError, "HINT: ", e.hint)

var consoleLogger* = newNimbleConsoleLogger(useStderr = true)

# TODO: RollingFileLogger
addHandler consoleLogger

