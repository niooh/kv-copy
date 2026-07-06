import std/[base64, strformat, os, osproc, strutils, streams]

type ClipboardBackend = enum
  cbOsc52
  cbPbcopy
  cbWlCopy
  cbXclip
  cbXsel
  cbTermux

# Allow users to force specify the backend via compile flags, otherwise automatically detect the build environment at compile time.
when defined(clipboardBackend):
  # nim c -d:clipboardBackend=Pbcopy ...
  const BACKEND = parseEnum[ClipboardBackend]("cb" & clipboardBackend)
else:
  const BACKEND = block:
    var detected: ClipboardBackend
    if staticExec("command -v termux-clipboard-set 2>/dev/null").len > 0:
      detected = cbTermux
    elif staticExec("command -v wl-copy 2>/dev/null").len > 0:
      detected = cbWlCopy
    elif staticExec("command -v xclip 2>/dev/null").len > 0:
      detected = cbXclip
    elif staticExec("command -v xsel 2>/dev/null").len > 0:
      detected = cbXsel
    elif staticExec("command -v pbcopy 2>/dev/null").len > 0:
      detected = cbPbcopy
    else:
      detected = cbOsc52
    detected

proc osc52Copy(text: string) =
  let encoded = base64.encode(text)
  stdout.write &"\x1b]52;c;{encoded}\x07"

proc pipeToProcess(cmd: string, args: openArray[string], text: string) =
  let p = startProcess(cmd, args = args, options = {poUsePath})
  p.inputStream.write(text)
  p.inputStream.close()
  discard p.waitForExit()
  p.close()

proc copyToClipboard(text: string) =
  case BACKEND
  of cbWlCopy:
    pipeToProcess("wl-copy", [], text)
  of cbXclip:
    pipeToProcess("xclip", ["-selection", "clipboard"], text)
  of cbXsel:
    pipeToProcess("xsel", ["--clipboard", "--input"], text)
  of cbPbcopy:
    pipeToProcess("pbcopy", [], text)
  of cbTermux:
    pipeToProcess("termux-clipboard-set", [], text)
  of cbOsc52:
    osc52Copy(text)

proc copyResolved*(raw: string): bool =
  ## Parse the prefix and copy the final content.
  ## Returns true if content was non-empty and copied, false otherwise.
  var text: string
  if raw.startsWith("f: "):
    let path = raw[3..^1]
    if not fileExists(path):
      raise newException(IOError, "File not found: " & path)
    text = readFile(path)
  elif raw.startsWith("c: "):
    let cmd = raw[3..^1]
    text = execProcess(cmd, options = {poUsePath, poEvalCommand, poStdErrToStdOut})
    text.removeSuffix("\n")  # remove trailing newlines
  elif raw.startsWith("s: "):
    text = raw[3..^1]
  else:
    text = raw

  if text.len == 0:
    return false

  copyToClipboard(text)
  return true
