## Copy to system clipboard with "s: ", "f: ", "c: " prefix support.
import std/[base64, strformat, os, osproc, strutils]

proc osc52Copy(text: string) =
  # 通过 OSC52 转义序列复制文本到终端剪贴板
  let encoded = base64.encode(text)
  stdout.write &"\x1b]52;c;{encoded}\x07"

proc copyResolved*(raw: string) =
  ## 解析前缀并复制最终内容。支持 f: /path, c: command, s: text，无前缀为纯文本。
  var text: string
  if raw.startsWith("f: "):
    let path = raw[3..^1]
    if not fileExists(path):
      raise newException(IOError, "File not found: " & path)
    text = readFile(path)
  elif raw.startsWith("c: "):
    let cmd = raw[3..^1]
    text = execProcess(cmd, options={poUsePath, poEvalCommand, poStdErrToStdOut}).strip()
  elif raw.startsWith("s: "):
    text = raw[3..^1]
  else:
    text = raw
  osc52Copy(text)
