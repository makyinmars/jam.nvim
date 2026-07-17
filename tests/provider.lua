local http = require("jam.http")
local Spotify = require("jam.providers.spotify")
local util = require("jam.util")

local requests = {}
http.request = function(opts, callback)
  table.insert(requests, opts)
  if #requests == 1 then
    callback(nil, {
      items = {
        {
          id = "track-one",
          uri = "spotify:track:one",
          name = "First Track",
          artists = { { name = "Test Artist" } },
          duration_ms = 61000,
          disc_number = 1,
          track_number = 1,
        },
      },
      next = "https://api.spotify.com/v1/albums/test-album/tracks?limit=50&offset=50",
    })
  else
    callback(nil, {
      items = {
        {
          id = "track-two",
          uri = "spotify:track:two",
          name = "Second Track",
          artists = { { name = "Test Artist" } },
          duration_ms = 122000,
          disc_number = 2,
          track_number = 1,
        },
      },
      next = vim.NIL,
    })
  end
end

local auth = {
  get_access_token = function(_, callback)
    callback(nil, "test-token")
  end,
}
local provider = Spotify.new({}, auth)
local callback_error
local album_tracks
provider:album_tracks({
  id = "test-album",
  name = "Test Album",
  image_url = "https://example.com/artwork.jpg",
}, function(err, tracks)
  callback_error = err
  album_tracks = tracks
end)

assert(not callback_error, callback_error)
assert(#requests == 2)
assert(requests[1].url:find("/albums/test%-album/tracks%?limit=50"))
assert(requests[2].url:find("offset=50", 1, true))
assert(requests[1].headers.Authorization == "Bearer test-token")
assert(#album_tracks == 2)
assert(album_tracks[1].kind == "track")
assert(album_tracks[1].album == "Test Album")
assert(album_tracks[1].image_url == "https://example.com/artwork.jpg")
assert(album_tracks[1].track_number == 1)
assert(album_tracks[2].disc_number == 2)

local artist_request
http.request = function(opts, callback)
  artist_request = opts
  callback(nil, {
    tracks = {
      {
        id = "top-track",
        uri = "spotify:track:top",
        name = "Top Track",
        artists = { { name = "Test Artist" } },
        album = {
          name = "Popular Album",
          images = { { url = "https://example.com/top-track.jpg" } },
        },
        duration_ms = 180000,
      },
    },
  })
end

local top_tracks
provider:artist_top_tracks({
  id = "test-artist",
  name = "Test Artist",
}, function(err, tracks)
  callback_error = err
  top_tracks = tracks
end)

assert(not callback_error, callback_error)
assert(artist_request.url:find("/artists/test%-artist/top%-tracks"))
assert(#top_tracks == 1)
assert(top_tracks[1].name == "Top Track")
assert(top_tracks[1].album == "Popular Album")
assert(top_tracks[1].list_position == 1)

for _, filter in ipairs({
  { query = "a: Test Album", expected_type = "album" },
  { query = "t: Test Artist", expected_type = "artist" },
  { query = "s: Test Song", expected_type = "track" },
}) do
  local search_request
  http.request = function(opts, callback)
    search_request = opts
    callback(nil, {})
  end
  provider:search(filter.query, {}, function(err)
    callback_error = err
  end)
  assert(not callback_error, callback_error)
  assert(search_request.url:find("type=" .. filter.expected_type, 1, true))
  assert(search_request.url:find("q=" .. util.urlencode(filter.query:sub(4)), 1, true))
end

local opened_uri
http.request = function(_, callback)
  callback("HTTP 404: Device not found")
end
util.open_url = function(uri)
  opened_uri = uri
  return true
end

local playback_error
local playback_message
provider:play({
  kind = "track",
  uri = "spotify:track:test-track",
}, function(err, message)
  playback_error = err
  playback_message = message
end)

assert(not playback_error, playback_error)
assert(opened_uri == "spotify:track:test-track")
assert(playback_message:find("Opened Spotify", 1, true))

print("jam.nvim provider tests passed")
