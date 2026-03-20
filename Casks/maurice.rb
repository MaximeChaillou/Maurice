cask "maurice" do
  version "1.0.0-beta.6"
  sha256 "15061e6060b570c26000aa619e4eaa08fe2e7c7b69db8627a450ba54143ec862"

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
