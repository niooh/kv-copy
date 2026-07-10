<p align="center">
  <img src="https://raw.githubusercontent.com/niooh/kv-query/main/docs/figures/logo.png" alt="kv logo" width="160px"/>
</p>
<h1 align="center">kv-copy</h1>

a lightweight tool lets you define key‑value entries in a single file, query them, and **copy the value directly to your clipboard**.  

## Features

- **Flexible search**: strict or partial matching, with OR / AND logic.
- **Multiple value sources**: static text, command output, or file contents.
- **Interactive selection**: when multiple results match, you can navigate with <kbd>↑ ↓</kbd> or type a number to select.
- **Self‑updating**: `kvc edit` opens your editor, and if you change the data, the tool rebuilds itself automatically.

## Data format

Entries are stored in `data/raw.nim` as a flat array where keys and values alternate:

```nim
const KV_DATA* = [
  "key1 | key2 | ...", "value",
  ...
]
```

Keys are separated by ` | ` (space‑pipe‑space) to allow multiple tags per entry.<br>

**Value prefixes**:

| Prefix | Copy behavior                       | Example              |
|--------|-------------------------------------|----------------------|
| `s: `  | Copy string (default if no prefix)  | `"s: Hello"`         |
| `f: `  | Copy file content by absolute path  | `"f: /etc/hosts"`    |
| `c: `  | Copy command output                 | `"c: date '+%H:%M'"` |
| `r: `  | Run command and do not copy         | `"r: pwd"`           |

> When the resolved value is empty (e.g. empty string, empty file, or command with no output), no clipboard copy is performed.

## Build

You need:
- Unix-like system, e.g., Linux, WSL2, macOS, Termux.
- One of these clipboard tools: `wl-copy | xclip | xsel | pbcopy | termux-clipboard-set`.<br>
  If none of them is found, the program falls back to **OSC52**, which may not work reliably for long text.
  To test OSC52 support, run `echo -e "\e]52;c;$(echo -n '😀' | base64)\a"` and paste somewhere. If `😀` appears, it works.
- [Nim](https://nim-lang.org) ≥ 2.0.0 installed.

Run:

```bash
git clone https://github.com/niooh/kv-copy && cd kv-copy/

# you can modify the parameters in `config.nims` before compiling
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
| `-s [terms]`  | Strict match, OR logic |
| `-sa [terms]` | Strict match, AND logic |
| `-c [terms]`  | Contains match, OR logic |
| `-ca [terms]` | Contains match, AND logic |
| `ls`          | List all entries |
| `edit`        | Open `data/raw.nim` in your editor; if changed, rebuild and replace the binary |
| `path [-c]`   | Show project root path; add `-c` to copy it to clipboard |

### Examples

```bash
$ kvc ls
  apple | fruit | red | 苹果  A sweet red fruit
  banana | fruit | yellow  A long yellow fruit
  ...

$ kvc -s red
  1 apple | fruit | red | 苹果  A sweet red fruit
  2 tomato | fruit | red | vegetable  Botanically a fruit, culinarily a vegetable

Select (1-2): 1
Copied.

$ kvc -ca app it
  apple | fruit | red | 苹果  A sweet red fruit
Copied.
```

### Selection

If a query returns a single entry, its value is copied immediately.

When multiple entries match, an interactive prompt appears:

- Initially the prompt shows `Select (1-N): ` with no number.
- <kbd>↓</kbd> moves to the next item, <kbd>↑</kbd> to the previous. Both wrap around at the edges.
- You can also type a number directly.
- Press <kbd>Enter</kbd> to confirm the current selection.
