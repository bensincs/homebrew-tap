class Dubalt < Formula
  desc "Double-Option hold dictation with local speech and semantic Copilot cleanup"
  homepage "https://github.com/bensincs/dubalt"
  url "ssh://git@github.com/bensincs/dubalt.git",
      using:    :git,
      revision: "dacf815d35976bd52bdf6cd7ab8260e80320947c"
  version "0.2.2"
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
      DubAlt builds from a pinned PRIVATE Git repository, not a release/bottle.
      Before fetching, your normal GitHub SSH identity/agent must have access to
      bensincs/dubalt. Homebrew Git downloads are non-interactive; the app's
      other checkout's repo-local HTTPS credential helper is not inherited.
      No token-bearing URL/header or copied auth state is needed. Check access:
        git ls-remote ssh://git@github.com/bensincs/dubalt.git HEAD

      The first source build downloads locked crates and the SDK's pinned public
      native runtime archives. Allow substantial time, RAM and disk; no build
      duration has been measured. Rust >= 1.99.1, full Xcode, Python 3.14 and
      CMake are build-time prerequisites, not installed app helpers.

      Brew installs only the executable. It never installs/launches the user app,
      accepts model terms, downloads speech models, opens the mic, requests TCC,
      logs into Copilot, calls AI or registers a startup service. Explicitly run:
        dubalt install
        open "$HOME/Applications/DubAlt.app"
      Then use the DubAlt menu for model-license acceptance/setup and explicit
      microphone + Accessibility + Input Monitoring permissions. Tap either
      Option once and release (<= 200 ms); press the SAME Option again within
      350 ms and HOLD while speaking. Release the second press to finish.
      Cancel/dismiss is Control-Option-Escape or the menu. This is NOT a toggle.
      The non-activating overlay shows recording, processing and errors.
      Copilot semantic cleanup is ON by default. Recording requires primed local
      speech plus an authenticated, prepared cleanup session. Unavailable setup/
      auth/session/rearm stays unavailable; RAW is usable only by explicit choice.
      One final request per utterance; network/model latency is
      nonzero. Auth/network/timeout/invalid output inserts NOTHING, never raw.
      `dubalt config --copilot false` explicitly selects raw mode.

      Homebrew rename metadata maps the old flowdict formula name to dubalt;
      the executable/app are now dubalt/DubAlt. Quit the legacy app first.
      Existing own-app Flowdict model/settings/auth roots are reused in place
      when the DubAlt root is absent, never merged/copied/deleted. Existing
      explicit raw-mode settings are preserved. If both roots exist, startup
      refuses to choose. Insecure ownership/permissions, symlinks and unsafe
      config/auth/runtime directories are refused without chmod or state merging.
      Nonempty COPILOT_CLI_PATH and ambient token routing are rejected before SDK
      startup; use normal own-app device login, not an inherited runtime override.
      New bundle identity requires new macOS TCC grants.

      Version 0.2.2 is a hardened SOURCE TEST SNAPSHOT, not native production proof.
      The original paired-Option/DA icon and About/version/notices are embedded.
      Quit before `dubalt install --replace`; unrelated destinations and existing
      backups are refused. Valid prior own-app bundles are retained on replacement.

      Experimental and native-unverified: packaging is not full tool readiness.
      Declared Apple Silicon macOS 14+ minimum, embedded runtime startup/session/
      shutdown, microphone/TCC, actual inference and M1 latency remain UNTESTED.
      Insertion is AX-only into supported captured editable fields. Terminals
      and secure/password fields are refused; incomplete AX support fails closed.
      Clipboard recovery is manual and opt-in, not automatic Paste/Enter.
      Browser/Electron/custom-field coverage is not guaranteed.

      The explicit app installer uses ad-hoc signing, not Developer ID or
      notarization. Never disable Gatekeeper or SIP. Inspect embedded dependency
      notices with `dubalt notices`; runtime/model terms are separate from the
      app's MIT license and complete license clearance remains a review gate.
      No native binary, bottle or GitHub release has been published.
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
    assert_equal true, report.fetch("config").fetch("copilot")
    assert_equal false, report.fetch("config").fetch("clipboard_fallback")
    assert_equal "not checked; use copilot-smoke", report.fetch("copilot_auth")
    refute_predicate testpath/"Library", :exist?
    assert_equal "off", report.fetch("history")
    refute_predicate testpath/"Applications/DubAlt.app", :exist?
  end
end
