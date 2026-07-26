# Homebrew Sundries

Homebrew tap for small tools and development helpers.

## Install

Add the tap and trust its dependency helper:

```bash
brew tap zeewanderer/sundries
brew trust --command zeewanderer/sundries/wfcli-deps
```

Install the toolchain required by `make build` in
[`wfcli`](https://github.com/ZeeWanderer/wfcli):

```bash
brew wfcli-deps build
```

Install the build toolchain plus editor, test, preview, and packaging tools:

```bash
brew wfcli-deps dev
```

Both commands are idempotent Homebrew Bundle profiles.

## Profiles

### `build`

- CMake
- Erlang/OTP
- Git
- jq
- GNU Make
- MinGW-w64
- Rebar3
- Rust

### `dev`

Includes `build` plus:

- ccache
- Erlang Language Platform
- FFmpeg
- LLVM and clangd
- Node.js
- ripgrep
- rust-analyzer
- ShellCheck
- Tesseract
- Zip

The profiles target Linux. A host C/C++ toolchain is required. Live
`wfcompanion` use additionally requires KDE Plasma on Wayland, KScreen, and
Spectacle; those are supplied by the host distribution rather than Homebrew.
