class Flowdict < Formula
  desc "Local English push-to-talk dictation for Apple Silicon"
  homepage "https://github.com/bensincs/flowdict"
  url "ssh://git@github.com/bensincs/flowdict.git",
      using:    :git,
      revision: "bb83829b6ae62548a42cac4881300c71cda377db"
  version "0.1.0"
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
    odie "Flowdict requires Homebrew Rust 1.99.1 or newer" if Version.new(rust_version) < Version.new("1.99.1")

    # Build-only caches; do not read the user's Cargo/Copilot auth or config.
    ENV["CARGO_HOME"] = (buildpath/"cargo-home").to_s
    ENV["CARGO_TARGET_DIR"] = (buildpath/"target").to_s
    ENV["BUNDLED_CLI_CACHE_DIR"] = (buildpath/"copilot-downloads").to_s
    ENV["MACOSX_DEPLOYMENT_TARGET"] = "14.0"
    ENV["CARGO_BUILD_JOBS"] = "2"
    ENV.delete "COPILOT_SKIP_CLI_DOWNLOAD"
    ENV.delete "DOCS_RS"

    notices = buildpath/"flowdict-notices.txt"
    system "cargo", "fetch", "--locked", "--target", "aarch64-apple-darwin"
    system python3, "scripts/license-inventory.py", notices
    odie "Flowdict license inventory was not generated" unless notices.file? && notices.size.positive?
    ENV["FLOWDICT_LICENSE_INVENTORY"] = notices.to_s

    # Preserve the source's Parakeet Metal and official bundled-in-process SDK features.
    system "cargo", "build", "--release", "--locked", "--bin", "flowdict", "--target", "aarch64-apple-darwin"
    runtime_archives = Dir["target/aarch64-apple-darwin/release/build/github-copilot-sdk-*/out/copilot_runtime.archive"]
    odie "Copilot runtime embedding was not produced" unless runtime_archives.any? { |path| File.size?(path) }

    bin.install "target/aarch64-apple-darwin/release/flowdict"
  end

  def caveats
    <<~EOS
      Flowdict builds from a pinned PRIVATE Git repository, not a release/bottle.
      Before fetching, your normal GitHub SSH identity/agent must have access to
      bensincs/flowdict. Homebrew Git downloads are non-interactive; the app's
      other checkout's repo-local HTTPS credential helper is not inherited.
      No token-bearing URL/header or copied auth state is needed. Check access:
        git ls-remote ssh://git@github.com/bensincs/flowdict.git HEAD

      The first source build downloads locked crates and the SDK's pinned public
      native runtime archives. Allow substantial time, RAM and disk; no build
      duration has been measured. Rust >= 1.99.1, full Xcode, Python 3.14 and
      CMake are build-time prerequisites, not installed app helpers.

      Brew installs only the executable. It never installs/launches the user app,
      accepts model terms, downloads speech models, opens the mic, requests TCC,
      logs into Copilot, calls AI or registers a startup service. Explicitly run:
        flowdict install
        open "$HOME/Applications/Flowdict.app"
      Then use the Flowdict menu for model-license acceptance/setup and explicit
      microphone + Accessibility permissions. Default push-to-talk is
      Control-Option-Space; cancel is Control-Option-Escape. Copilot is optional
      and OFF until explicitly configured/authenticated by the user.

      Experimental and native-unverified: packaging is not full tool readiness.
      Declared Apple Silicon macOS 14+ minimum, embedded runtime startup/session/
      shutdown, microphone/TCC, actual inference and M1 latency remain UNTESTED.
      Insertion is AX-only into supported captured editable fields. Terminals
      and secure/password fields are refused; incomplete AX support fails closed.
      Clipboard recovery is manual and opt-in, not automatic Paste/Enter.
      Browser/Electron/custom-field coverage is not guaranteed.

      The explicit app installer uses ad-hoc signing, not Developer ID or
      notarization. Never disable Gatekeeper or SIP. Inspect embedded dependency
      notices with `flowdict notices`; runtime/model terms are separate from the
      app's MIT license and complete license clearance remains a review gate.
      No native binary, bottle or GitHub release has been published.
    EOS
  end

  test do
    ENV["HOME"] = testpath.to_s
    assert_match "flowdict #{version}", shell_output("#{bin}/flowdict --version")
    assert_match "doctor", shell_output("#{bin}/flowdict --help")
    report = JSON.parse(shell_output("#{bin}/flowdict doctor").lines.first)
    assert_equal "macos", report.fetch("os")
    assert_equal "aarch64", report.fetch("arch")
    assert_equal false, report.fetch("model_integrity")
    assert_equal false, report.fetch("config").fetch("copilot")
    assert_equal "off", report.fetch("history")
    refute_predicate testpath/"Applications/Flowdict.app", :exist?
  end
end
