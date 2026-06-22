import std/[base64, strformat]

proc osc52Copy*(text: string) =
  # 通过 OSC52 转义序列复制文本到终端剪贴板
  let encoded = base64.encode(text)
  stdout.write &"\x1b]52;c;{encoded}\x07"
