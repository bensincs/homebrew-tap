class Webshow < Formula
  desc "A minimal macOS app that opens a URL in a native webview window"
  homepage "https://github.com/bensincs/webshow"
  version "0.1.0"
  license "MIT"

  on_macos do
    on_arm do
      url "https://github.com/bensincs/webshow/releases/download/v0.1.0/webshow-v0.1.0-aarch64-apple-darwin.tar.gz"
      sha256 "75e385ddf52706191cf2b7b33d64fc5ac9909926593fca191a228a5e9205c50e"
    end
  end

  def install
    bin.install "webshow"
  end

  test do
    assert_match "webshow", shell_output("#{bin}/webshow --help")
  end
end
