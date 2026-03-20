cask "maurice" do
  version "1.0.0-beta.5"
  sha256 "b9a3aef78dfd186575e33b0281e34a92ae28b79ed87b55ad7c55d5ea621f4d65"

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
