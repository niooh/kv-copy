## Edit raw.nim and self-rebuild / replace the running binary.
import std/[os, osproc, strformat]
import ../build_info

proc getEditor*(): string =
  let visual = getEnv("VISUAL")
  if visual.len > 0: return visual
  let editor = getEnv("EDITOR")
  if editor.len > 0: return editor
  return "vi"

proc readFileOrEmpty(path: string): string =
  if fileExists(path): readFile(path) else: ""

proc runEdit*() =
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

  let currentExe = getAppFilename()
  let newExe = currentExe & ".new"
  let backupExe = currentExe & ".bak"

  let oldDir = getCurrentDir()
  setCurrentDir(ProjectRoot)
  let buildCmd = "nim c -d:release --out:" & quoteShell(newExe) & " src/main.nim"
  let buildCode = execShellCmd(buildCmd)
  setCurrentDir(oldDir)

  if buildCode != 0:
    stderr.writeLine &"Build failed with code {buildCode}."
    if fileExists(newExe): removeFile(newExe)
    quit(buildCode)

  discard execShellCmd("chmod 700 " & quoteShell(newExe))

  if fileExists(backupExe): removeFile(backupExe)
  if fileExists(currentExe):
    moveFile(currentExe, backupExe)

  try:
    moveFile(newExe, currentExe)
    stderr.writeLine "Updated: " & currentExe
    if fileExists(backupExe): removeFile(backupExe)
  except:
    stderr.writeLine "Failed to replace executable, restoring backup..."
    if fileExists(backupExe):
      moveFile(backupExe, currentExe)
    quit(1)
    