class Wfcli < Formula
  desc "Warframe toolkit for terminal, desktop, MCP, and Linux/Proton overlays"
  homepage "https://github.com/ZeeWanderer/wfcli"
  url "https://github.com/ZeeWanderer/wfcli.git",
      tag:      "v0.1.0",
      revision: "5d9b15e9b8ac59cea3bb7ea6a713a2de0118bb71"
  license "Apache-2.0"
  head "https://github.com/ZeeWanderer/wfcli.git", branch: "master"

  depends_on "autoconf" => :build
  depends_on "autoconf-archive" => :build
  depends_on "automake" => :build
  depends_on "cmake" => :build
  depends_on "libtool" => :build
  depends_on "llvm" => :build
  depends_on "mingw-w64" => :build
  depends_on "patchelf" => :build
  depends_on "pkgconf" => :build
  depends_on "rebar3" => :build
  depends_on "rust" => :build
  depends_on "vcpkg" => :build
  depends_on arch: :x86_64
  depends_on "erlang"
  depends_on "libxkbcommon"
  depends_on :linux
  depends_on "mesa"
  depends_on "ncurses"
  depends_on "openssl@3"
  depends_on "tesseract"
  depends_on "wayland"
  depends_on "zlib-ng-compat"

  resource "vcpkg-registry" do
    url "https://github.com/microsoft/vcpkg.git",
        revision: "9e593bb18ea69cc5095e012465dcd675a822ed0d"
  end

  def install
    ENV.llvm_clang
    vcpkg_root = buildpath/"vcpkg"
    resource("vcpkg-registry").stage vcpkg_root
    ln_sf formula_opt_bin("vcpkg")/"vcpkg", vcpkg_root/"vcpkg"
    inreplace "cmake/vcpkg-triplets/x64-linux-llvm-libcxx.cmake",
              "set(VCPKG_LIBRARY_LINKAGE dynamic)",
              "set(VCPKG_LIBRARY_LINKAGE dynamic)\nset(VCPKG_BUILD_TYPE release)"

    ENV["CARGO_HOME"] = buildpath/".cache/cargo"
    ENV["CCACHE_DISABLE"] = "1"
    ENV["LLVM_ROOT"] = formula_opt_prefix("llvm")
    ENV["VCPKG_ROOT"] = vcpkg_root
    mkdir_p buildpath/".cache/vcpkg/archives"

    system "make", "prod",
           "LLVM_ROOT=#{formula_opt_prefix("llvm")}",
           "NINJA=#{formula_opt_bin("ninja")}/ninja"

    gui_rpath = %w[libxkbcommon mesa wayland].map { |dependency| formula_opt_lib(dependency) }.join(File::PATH_SEPARATOR)
    system "patchelf", "--set-rpath", "#{gui_rpath}:$ORIGIN:$ORIGIN/../lib", "prod/bin/wfgui"
    Dir["prod/Qt6/plugins/**/*.so", "prod/lib/libQt6*.so.*"].each do |object|
      next if File.symlink?(object)

      system "patchelf", "--add-rpath", gui_rpath, object
    end
    %w[libc++.so.1 libc++abi.so.1 libunwind.so.1].each do |library|
      system "patchelf", "--set-rpath", "$ORIGIN", "prod/lib/#{library}"
    end
    libexec.install Dir["prod/*"]
    %w[wfcli wfcompanion wfdaemon wfgui].each do |command|
      bin.install_symlink libexec/"bin"/command
    end
  end

  test do
    assert_match "COMMANDS:", shell_output("#{bin}/wfcli --help")
    assert_match "Linux/Proton", shell_output("#{bin}/wfcompanion --help")
    assert_predicate bin/"wfgui", :executable?
    assert_predicate libexec/"libexec/wfdaemon/bin/wfdaemon", :executable?
  end
end
