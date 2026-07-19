local http = require("jam.http")
local util = require("jam.util")
local YouTubeMusic = require("jam.providers.youtube_music")

local requests = {}
http.request = function(opts, callback)
  table.insert(requests, opts)
  if #requests == 1 then
    callback(nil, {
      items = {
        { id = "10", snippet = { title = "Music" } },
        { id = "20", snippet = { title = "Gaming" } },
      },
    })
  elseif #requests == 2 then
    callback(nil, {
      items = {
        {
          id = { videoId = "video-one" },
          snippet = {
            title = "Test Video",
            description = "A test music video",
            channelTitle = "Test Channel",
            publishedAt = "2026-07-18T12:34:56Z",
            thumbnails = {
              default = { url = "https://example.com/default.jpg" },
              high = { url = "https://example.com/high.jpg" },
            },
          },
        },
      },
    })
  else
    callback(nil, {
      items = {
        {
          id = "video-one",
          contentDetails = {
            duration = "PT1H2M3S",
            licensedContent = true,
            regionRestriction = { blocked = { "ZZ" } },
          },
          status = { embeddable = false },
        },
      },
    })
  end
end

local provider = YouTubeMusic.new({
  api_key = "test-api-key",
  region_code = "US",
  relevance_language = "en",
  open_host = "music.youtube.com",
  search = { limit = 20, mode = "submit" },
})

assert(provider.display_name == "YouTube Music")
assert(provider.capabilities.search)
assert(provider.capabilities.open)
assert(not provider.capabilities.live_search)
assert(not provider.capabilities.auth)
assert(not provider.capabilities.playback_control)
assert(not provider.capabilities.queue)
assert(not provider.capabilities.now_playing)
assert(not provider.capabilities.playlists)
assert(provider.capabilities.artwork)

local search_error
local results
provider:search("test query", provider.config.search, function(err, items)
  search_error = err
  results = items
end)

assert(not search_error, search_error)
assert(#requests == 3)
for _, request in ipairs(requests) do
  assert(request.headers["x-goog-api-key"] == "test-api-key")
  assert(not request.url:find("test-api-key", 1, true))
end
assert(requests[1].url:find("/videoCategories?", 1, true))
assert(requests[1].url:find("regionCode=US", 1, true))
assert(requests[2].url:find("/search?", 1, true))
assert(requests[2].url:find("type=video", 1, true))
assert(requests[2].url:find("videoCategoryId=10", 1, true))
assert(requests[2].url:find("q=test%20query", 1, true))
assert(requests[2].url:find("relevanceLanguage=en", 1, true))
assert(requests[3].url:find("/videos?", 1, true))
assert(requests[3].url:find("id=video%-one"))

assert(#results == 1)
local result = results[1]
assert(result.id == "video-one")
assert(result.kind == "video")
assert(result.service_kind == "youtube_video")
assert(result.name == "Test Video")
assert(result.subtitle == "Test Channel")
assert(result.duration_ms == 3723000)
assert(result.release_date == "2026-07-18T12:34:56Z")
assert(result.image_url == "https://example.com/high.jpg")
assert(result.uri == "https://music.youtube.com/watch?v=video-one")
assert(result.external_url == result.uri)
assert(result.raw.search.id.videoId == "video-one")
assert(result.raw.video.status.embeddable == false)

local cached_results
provider:search("test query", provider.config.search, function(err, items)
  search_error = err
  cached_results = items
end)
assert(not search_error, search_error)
assert(#requests == 3, "an exact cached query made another API request")
assert(cached_results[1].id == "video-one")

local category_cache_requests = 0
http.request = function(opts, callback)
  category_cache_requests = category_cache_requests + 1
  assert(not opts.url:find("/videoCategories?", 1, true), "resolved Music category was not cached")
  if opts.url:find("/search?", 1, true) then
    callback(nil, {
      items = {
        {
          id = { videoId = "video-two" },
          snippet = { title = "Second Video", channelTitle = "Test Channel" },
        },
      },
    })
  else
    callback(nil, {
      items = {
        {
          id = "video-two",
          contentDetails = { duration = "PT2M" },
          status = { embeddable = true },
        },
      },
    })
  end
end
provider:search("different query", provider.config.search, function(err)
  search_error = err
end)
assert(not search_error, search_error)
assert(category_cache_requests == 2)

local opened_urls = {}
util.open_url = function(url)
  table.insert(opened_urls, url)
  if #opened_urls == 1 then
    return false, "no URL handler"
  end
  return true
end
local open_error
local open_message
provider:open(result, function(err, message)
  open_error = err
  open_message = message
end)
assert(not open_error, open_error)
assert(opened_urls[1] == "https://music.youtube.com/watch?v=video-one")
assert(opened_urls[2] == "https://www.youtube.com/watch?v=video-one")
assert(open_message == "Opened Test Video on YouTube")

opened_urls = {}
local youtube_provider = YouTubeMusic.new({
  api_key = "key",
  category_id = "10",
  open_host = "www.youtube.com",
  search = {},
})
util.open_url = function(url)
  table.insert(opened_urls, url)
  return true
end
youtube_provider:open({ id = result.id, name = result.name }, function(err, message)
  open_error = err
  open_message = message
end)
assert(not open_error, open_error)
assert(open_message == "Opened Test Video on YouTube")

util.open_url = function()
  return false, "no browser available"
end
youtube_provider:open({ id = result.id, name = result.name }, function(err)
  open_error = err
end)
assert(open_error:find("Could not open YouTube", 1, true))

local pending_requests = {}
http.request = function(opts, callback)
  table.insert(pending_requests, { opts = opts, callback = callback })
end
local coalesced_provider = YouTubeMusic.new({
  api_key = "key",
  category_id = "10",
  search = {},
})
local coalesced_callbacks = 0
for _ = 1, 2 do
  coalesced_provider:search("same in-flight query", {}, function(err, items)
    assert(not err, err)
    assert(items[1].id == "coalesced-video")
    coalesced_callbacks = coalesced_callbacks + 1
  end)
end
assert(#pending_requests == 1, "identical in-flight query made duplicate search requests")
pending_requests[1].callback(nil, {
  items = {
    {
      id = { videoId = "coalesced-video" },
      snippet = { title = "Coalesced Video", channelTitle = "Test Channel" },
    },
  },
})
assert(#pending_requests == 2)
pending_requests[2].callback(nil, {
  items = {
    {
      id = "coalesced-video",
      contentDetails = { duration = "PT1M" },
      status = { embeddable = true },
    },
  },
})
assert(coalesced_callbacks == 2)

local missing_key_error
YouTubeMusic.new({ search = {} }):search("query", {}, function(err)
  missing_key_error = err
end)
assert(missing_key_error:find("providers.youtube_music.api_key", 1, true))

http.request = function(_, callback)
  callback("HTTP 403: quota exceeded", {
    error = { errors = { { reason = "quotaExceeded" } } },
  }, 403)
end
local quota_error
YouTubeMusic.new({ api_key = "key", category_id = "10", search = {} })
  :search("query", {}, function(err)
    quota_error = err
  end)
assert(quota_error:find("YouTube search quota is exhausted", 1, true))

print("jam.nvim YouTube Music provider tests passed")
