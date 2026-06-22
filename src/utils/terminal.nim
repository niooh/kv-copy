## POSIX raw-mode terminal helpers for interactive single-keypress input.
## Uses termios directly via importc — no external dependencies needed.
import std/posix

# termios FFI

type
  CTermios {.importc: "struct termios", header: "<termios.h>", pure, final.} = object
    c_iflag  : cuint
    c_oflag  : cuint
    c_cflag  : cuint
    c_lflag  : cuint
    c_line   : char
    c_cc     : array[32, char]
    c_ispeed : cuint
    c_ospeed : cuint

proc tcgetattr(fd: cint; t: ptr CTermios): cint
  {.importc, header: "<termios.h>", discardable.}
proc tcsetattr(fd: cint; action: cint; t: ptr CTermios): cint
  {.importc, header: "<termios.h>", discardable.}
proc c_isatty(fd: cint): cint
  {.importc: "isatty", header: "<unistd.h>"}

# Terminal flag / index constants (POSIX values, stable across Linux and macOS)
const
  StdinFd  = 0.cint
  TcsaNow  = 0.cint
  EchoFlag = 0x8.cuint  # ECHO
  ICanon   = 0x2.cuint  # ICANON
  VMin     = 6          # c_cc index for VMIN
  VTime    = 5          # c_cc index for VTIME

# Public API

type KeyPress* = enum
  kpUp, kpDown, kpEnter, kpOther

var gOrigTermios: CTermios  ## saved original terminal state

proc isTty*(): bool =
  ## Returns true when stdin is an interactive terminal.
  c_isatty(StdinFd) != 0

proc enableRawMode*() =
  ## Disable echo and canonical (line-buffered) mode on stdin.
  tcgetattr(StdinFd, addr gOrigTermios)
  var raw = gOrigTermios
  raw.c_lflag = raw.c_lflag and not (EchoFlag or ICanon)
  raw.c_cc[VMin]  = char(1)   # return after 1 byte
  raw.c_cc[VTime] = char(0)   # no timeout
  tcsetattr(StdinFd, TcsaNow, addr raw)

proc disableRawMode*() =
  ## Restore the terminal to its state before enableRawMode.
  tcsetattr(StdinFd, TcsaNow, addr gOrigTermios)

proc readByte(): char =
  var c: char
  discard posix.read(StdinFd, addr c, 1)
  c

proc readKey*(): KeyPress =
  ## Block until one logical keypress is available, then return its kind.
  ## Arrow keys send a 3-byte ESC sequence; Enter sends CR or LF.
  let c = readByte()
  case c
  of '\r', '\n':
    return kpEnter
  of '\x1b':
    # Expect CSI: ESC [ <char>
    if readByte() == '[':
      case readByte()
      of 'A': return kpUp
      of 'B': return kpDown
      else:   return kpOther
    else:
      return kpOther
  else:
    return kpOther

proc readKeyAndChar*(): tuple[kind: KeyPress, ch: char] =
  ## Like readKey(), but also returns the first byte read.
  let c = readByte()
  case c
  of '\r', '\n':
    return (kpEnter, c)
  of '\x1b':
    if readByte() == '[':
      case readByte()
      of 'A': return (kpUp, c)
      of 'B': return (kpDown, c)
      else:   return (kpOther, c)
    else:
      return (kpOther, c)
  else:
    return (kpOther, c)
    