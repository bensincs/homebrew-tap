cask "webshow" do
  version "0.3.0"
  sha256 "0019dfc4b32d63c1392aa264aed2253c1e0c2fb09216f8e2cc269bbfb8bb49b5"

  url "https://github.com/bensincs/webshow/releases/download/v#{version}/webshow-v#{version}-aarch64-apple-darwin.tar.gz"
  name "WebShow"
  desc "A minimal macOS app that opens a URL in a native webview window"
  homepage "https://github.com/bensincs/webshow"

  depends_on macos: ">= :ventura"
  depends_on arch: :arm64

  app "WebShow.app"

  postflight do
    system_command "/usr/bin/xattr",
                   args: ["-d", "com.apple.quarantine", "#{appdir}/WebShow.app"],
                   sudo: false
  end
end
