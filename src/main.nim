import std/[os, strformat]
import ../data/raw
import app/[ui, editor]
import core/[index, query]
import utils/copy
import build_info

const idx = buildIndex(KV_DATA)

proc main() =
  let args = commandLineParams()

  if args.len < 1 or args[0] == "-h" or args[0] == "--help":
    printHelp()
    return

  case args[0]
  of "edit":
    runEdit()

  of "path":
    echo ProjectRoot

  of "ls":
    printResults(idx.v)

  of "-s", "-sa", "-c", "-ca":
    if args.len < 2:
      stderr.writeLine &"Usage: kvc {args[0]} <terms>"
      quit(1)
    let results = runQuery(idx, args[0], args[1..^1])

    if results.len == 0:
      echo "  No matches."
      return

    let selected =
      if results.len == 1:
        echo "  " & formatEntry(results[0])
        results[0]
      else:
        selectResult(results)

    copyResolved(selected.value)  # 解析并复制
    stderr.writeLine "Copied."
  
  else:
    stderr.writeLine &"Unknown command: {args[0]}"
    printHelp()
    quit(1)

when isMainModule:
  main()
  