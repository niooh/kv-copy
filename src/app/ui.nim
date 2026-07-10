## User interface: output formatting, result listing, interactive selection, help.
import std/[strformat, strutils, unicode]
import ../utils/terminal
import ../core/index
from ../core/query import QueryModes

const
  ColorYellow = "\e[33m"  # Number color
  ColorBlue   = "\e[34m"  # Key color
  ColorCyan = "\e[36m"  # Prefix color
  ColorDim    = "\e[2m"
  ColorReset  = "\e[0m"
  MaxValueDisplay = 60    # value 最大显示宽度

# Output formatting
proc colorizeValue(value: string): string =
  var prefix = ""
  var rest = value
  for p in ["s: ", "f: ", "c: ", "r: "]:
    if value.startsWith(p):
      prefix = p
      rest = value[prefix.len..^1]
      break

  if prefix == "":
    if rest.runeLen > MaxValueDisplay:  # `runeLen` can handle special Unicode characters that may exist in rest.
      # Truncate and append a dimmed "..." at the end.
      result = rest.runeSubStr(0, MaxValueDisplay) & ColorDim & " ..." & ColorReset
    else:
      result = rest
  else:
    let available = MaxValueDisplay - prefix.len
    if rest.runeLen > available:
      result = ColorCyan & prefix & ColorReset &
               rest.runeSubStr(0, available) & ColorDim & " ..." & ColorReset
    else:
      result = ColorCyan & prefix & ColorReset & rest

proc formatEntry*(r: KVEntry): string =
  &"{ColorBlue}{r.compositeKey}{ColorReset}  {colorizeValue(r.value)}"

proc printResults*(results: seq[KVEntry]) =
  if results.len == 0:
    echo "  No matches."
    return
  for r in results:
    echo "  " & formatEntry(r)

# Interactive selection: allows arrow keys / manual input.
proc selectResult*(results: seq[KVEntry]): KVEntry =
  for i, r in results:
    stderr.writeLine &"  {ColorYellow}{i + 1}{ColorReset} {formatEntry(r)}"

  let n = results.len
  let promptBase = &"Select ({ColorYellow}1-{n}{ColorReset}): "
  stderr.write "\n" & promptBase
  stderr.flushFile()

  if not isTty():
    let input = stdin.readLine().strip()
    let choice = try: parseInt(input) except ValueError: 0
    if choice < 1 or choice > n:
      stderr.writeLine "Invalid selection."
      quit(1)
    return results[choice - 1]

  # main interaction loop
  var inputBuf = ""

  enableRawMode()
  defer: disableRawMode()

  while true:
    let (key, ch) = readKeyAndChar()

    case key
    of kpDown:
      var cur = try: parseInt(inputBuf) except ValueError: 0
      if cur < 1 or cur > n:
        cur = 1
      else:
        cur = if cur >= n: 1 else: cur + 1
      inputBuf = $cur
      stderr.write "\r" & promptBase & inputBuf & "\x1b[K"
      stderr.flushFile()
    of kpUp:
      var cur = try: parseInt(inputBuf) except ValueError: 0
      if cur < 1 or cur > n:
        cur = n
      else:
        cur = if cur <= 1: n else: cur - 1
      inputBuf = $cur
      stderr.write "\r" & promptBase & inputBuf & "\x1b[K"
      stderr.flushFile()
    of kpEnter:
      let choice = try: parseInt(inputBuf) except ValueError: 0
      if choice >= 1 and choice <= n:
        stderr.write "\n"
        return results[choice - 1]
      else:
        stderr.write "\n"
        disableRawMode()
        stderr.writeLine "Invalid selection."
        quit(1)
    of kpOther:
      if ch >= '0' and ch <= '9':
        inputBuf.add(ch)
        stderr.write "\r" & promptBase & inputBuf & "\x1b[K"
        stderr.flushFile()
      elif ch == '\x7f' or ch == '\b':
        if inputBuf.len > 0:
          inputBuf.setLen(inputBuf.len - 1)
          stderr.write "\r" & promptBase & inputBuf & "\x1b[K"
          stderr.flushFile()
      # ignore other characters

proc printHelp*() =
  echo &"Usage: kvc {ColorBlue}<command>{ColorReset} [terms]"
  echo ""
  echo "Commands:"
  echo &"  {ColorBlue}edit{ColorReset}         Edit raw.nim and rebuild if changed"
  echo &"  {ColorBlue}path{ColorReset} [-c]    Print project root path, use `-c` to copy"
  echo &"  {ColorBlue}ls{ColorReset}           List all"
  for item in QueryModes:
    echo &"  {ColorBlue}{item[0]}{ColorReset} ...      {item[2]}"
  echo &"  {ColorBlue}-h{ColorReset}           Show help"
  echo ""
  echo "Examples:"
  echo "  kvc -c app"
  echo "  kvc -ca fruit red"
  echo "  kvc -s apple"
  echo "  kvc edit"
  