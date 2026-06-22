import std/[os, strformat]
import ../data/raw
import app/[ui, editor]
import core/[index, query]

const idx = buildIndex(KV_DATA)

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
    let results = runQuery(idx, args[0], args[1..^1])
    handleCopyResults(results)

  else:
    stderr.writeLine &"Unknown command: {args[0]}"
    printHelp()
    quit(1)

when isMainModule:
  main()
  