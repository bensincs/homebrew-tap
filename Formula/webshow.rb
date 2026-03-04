class Webshow < Formula
  desc "A minimal macOS app that opens a URL in a native webview window"
  homepage "https://github.com/bensincs/webshow"
  version "0.2.0"
  license "MIT"

  on_macos do
    on_arm do
      url "https://github.com/bensincs/webshow/releases/download/v0.2.0/webshow-v0.2.0-aarch64-apple-darwin.tar.gz"
      sha256 "afac4263c63a64e31207a4c0acb3f62db55940db22977f0772fccffc80616171"
    end
  end

  def install
    bin.install "webshow"
  end

  test do
    assert_match "webshow", shell_output("#{bin}/webshow --help")
  end
end
