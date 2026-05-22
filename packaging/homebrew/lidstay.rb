cask "lidstay" do
  version "1.0"
  sha256 :no_check

  url "file://#{File.expand_path("../../dist/LidStay.zip", __dir__)}"
  name "LidStay"
  desc "Menu bar app that keeps a Mac awake while allowing display sleep"
  homepage "https://github.com/ghkdqhrbals/LidStay"

  depends_on macos: ">= :ventura"

  app "LidStay.app"

  zap trash: [
    "~/Library/Preferences/com.ghkdqhrbals.LidStay.plist",
  ]
end
