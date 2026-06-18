import std/[os, osproc, strformat, strutils]

import ../data/raw
import terminal
import build_info
import index
import query
import clipboard

const idx = buildIndex(KV_DATA)

const
  colorBlue = "\e[34m"
  colorReset = "\e[0m"

type
  QueryMode = object
    strict: bool
    andMode: bool

const queryModes = [
  ("-s",  QueryMode(strict: true,  andMode: false), "Strict match (OR)"),
  ("-sa", QueryMode(strict: true,  andMode: true),  "Strict match (AND)"),
  ("-c",  QueryMode(strict: false, andMode: false), "Contains match (OR)"),
  ("-ca", QueryMode(strict: false, andMode: true),  "Contains match (AND)")
]

proc formatEntry(r: KVEntry): string =
  &"{colorBlue}{r.compositeKey}{colorReset}  {r.value}"

proc parseMode(mode: string): QueryMode =
  for item in queryModes:
    if item[0] == mode:
      return item[1]

  stderr.writeLine &"Unknown mode: {mode}"
  quit(1)

proc runQuery(mode: string; terms: seq[string]): seq[KVEntry] =
  let m = parseMode(mode)
  query(idx, terms, strict = m.strict, andMode = m.andMode)

proc printResults(results: seq[KVEntry]) =
  if results.len == 0:
    echo "  No matches."
    return

  for r in results:
    echo "  " & formatEntry(r)

proc selectResult(results: seq[KVEntry]): KVEntry =
  ## 交互选择：方向键辅助 + 手动输入数字 + 回车确认。
  ## - 方向键 ↑/↓ 基于当前输入的数字进行增减（循环）
  ## - 直接按数字键可键入任意位数的数字（可退格修改）
  ## - 回车时：数字有效(1..N) → 确认选择；无效 → 提示错误并退出
  for i, r in results:
    stderr.writeLine &"  {i + 1} {formatEntry(r)}"

  let n = results.len
  let promptBase = &"Select (1-{n}): "
  stderr.write "\n" & promptBase
  stderr.flushFile()

  # 非交互回退（管道/重定向）
  if not isTty():
    let input = stdin.readLine().strip()
    let choice = try: parseInt(input) except ValueError: 0
    if choice < 1 or choice > n:
      stderr.writeLine "Invalid selection."
      quit(1)
    return results[choice - 1]

  # 交互主循环（raw 模式）
  var inputBuf = ""  # 用户输入的数字字符串（空表示未开始）

  enableRawMode()
  defer: disableRawMode()

  while true:
    let (key, ch) = readKeyAndChar()

    case key
    of kpDown:
      # 方向下：基于当前输入的数字递增（无输入时从 1 开始）
      var cur = try: parseInt(inputBuf) except ValueError: 0
      if cur < 1 or cur > n:
        cur = 1
      else:
        cur = if cur >= n: 1 else: cur + 1
      inputBuf = $cur
      stderr.write "\r" & promptBase & inputBuf & "\x1b[K"
      stderr.flushFile()
    of kpUp:
      # 方向上：基于当前输入的数字递减（无输入时从 N 开始）
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
        # 无效选择：恢复终端，输出错误并退出（与原始行为一致）
        stderr.write "\n"
        disableRawMode()   # 确保终端恢复，避免 stderr 显示异常
        stderr.writeLine "Invalid selection."
        quit(1)
    of kpOther:
      # 处理数字键和退格键
      if ch >= '0' and ch <= '9':
        inputBuf.add(ch)
        stderr.write "\r" & promptBase & inputBuf & "\x1b[K"
        stderr.flushFile()
      elif ch == '\x7f' or ch == '\b':    # 退格 (DEL / Backspace)
        if inputBuf.len > 0:
          inputBuf.setLen(inputBuf.len - 1)
          stderr.write "\r" & promptBase & inputBuf & "\x1b[K"
          stderr.flushFile()
      # 其他字符一律忽略

