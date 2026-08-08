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

The helper keeps Erlang, LLVM/libc++, MinGW-w64, and Tesseract under Homebrew.
It reuses suitable host build tools and installs missing ones. GNU Make and a
Rust toolchain installed through [rustup](https://rustup.rs) must be available;
CMake must be 3.28 or newer.

The GUI build also needs a vcpkg checkout:

```bash
git clone https://github.com/microsoft/vcpkg "$HOME/vcpkg"
export VCPKG_ROOT="$HOME/vcpkg"
"$VCPKG_ROOT/bootstrap-vcpkg.sh" -disableMetrics
```

Install the build toolchain plus editor, test, preview, and packaging tools:

```bash
brew wfcli-deps dev
```

Both commands are idempotent.

## Profiles

### `build`

- Erlang/OTP
- LLVM with libc++
- MinGW-w64
- Rebar3
- Tesseract

Missing CMake, Autoconf tooling, ccache, Git, jq, Ninja, pkg-config, or Python
are installed after the managed toolchains.

### `dev`

Includes `build` plus:

- Erlang Language Platform
- rust-analyzer

Missing FFmpeg, Node.js, ripgrep, ShellCheck, and Zip are installed for this
profile.

The profiles target Linux. Live `wfcompanion` use additionally requires KDE
Plasma on Wayland and KScreen; those are supplied by the host distribution.
