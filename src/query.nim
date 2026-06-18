import std/[strutils, tables]
import index

## 运行时查询逻辑

# 两个有序 seq 的并集，去重，保持升序
func mergeUnion(a, b: seq[int]): seq[int] =
  var i = 0
  var j = 0

  while i < a.len and j < b.len:
    if a[i] < b[j]:
      result.add(a[i])
      inc i
    elif a[i] > b[j]:
      result.add(b[j])
      inc j
    else:
      result.add(a[i])
      inc i
      inc j

  while i < a.len:
    result.add(a[i])
    inc i

  while j < b.len:
    result.add(b[j])
    inc j


# 两个有序 seq 的交集，保持升序
func mergeIntersect(a, b: seq[int]): seq[int] =
  var i = 0
  var j = 0

  while i < a.len and j < b.len:
    if a[i] < b[j]:
      inc i
    elif a[i] > b[j]:
      inc j
    else:
      result.add(a[i])
      inc i
      inc j


# 包含匹配：线性扫描关键词，并用归并并集合并 ID
func findContainsIds*(idx: KVIndex; term: string): seq[int] =
  for kw in idx.k:
    if kw.contains(term):
      result = mergeUnion(result, idx.map[kw])


# 交集 (AND)
func intersect*(sets: seq[seq[int]]): seq[int] =
  if sets.len == 0:
    return @[]
  if sets.len == 1:
    return sets[0]

  result = sets[0]
  for i in 1 ..< sets.len:
    result = mergeIntersect(result, sets[i])
    if result.len == 0:
      break


# 并集 (OR)
func union*(sets: seq[seq[int]]): seq[int] =
  if sets.len == 0:
    return @[]

  result = sets[0]
  for i in 1 ..< sets.len:
    result = mergeUnion(result, sets[i])


# 查询接口
func query*(idx: KVIndex; terms: seq[string]; strict: bool; andMode: bool): seq[KVEntry] =
  var groups: seq[seq[int]] = @[]

  for term in terms:
    if strict:
      groups.add(idx.map.getOrDefault(term, @[]))
    else:
      groups.add(findContainsIds(idx, term))

  let final =
    if andMode: intersect(groups)
    else: union(groups)

  result = newSeqOfCap[KVEntry](final.len)

  for id in final:
    if id >= 0 and id < idx.v.len:
      result.add(idx.v[id])
