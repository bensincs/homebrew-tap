cask "webshow" do
  version "0.2.0"
  sha256 "afac4263c63a64e31207a4c0acb3f62db55940db22977f0772fccffc80616171"

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
