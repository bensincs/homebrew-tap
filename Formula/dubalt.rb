class Dubalt < Formula
  desc "Double-Option dictation with local speech and semantic Copilot cleanup"
  homepage "https://github.com/bensincs/dubalt"
  url "ssh://git@github.com/bensincs/dubalt.git",
      using:    :git,
      revision: "83f302dcdb66e3734293d2f5825b4f96ba610627"
  version "0.3.0-alpha.1"
  license "MIT"

  depends_on "cmake" => :build
  depends_on "python@3.14" => :build
  depends_on "rust" => :build
  depends_on xcode: :build
  depends_on arch: :arm64
  depends_on macos: :sonoma

  deny_network_access! :test

  def install
    ENV.prepend_path "PATH", Formula["rust"].opt_bin
    ENV["RUSTC"] = (Formula["rust"].opt_bin/"rustc").to_s
    rust_version = Utils.safe_popen_read("rustc", "--version").split[1]
    odie "DubAlt requires Homebrew Rust 1.99.1 or newer" if Version.new(rust_version) < Version.new("1.99.1")

    # Build-only caches; do not read the user's Cargo/Copilot auth or config.
    ENV["CARGO_HOME"] = (buildpath/"cargo-home").to_s
    ENV["CARGO_TARGET_DIR"] = (buildpath/"target").to_s
    ENV["BUNDLED_CLI_CACHE_DIR"] = (buildpath/"copilot-downloads").to_s
    ENV["MACOSX_DEPLOYMENT_TARGET"] = "14.0"
    ENV["CARGO_BUILD_JOBS"] = "2"
    ENV.delete "COPILOT_SKIP_CLI_DOWNLOAD"
    ENV.delete "DOCS_RS"

    notices = buildpath/"dubalt-notices.txt"
    system "cargo", "fetch", "--locked", "--target", "aarch64-apple-darwin"
    system python3, "scripts/license-inventory.py", notices
    odie "DubAlt license inventory was not generated" unless notices.file? && notices.size.positive?
    ENV["DUBALT_LICENSE_INVENTORY"] = notices.to_s

    # Preserve the source's Parakeet Metal and official bundled-in-process SDK features.
    system "cargo", "build", "--release", "--locked", "--bin", "dubalt", "--target", "aarch64-apple-darwin"
    runtime_archives = Dir["target/aarch64-apple-darwin/release/build/github-copilot-sdk-*/out/copilot_runtime.archive"]
    odie "Copilot runtime embedding was not produced" unless runtime_archives.any? { |path| File.size?(path) }

    bin.install "target/aarch64-apple-darwin/release/dubalt"
  end

  def caveats
    <<~EOS
      Source-test candidate: native Mac build/runtime and M1 performance are
      unverified. No binary/bottle or notarized release is available.

      The source repository is PRIVATE. Your existing GitHub SSH identity/agent
      must have access before Homebrew's non-interactive clone:
        git ls-remote ssh://git@github.com/bensincs/dubalt.git HEAD
      Full selected Xcode is required; Homebrew supplies the other build tools.
      Source builds download locked crates and pinned runtime archives and can
      take substantial time and disk space.

      Brew installs the executable only. Explicitly install/open the user app:
        dubalt install
        open "$HOME/Applications/DubAlt.app"
      Upgrading? Quit DubAlt/legacy Flowdict first, then use:
        dubalt install --replace
      The previous valid DubAlt bundle is retained. Old apps/state are not
      automatically deleted, merged, overwritten or chmodded.

      Prepare from the app menu: Download model / license (~483 MB),
      Sign in / reconnect Copilot, and Permissions (microphone, Accessibility,
      Input Monitoring). Normal Copilot entitlement/network access is required.
      No CLI login or configuration is needed. Wait for Ready.

      Tap Option and release; press the SAME Option again and hold while speaking;
      release to finish. Cancel with Control-Option-Escape or the menu.
      Audio stays local; the transcript goes to Copilot for semantic cleanup.
      One final result, no Enter or automatic Paste, and no raw fallback.
      There is no RAW/offline mode, model picker or clipboard backup/restore.
      Failed-insertion text can be copied manually or discarded in the app.
      Retired nondefault settings need explicit acknowledgement each launch;
      an old RAW choice never silently enables transcript uploads.

      Terminals/secure/unsupported fields are refused; app coverage, speech
      accuracy and latency still need Mac testing. Never disable macOS security
      protections. Inspect licenses with `dubalt notices`; signing/notarization
      and complete runtime/model/dependency clearance remain binary-release gates.
      Brew install/test does not launch the app, download speech models, request
      permissions, authenticate, open the mic or make a model call.
    EOS
  end

  test do
    ENV["HOME"] = testpath.to_s
    assert_match "dubalt #{version}", shell_output("#{bin}/dubalt --version")
    assert_match "doctor", shell_output("#{bin}/dubalt --help")
    report = JSON.parse(shell_output("#{bin}/dubalt doctor").lines.first)
    assert_equal "macos", report.fetch("os")
    assert_equal "aarch64", report.fetch("arch")
    assert_equal false, report.fetch("model_integrity")
    assert_equal "semantic / SDK default model only", report.fetch("mode")
    assert_equal false, report.fetch("settings_acknowledgement_required")
    assert_nil report.fetch("legacy_settings").fetch("copilot")
    assert_nil report.fetch("legacy_settings").fetch("clipboard_fallback")
    assert_nil report.fetch("legacy_settings").fetch("copilot_model")
    assert_equal "not checked; sign in from app", report.fetch("copilot_auth")
    refute_predicate testpath/"Library", :exist?
    assert_equal "off", report.fetch("history")
    refute_predicate testpath/"Applications/DubAlt.app", :exist?
  end
end
