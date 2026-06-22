import std/[algorithm, strutils, tables]

## 编译时索引构建
const SEP* = " | "

type
  KVEntry* = object
    compositeKey*: string
    value*: string

  KVIndex* = object
    map*: Table[string, seq[int]]   # 哈希表
    k*: seq[string]                 # 所有关键词（供 contains 遍历）
    v*: seq[KVEntry]                # 原始条目

func buildIndex*(data: openArray[string]): KVIndex =
  assert data.len mod 2 == 0

  var
    entries: seq[KVEntry]
    keywordMap = initTable[string, seq[int]]()
    keywords: seq[string]

  # 解析条目
  for i in countup(0, data.len - 1, 2):
    entries.add(KVEntry(compositeKey: data[i], value: data[i + 1]))

  # 构建哈希映射
  for id, entry in entries:
    for key in entry.compositeKey.split(SEP):
      if key notin keywordMap:
        keywords.add(key)
        keywordMap[key] = @[id]
      else:
        keywordMap[key].add(id)

  # 对每个 ID 列表排序
  for key in keywords:
    keywordMap[key].sort(cmp[int])

  keywords.sort(cmp[string])

  result = KVIndex(map: keywordMap, k: keywords, v: entries)
