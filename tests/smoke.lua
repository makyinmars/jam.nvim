local jam = require("jam")
local util = require("jam.util")

local values = jam.setup({
  providers = {
    spotify = {
      client_id = "test-client-id",
    },
  },
})

assert(values.provider == "spotify")
assert(values.providers.spotify.client_id == "test-client-id")
assert(util.urlencode("Daft Punk & friends") == "Daft%20Punk%20%26%20friends")
assert(util.base64url("jam") == "amFt")

local provider = require("jam.providers").get("spotify", values)
assert(provider.capabilities.search)
assert(provider.capabilities.playback_control)
assert(provider.capabilities.auth)
assert(provider.capabilities.now_playing)
assert(provider.capabilities.album_tracks)
assert(provider.capabilities.artist_top_tracks)
assert(provider.capabilities.show_episodes)
assert(provider.capabilities.artwork)

assert(vim.fn.exists(":Jam") == 2)
assert(vim.tbl_contains(jam.complete("p"), "play"))
assert(vim.tbl_contains(jam.complete("p"), "pause"))
assert(vim.tbl_contains(jam.complete("n"), "next"))
assert(vim.tbl_contains(jam.complete("n"), "now-playing"))
assert(require("telescope").extensions.jam ~= nil)

require("jam").setup({ provider = "youtube_music" })
local youtube = require("jam.providers").get("youtube_music", require("jam.config").values)
assert(youtube.display_name == "YouTube Music")
assert(youtube.capabilities.open)
assert(not youtube.capabilities.live_search)
assert(vim.tbl_contains(jam.complete("s"), "search"))
assert(not vim.tbl_contains(jam.complete("p"), "pause"))
assert(not vim.tbl_contains(jam.complete("a"), "auth"))
assert(not vim.tbl_contains(jam.complete("n"), "now-playing"))

local notification
util.notify = function(message)
  notification = message
end
jam.command("pause")
assert(notification:find("hands playback to the first-party app", 1, true))
jam.command("now-playing")
assert(notification:find("hands playback to the first-party app", 1, true))

print("jam.nvim smoke tests passed")
