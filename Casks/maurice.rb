cask "maurice" do
  version "1.0.3"
  sha256 "3e5c32a2bced5da568a7a2bf7d2a800628feffc13b12bcadde4de0ef2cfbb862"

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
