## User interface: output formatting, result listing, interactive selection, help.
import std/[strformat, strutils, unicode]
import ../utils/terminal
import ../core/index
from ../core/query import QueryModes

const
  ColorBlue   = "\e[34m"  # Key color, blue
  ColorPrefix = "\e[36m"  # Prefix color, cyan
  ColorDim    = "\e[2m"
  ColorReset  = "\e[0m"
  MaxValueDisplay = 60    # value 最大显示宽度

# 输出格式化
proc colorizeValue(value: string): string =
  var prefix = ""
  var rest = value
  for p in ["s: ", "f: ", "c: "]:
    if value.startsWith(p):
      prefix = p
      rest = value[prefix.len..^1]
      break

  # 如果没有前缀，直接将整串视为 rest
  if prefix == "":
    if rest.runeLen > MaxValueDisplay:  # runeLen 可处理 rest 中可能存在的特殊 Unicode
      # 截断并在末尾加暗色 ...
      result = rest.runeSubStr(0, MaxValueDisplay) & ColorDim & " ..." & ColorReset
    else:
      result = rest
  else:
    let available = MaxValueDisplay - prefix.len
    if rest.runeLen > available:
      result = ColorPrefix & prefix & ColorReset &
               rest.runeSubStr(0, available) & ColorDim & " ..." & ColorReset
    else:
      result = ColorPrefix & prefix & ColorReset & rest

proc formatEntry*(r: KVEntry): string =
  &"{ColorBlue}{r.compositeKey}{ColorReset}  {colorizeValue(r.value)}"

proc printResults*(results: seq[KVEntry]) =
  if results.len == 0:
    echo "  No matches."
    return
  for r in results:
    echo "  " & formatEntry(r)

# 交互选择，允许 方向键/手动输入
proc selectResult*(results: seq[KVEntry]): KVEntry =
  ## 交互选择，支持方向键与数字输入，回车确认。
  for i, r in results:
    stderr.writeLine &"  {i + 1} {formatEntry(r)}"

  let n = results.len
  let promptBase = &"Select (1-{n}): "
  stderr.write "\n" & promptBase
  stderr.flushFile()

  # 非交互回退
  if not isTty():
    let input = stdin.readLine().strip()
    let choice = try: parseInt(input) except ValueError: 0
    if choice < 1 or choice > n:
      stderr.writeLine "Invalid selection."
      quit(1)
    return results[choice - 1]

  # 交互主循环
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
      # 其他字符忽略

proc printHelp*() =
  echo &"Usage: kvc {ColorBlue}<command>{ColorReset} [terms]"
  echo ""
  echo "Commands:"
  echo &"  {ColorBlue}edit{ColorReset}         Edit raw.nim and rebuild if changed"
  echo &"  {ColorBlue}path{ColorReset}         Print project root path and copy it"
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
  