proc handleCopyResults(results: seq[KVEntry]) =
  if results.len == 0:
    echo "  No matches."
    return

  let selected =
    if results.len == 1:
      echo "  " & formatEntry(results[0])
      results[0]
    else:
      selectResult(results)

  osc52Copy(selected.value)
  stderr.writeLine "Copied."

proc getEditor(): string =
  let visual = getEnv("VISUAL")
  if visual.len > 0:
    return visual

  let editor = getEnv("EDITOR")
  if editor.len > 0:
    return editor

  "vi"

proc readFileOrEmpty(path: string): string =
  if fileExists(path):
    readFile(path)
  else:
    ""

proc runEdit() =
  let rawPath = ProjectRoot / "data" / "raw.nim"
  if not fileExists(rawPath):
    stderr.writeLine &"raw.nim not found: {rawPath}"
    quit(1)

  let before = readFileOrEmpty(rawPath)
  let editor = getEditor()
  let editCmd = editor & " " & quoteShell(rawPath)
  let editCode = execShellCmd(editCmd)
  if editCode != 0:
    stderr.writeLine &"Editor exited with code {editCode}."
    quit(editCode)

  let after = readFileOrEmpty(rawPath)
  if before == after:
    stderr.writeLine "No changes."
    return

  stderr.writeLine "Changes detected. Rebuilding and updating kvc..."

  # 当前运行的可执行文件路径
  let currentExe = getAppFilename()
  # 新编译的文件（放在可执行文件同目录的 .new 后缀，防止覆盖失败丢失）
  let newExe = currentExe & ".new"
  let backupExe = currentExe & ".bak"

  # 在项目目录下编译
  let oldDir = getCurrentDir()
  setCurrentDir(ProjectRoot)
  let buildCmd = "nim c -d:release --out:" & quoteShell(newExe) & " src/main.nim"
  let buildCode = execShellCmd(buildCmd)
  setCurrentDir(oldDir)

  if buildCode != 0:
    stderr.writeLine &"Build failed with code {buildCode}."
    if fileExists(newExe): removeFile(newExe)
    quit(buildCode)

  # 给新文件加上执行权限
  let chmodCmd = "chmod 700 " & quoteShell(newExe)
  discard execShellCmd(chmodCmd)

  # 备份当前文件（如存在）
  if fileExists(backupExe): removeFile(backupExe)
  if fileExists(currentExe):
    moveFile(currentExe, backupExe)

  # 用新文件替换
  try:
    moveFile(newExe, currentExe)
    stderr.writeLine "Updated: " & currentExe
    if fileExists(backupExe): removeFile(backupExe)
  except:
    # 替换失败，恢复备份
    stderr.writeLine "Failed to replace executable, restoring backup..."
    if fileExists(backupExe):
      moveFile(backupExe, currentExe)
    quit(1)
    
    
proc printHelp() =
  echo &"Usage: kvc {colorBlue}<command>{colorReset} [terms]"
  echo ""
  echo "Commands:"
  echo &"  {colorBlue}ls{colorReset}           List all"
  echo &"  {colorBlue}edit{colorReset}         Edit raw.nim and rebuild if changed"

  for item in queryModes:
    echo &"  {colorBlue}{item[0]}{colorReset} ...      {item[2]} + copy"

  echo &"  {colorBlue}-h{colorReset}           Show help"
  echo ""
  echo "Examples:"
  echo "  kvc -c app"
  echo "  kvc -ca fruit red"
  echo "  kvc -s apple"
  echo "  kvc edit"

proc main() =
  let args = commandLineParams()

  if args.len < 1 or args[0] == "-h" or args[0] == "--help":
    printHelp()
    return

  case args[0]
  of "ls":
    printResults(idx.v)

  of "edit":
    runEdit()

  of "-s", "-sa", "-c", "-ca":
    if args.len < 2:
      stderr.writeLine &"Usage: kvc {args[0]} <terms>"
      quit(1)

    let mode = args[0]
    let terms = args[1..^1]
    handleCopyResults(runQuery(mode, terms))

  else:
    stderr.writeLine &"Unknown command: {args[0]}"
    printHelp()
    quit(1)

when isMainModule:
  main()
  