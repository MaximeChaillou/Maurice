cask "maurice" do
  version "1.0.0-beta.9"
  sha256 "8a740c1dbbd550f3b746edc96b90f27f8df6612e5cc0329991512bec541ff349"

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
