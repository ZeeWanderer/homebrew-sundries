class Wfcli < Formula
  desc "Warframe toolkit for terminal, desktop, MCP, and Linux/Proton overlays"
  homepage "https://github.com/ZeeWanderer/wfcli"
  url "https://github.com/ZeeWanderer/wfcli.git",
      tag:      "v0.2.0",
      revision: "e808f7ca1678ca7cfcbfbbd9361c829ae19e5c54"
  license "Apache-2.0"
  head "https://github.com/ZeeWanderer/wfcli.git", branch: "master"

  bottle do
    root_url "https://ghcr.io/v2/zeewanderer/sundries"
    sha256 cellar: :any, x86_64_linux: "f4a7f4896f9a99070d9ce468c71b39df438fbe6bdd979e49becc8115955bb662"
  end

  depends_on "autoconf" => :build
  depends_on "autoconf-archive" => :build
  depends_on "automake" => :build
  depends_on "cmake" => :build
  depends_on "erlang" => :build
  depends_on "libtool" => :build
  depends_on "llvm" => :build
  depends_on "mingw-w64" => :build
  depends_on "ninja" => :build
  depends_on "patchelf" => :build
  depends_on "pkgconf" => :build
  depends_on "rebar3" => :build
  depends_on "rust" => :build
  depends_on "sccache" => :build
  depends_on "vcpkg" => :build
  depends_on "zip" => :build
  depends_on arch: :x86_64
  depends_on "libxkbcommon"
  depends_on :linux
  depends_on "ncurses"
  depends_on "openssl@3"
  depends_on "tesseract"
  depends_on "wayland"
  depends_on "zlib-ng-compat"

  resource "vcpkg-registry" do
    url "https://github.com/microsoft/vcpkg.git",
        revision: "9e593bb18ea69cc5095e012465dcd675a822ed0d"
  end

  service do
    state_dir = Pathname.new(Dir.home)/".local/state/wfcli"
    log_dir = Pathname.new(Dir.home)/".cache/wfcli/daemon-log"
    name linux: "wfdaemon"
    run [opt_libexec/"bin/wfdaemon", "foreground"]
    keep_alive crashed: true
    restart_delay 2
    working_dir state_dir
    log_path log_dir/"wfdaemon.log"
    error_log_path log_dir/"wfdaemon.log"
    environment_variables(
      WFCLI_PACKAGE_MANAGER:      "homebrew",
      WFCLI_DAEMON_IDLE_POLICY:   "persistent",
      WFCLI_BUILD_FLAVOR:         "prod",
      WFCLI_INSTALL_ROOT:         opt_libexec,
      WFCLI_UPDATE_ROOT:          opt_libexec,
      RUNNER_LOG_DIR:             log_dir,
      ERL_CRASH_DUMP:             state_dir/"erl_crash.dump",
      LD_PRELOAD:                 "",
      LD_LIBRARY_PATH:            "",
      STEAM_RUNTIME:              "",
      STEAM_RUNTIME_LIBRARY_PATH: "",
    )
  end

  def install
    ENV.runtime_cpu_detection
    ENV.llvm_clang
    cache_root = HOMEBREW_CACHE/"wfcli-build"
    sccache_dir = cache_root/"sccache"
    sccache_socket = cache_root/"sccache.sock"
    vcpkg_archives = cache_root/"vcpkg/archives"
    vcpkg_downloads = cache_root/"vcpkg/downloads"
    cache_root.mkpath
    sccache_dir.mkpath
    vcpkg_archives.mkpath
    vcpkg_downloads.mkpath
    ln_s cache_root, buildpath/".cache" if cache_root != buildpath/".cache"

    vcpkg_root = buildpath/"vcpkg"
    resource("vcpkg-registry").stage vcpkg_root
    ln_sf formula_opt_bin("vcpkg")/"vcpkg", vcpkg_root/"vcpkg"
    inreplace "cmake/vcpkg-triplets/x64-linux-llvm-libcxx.cmake",
              "set(VCPKG_LIBRARY_LINKAGE dynamic)",
              "set(VCPKG_LIBRARY_LINKAGE dynamic)\nset(VCPKG_BUILD_TYPE release)"
    inreplace "CMakePresets.json",
              '"VCPKG_DEFAULT_BINARY_CACHE": "${sourceDir}/.cache/vcpkg/archives"',
              %Q("VCPKG_BINARY_SOURCES": "clear;files,#{vcpkg_archives},readwrite")
    toolchain = buildpath/"cmake/toolchains/llvm-libcxx.cmake"
    if toolchain.read.include?("WFCLI_CCACHE")
      inreplace toolchain, "WFCLI_CCACHE", "WFCLI_SCCACHE"
      inreplace toolchain, "NAMES ccache", "NAMES sccache"
    end

    ENV["CARGO_HOME"] = cache_root/"cargo"
    ENV["CMAKE_C_COMPILER_LAUNCHER"] = formula_opt_bin("sccache")/"sccache"
    ENV["CMAKE_CXX_COMPILER_LAUNCHER"] = formula_opt_bin("sccache")/"sccache"
    ENV["LLVM_ROOT"] = formula_opt_prefix("llvm")
    ENV["RUSTC_WRAPPER"] = formula_opt_bin("sccache")/"sccache"
    ENV["SCCACHE_BASEDIRS"] = buildpath
    ENV["SCCACHE_CACHE_SIZE"] = "2G"
    ENV["SCCACHE_DIR"] = sccache_dir
    ENV["SCCACHE_SERVER_UDS"] = sccache_socket
    ENV["VCPKG_DOWNLOADS"] = vcpkg_downloads
    ENV["VCPKG_ROOT"] = vcpkg_root

    sccache = formula_opt_bin("sccache")/"sccache"
    system sccache, "--show-stats" unless quiet_system(sccache, "--start-server")

    system "make", "prod",
           "LLVM_ROOT=#{formula_opt_prefix("llvm")}",
           "NINJA=#{formula_opt_bin("ninja")}/ninja"
    system sccache, "--show-stats"
    quiet_system sccache, "--stop-server"

    gui_rpath = %w[libxkbcommon wayland].map { |dependency| formula_opt_lib(dependency) }.join(File::PATH_SEPARATOR)
    system "patchelf", "--set-rpath", "#{gui_rpath}:$ORIGIN:$ORIGIN/../lib", "prod/bin/wfgui"
    Dir["prod/Qt6/plugins/**/*.so", "prod/lib/libQt6*.so.*"].each do |object|
      next if File.symlink?(object)

      system "patchelf", "--add-rpath", gui_rpath, object
    end
    %w[libc++.so.1 libc++abi.so.1 libunwind.so.1].each do |library|
      system "patchelf", "--set-rpath", "$ORIGIN", "prod/lib/#{library}"
    end
    libexec.install Dir["prod/*"]
    %w[wfcli wfcompanion wfdaemon wfinspect wfgui].each do |command|
      bin.install_symlink libexec/"bin"/command
    end
  end

  test do
    assert_match "COMMANDS:", shell_output("env PATH=/usr/bin:/bin #{bin}/wfcli --help")
    assert_match "Linux/Proton", shell_output("#{bin}/wfcompanion --help")
    assert_match "runtime diagnostics", shell_output("#{bin}/wfinspect --help")
    assert_match "wfcli desktop client",
                 shell_output("env QT_QPA_PLATFORM=offscreen #{bin}/wfgui --help")
    assert_predicate libexec/"libexec/wfdaemon/bin/wfdaemon", :executable?
    assert_equal 1, Dir[libexec/"libexec/wfdaemon/erts-*/bin/epmd"].length
  end
end
