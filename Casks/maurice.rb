cask "maurice" do
  version "1.0.0-beta.12"
  sha256 "f2d0a0d97c3574f9d9b6099525bfefdf0012f0be3579e46599a00129a90da77a"

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
