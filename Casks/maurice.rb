cask "maurice" do
  version "1.0.0-beta.17"
  sha256 "adfd623ae200e7e76cfde1c0f90ae352c7e8d051aec4fc968df6e6202b56e59c"

  url "https://github.com/MaximeChaillou/Maurice/releases/download/v#{version}/Maurice-#{version}.zip"
  name "Maurice"
  desc "Application macOS de transcription audio avec édition Markdown"
  homepage "https://github.com/MaximeChaillou/Maurice"

  app "Maurice.app"

  zap trash: [
    "~/Library/Preferences/com.maxime.maurice.plist",
    "~/Documents/Maurice",
  ]
end
