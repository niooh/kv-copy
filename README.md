<h1 align="center">kvc</h1>

`kvc` lets you define key‑value entries in a Nim file, query them, and **copy the value directly to your clipboard** using OSC 52.  

## Features

- **Compiled index**: data lives in `data/raw.nim` and is embedded at compile time for instant lookup.
- **Flexible search**: strict or partial matching, with OR / AND logic.
- **Interactive selection**: when multiple results match, you can navigate with <kbd>↑ ↓</kbd> or type a number to select.
- **Self‑updating editor**: `kvc edit` opens your editor, and if you change the data, the tool rebuilds itself automatically.

## Data format

Entries are stored in `data/raw.nim` as a flat array where keys and values alternate.
Keys are separated by ` | ` (space‑pipe‑space) to allow multiple tags per entry:

```nim
const KV_DATA* = [
  "apple | fruit | red", "A sweet red fruit",
  "banana | fruit | yellow", "A long yellow fruit",
  "carrot | vegetable | orange", "A crunchy orange root",
  "tomato | fruit | red | vegetable", "Botanically a fruit, culinarily a vegetable",
  "grape | fruit | purple", "Small round fruit for wine",
  "apple | 苹果", "中文测试"
]
```


## Build

You need [Nim](https://nim-lang.org) ≥ 2.0.0 installed.

```bash
git clone https://github.com/niooh/kvc && cd kvc/
nim c -d:release --out:dist/kvc src/main.nim
```

Or, if you have [npm](https://github.com/npm/cli), you can use the convenience script:

```bash
npm run build
```

The resulting binary `dist/kvc` is a self‑contained binary. You can run it directly from any directory, or place it in a directory on your `PATH` to call it as `kvc` anywhere.

## Usage

```bash
kvc <command> [terms]
```

### Commands

| Command       | Description |
|---------------|-------------|
| `-h`          | Show help   |
| `ls`          | List all entries |
| `edit`        | Open `data/raw.nim` in your editor; if changed, rebuild and replace the binary |
| `-s [terms]`  | Strict match, OR logic |
| `-sa [terms]` | Strict match, AND logic |
| `-c [terms]`  | Contains match, OR logic |
| `-ca [terms]` | Contains match, AND logic |

### Examples

```bash
$ kvc ls
  apple | fruit | red  A sweet red fruit
  apple | 苹果  中文测试
  ...

$ kvc -c apple
  1 apple | fruit | red  A sweet red fruit
  2 apple | 苹果  中文测试

Select (1-2): 1
Copied.
```

Now paste and you’ll see `A sweet red fruit`.

## Selection

If a query returns a single entry, its value is copied immediately — no prompt.

When multiple entries match, an interactive prompt appears:

- Initially the prompt shows `Select (1-N): ` with no number.
- <kbd>↓</kbd> moves to the next item, <kbd>↑</kbd> to the previous. Both wrap around at the edges.
- You can also type a number directly.
- Press <kbd>Enter</kbd> to confirm the current selection.

## Configuration

- `data/raw.nim`: your actual key‑value data.
- `config.nims`: compiler settings (optimisations, paths).
- The `$EDITOR` or `$VISUAL` environment variable is respected for the `edit` command.

## License

MIT
