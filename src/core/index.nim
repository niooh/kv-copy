import std/[algorithm, strutils, tables]

## Compile-time index building
const SEP* = " | "

type
  KVEntry* = object
    compositeKey*: string
    value*: string

  KVIndex* = object
    map*: Table[string, seq[int]]  # Hash table
    k*: seq[string]                # All keywords, for contains iteration
    v*: seq[KVEntry]               # Raw entries

func buildIndex*(data: openArray[string]): KVIndex =
  assert data.len mod 2 == 0

  var
    entries: seq[KVEntry]
    keywordMap = initTable[string, seq[int]]()
    keywords: seq[string]

  # parse entries
  for i in countup(0, data.len - 1, 2):
    entries.add(KVEntry(compositeKey: data[i], value: data[i + 1]))

  # build hash map
  for id, entry in entries:
    for key in entry.compositeKey.split(SEP):
      if key notin keywordMap:
        keywords.add(key)
        keywordMap[key] = @[id]
      else:
        keywordMap[key].add(id)

  # sort each ID list
  for key in keywords:
    keywordMap[key].sort(cmp[int])

  keywords.sort(cmp[string])

  result = KVIndex(map: keywordMap, k: keywords, v: entries)
