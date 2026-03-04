cask "webshow" do
  version "0.3.0"
  sha256 "4b08ac3e61820efa0574fe62a2bde2951fdf82bb0b807cc33dbb776d771285b4"

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
