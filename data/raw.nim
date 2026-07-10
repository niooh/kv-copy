const KV_DATA* = [
  "apple | fruit | red | 苹果", "A sweet red fruit",
  "banana | fruit | yellow", "A long yellow fruit",
  "tomato | fruit | red | vegetable", "Botanically a fruit, culinarily a vegetable",

  "git clone", """my_git_clone() { git clone "$1" && cd "$(basename "$1" .git)" ; }
my_git_clone """,

  # command
  "date", "c: date '+%Y-%m-%d %H:%M:%S'",
  "hello | greet", "c: echo 'hello'",

  "readme", "r: cat \"$(kvc path)/README.md\"",
]
