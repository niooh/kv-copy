## Copy to system clipboard with "s: ", "f: ", "c: " prefix support.
import std/[base64, strformat, os, osproc, strutils]

proc osc52Copy(text: string) =
  let encoded = base64.encode(text)
  stdout.write &"\x1b]52;c;{encoded}\x07"

proc copyResolved*(raw: string): bool =
  ## Parse the prefix and copy the final content.
  ## Returns true if content was non‑empty and copied, false otherwise.
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

  if text.len == 0:
    return false

  osc52Copy(text)
  return true
