# Homebrew Sundries

Homebrew tap for small tools and development helpers.

## Install

Install Retinue on Linux x86_64:

```bash
brew install zeewanderer/sundries/retinue
```

Retinue provides Warframe and Path of Exile 2 companions, a shared CLI/daemon,
and the Warframe desktop GUI. See the [setup guide](https://github.com/ZeeWanderer/retinue#install).
The former `wfcli` formula migrates to `retinue`; the `wfcli` command remains available.
Follow the [data migration guide](https://github.com/ZeeWanderer/retinue/blob/master/docs/data-sources.md#migrate-wfcli-storage)
to copy legacy settings and saved builds without overwriting existing Retinue data.

## Development

Add the tap and trust its dependency helper:

```bash
brew tap zeewanderer/sundries
brew trust --command zeewanderer/sundries/retinue-deps
```

Install the toolchain required by `make build` in
[`Retinue`](https://github.com/ZeeWanderer/retinue):

```bash
brew retinue-deps build
```

The helper keeps Erlang, LLVM/libc++, MinGW-w64, Tesseract, and native libraries under Homebrew.
It reuses suitable host build tools and installs missing ones. GNU Make and a
Rust toolchain installed through [rustup](https://rustup.rs) must be available;
CMake must be 3.28 or newer.

The GUI build needs a shared vcpkg ports checkout. The helper installs the vcpkg
executable if missing; no bootstrap or project-local checkout is needed:

```bash
git clone https://github.com/microsoft/vcpkg "$HOME/.local/share/vcpkg"
export VCPKG_ROOT="$HOME/.local/share/vcpkg"
```

Install the build toolchain plus editor, test, preview, and packaging tools:

```bash
brew retinue-deps dev
```

Both commands are idempotent.

## Profiles

### `build`

- Erlang/OTP
- LLVM with libc++
- MinGW-w64
- Rebar3
- Tesseract
- libxkbcommon and Wayland

Missing CMake, Autoconf tooling, Git, jq, Ninja, pkg-config, Python, sccache, or vcpkg
are installed after the managed toolchains.

### `dev`

Includes `build` plus:

- Erlang Language Platform
- rust-analyzer

Missing FFmpeg, Node.js, ripgrep, ShellCheck, and Zip are installed for this
profile.

The profiles target Linux. Live `wfcompanion` use additionally requires KDE
Plasma on Wayland and KScreen; those are supplied by the host distribution.
