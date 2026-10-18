class Retinue < Formula
  desc "Linux game companions, overlays, CLI, and desktop tools"
  homepage "https://github.com/ZeeWanderer/retinue"
  url "https://github.com/ZeeWanderer/retinue.git",
      tag:      "v0.3.0",
      revision: "583272e17199d1ba801ff4acffa92270e0d3a79a"
  license "Apache-2.0"
  head "https://github.com/ZeeWanderer/retinue.git", branch: "master"

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
  depends_on "python@3.14" => :build
  depends_on "rebar3" => :build
  depends_on "rust" => :build
  depends_on "sccache" => :build
  depends_on "vcpkg" => :build
  depends_on "zip" => :build
  depends_on arch: :x86_64
  depends_on "libxkbcommon"
  depends_on :linux
  depends_on "ncurses"
  depends_on "openssl@4"
  depends_on "tesseract"
  depends_on "wayland"
  depends_on "zlib-ng-compat"

  resource "vcpkg-registry" do
    url "https://github.com/microsoft/vcpkg.git",
        revision: "a42757564758c60651ebc616d9b000b7b91249ef"
  end

  service do
    state_dir = Pathname.new(Dir.home)/".local/state/retinue"
    log_dir = state_dir/"daemon-log"
    name linux: "retinue-daemon"
    run [opt_libexec/"bin/retinue-daemon", "foreground"]
    keep_alive crashed: true
    restart_delay 2
    working_dir state_dir
    log_path log_dir/"daemon.log"
    error_log_path log_dir/"daemon.log"
    environment_variables(
      RETINUE_PACKAGE_MANAGER:    "homebrew",
      RETINUE_DAEMON_IDLE_POLICY: "persistent",
      RETINUE_BUILD_FLAVOR:       "prod",
      RETINUE_INSTALL_ROOT:       opt_libexec,
      RETINUE_UPDATE_ROOT:        opt_libexec,
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
    ENV.prepend_path "PATH", formula_opt_libexec("python@3.14")/"bin"
    # Retain the old cache namespace across the formula rename.
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

    # Tool metadata follows vcpkg; library versions stay pinned by the GUI manifest.
    vcpkg = formula_opt_bin("vcpkg")/"vcpkg"
    system vcpkg, "version"
    system "git", "-C", vcpkg_root, "rev-parse", "HEAD"
    system vcpkg, "install", "--dry-run",
           "--x-manifest-root=#{buildpath}/apps/wfgui",
           "--x-install-root=#{buildpath}/_build/vcpkg_installed",
           "--overlay-triplets=#{buildpath}/cmake/vcpkg-triplets",
           "--overlay-ports=#{buildpath}/cmake/vcpkg-ports",
           "--triplet=x64-linux-llvm-libcxx",
           "--host-triplet=x64-linux-llvm-libcxx"

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
    %w[retinue retinue-daemon retinue-inspect wfcli poe2cli arccli
       wfcompanion poe2companion arccompanion wfinspect wf-luau-decompiler wfgui].each do |command|
      bin.install_symlink libexec/"bin"/command
    end
    %w[retinue wfcli poe2cli arccli].each do |command|
      bash_completion.install_symlink libexec/"share/bash-completion/completions/#{command}.bash" => command
    end
    pkgshare.install "scripts/migrate-wfcli-storage"
  end

  def caveats
    <<~EOS
      Steam launch options:
        Warframe: #{opt_bin}/wfcompanion launch -- %command%
        PoE2:     #{opt_bin}/poe2companion launch -- %command%

      Register the Warframe desktop launcher with: wfcli gui install
      Check companion health with: retinue doctor

      Disable any legacy wfdaemon.service before starting Retinue.
      To copy legacy wfcli settings and saved builds, close all clients and daemons,
      then review: #{opt_pkgshare}/migrate-wfcli-storage --dry-run
      Apply with --apply. Original data is retained; existing targets are not overwritten.
    EOS
  end

  test do
    assert_match "doctor", shell_output("env PATH=/usr/bin:/bin #{bin}/retinue --help")
    assert_match "retinue warframe <command>", shell_output("env PATH=/usr/bin:/bin #{bin}/wfcli --help")
    assert_match "companion", shell_output("#{bin}/poe2cli --help")
    assert_match "companion", shell_output("#{bin}/arccli --help")
    assert_match "Linux/Proton", shell_output("#{bin}/wfcompanion --help")
    assert_match "0.3.0", shell_output("#{bin}/poe2companion --version")
    assert_match "0.3.0", shell_output("#{bin}/arccompanion --version")
    assert_match "process inspection", shell_output("#{bin}/retinue-inspect --help")
    assert_match "process inspection", shell_output("#{bin}/wfinspect --help")
    assert_match "wfcli desktop client",
                 shell_output("env QT_QPA_PLATFORM=offscreen #{bin}/wfgui --help")
    assert_predicate libexec/"libexec/retinue_daemon/bin/retinue_daemon", :executable?
    assert_equal 1, Dir[libexec/"libexec/retinue_daemon/erts-*/bin/epmd"].length
    release = libexec/"libexec/retinue_daemon"
    erl = Dir[release/"erts-*/bin/erl"].fetch(0)
    system erl, "-boot", release/"releases/#{version}/start_clean", "-noshell", "-eval", <<~ERLANG
      {ok, _} = application:ensure_all_started(ssl),
      <<"ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad">> =
        binary:encode_hex(crypto:hash(sha256, <<"abc">>), lowercase),
      halt().
    ERLANG
    assert_predicate pkgshare/"migrate-wfcli-storage", :executable?
  end
end
