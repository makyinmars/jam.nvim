local http = require("jam.http")
local util = require("jam.util")

local YouTubeMusic = {}
YouTubeMusic.__index = YouTubeMusic

YouTubeMusic.capabilities = {
  search = true,
  open = true,
  live_search = false,
  auth = false,
  playback_control = false,
  queue = false,
  now_playing = false,
  playlists = false,
  album_tracks = false,
  artist_top_tracks = false,
  show_episodes = false,
  artwork = true,
}

YouTubeMusic.unsupported_messages = {
  playback_control = "YouTube Music hands playback to the first-party app and cannot control it",
  now_playing = "YouTube Music hands playback to the first-party app and cannot report now-playing status",
}

YouTubeMusic.open_targets = {
  { id = "music", label = "YouTube Music", host = "music.youtube.com" },
  { id = "video", label = "YouTube", host = "www.youtube.com" },
}

local API_URL = "https://www.googleapis.com/youtube/v3"

local function duration_ms(duration)
  if type(duration) ~= "string" or duration:sub(1, 1) ~= "P" then
    return nil
  end
  local days = tonumber(duration:match("([%d%.]+)D")) or 0
  local hours = tonumber(duration:match("([%d%.]+)H")) or 0
  local minutes = tonumber(duration:match("([%d%.]+)M")) or 0
  local seconds = tonumber(duration:match("([%d%.]+)S")) or 0
  return math.floor((days * 86400 + hours * 3600 + minutes * 60 + seconds) * 1000 + 0.5)
end

local function thumbnail_url(thumbnails)
  for _, size in ipairs({ "maxres", "standard", "high", "medium", "default" }) do
    if thumbnails and thumbnails[size] and thumbnails[size].url then
      return thumbnails[size].url
    end
  end
end

local function watch_url(host, id)
  return "https://" .. host .. "/watch?v=" .. util.urlencode(id)
end

local html_entities = {
  amp = "&",
  apos = "'",
  gt = ">",
  lt = "<",
  quot = '"',
}

local function decode_html(value)
  if type(value) ~= "string" then
    return value
  end
  return (
    value:gsub("&(#?[xX]?[%w]+);", function(entity)
      local replacement = html_entities[entity]
      if replacement then
        return replacement
      end

      local number
      if entity:sub(1, 2):lower() == "#x" then
        number = tonumber(entity:sub(3), 16)
      elseif entity:sub(1, 1) == "#" then
        number = tonumber(entity:sub(2), 10)
      end
      if number then
        local ok, character = pcall(vim.fn.nr2char, number)
        if ok and character ~= "" then
          return character
        end
      end
      return "&" .. entity .. ";"
    end)
  )
end

local function has_quota_reason(value)
  if type(value) ~= "table" then
    return false
  end
  for key, nested in pairs(value) do
    if key == "reason" and (nested == "quotaExceeded" or nested == "dailyLimitExceeded") then
      return true
    end
    if type(nested) == "table" and has_quota_reason(nested) then
      return true
    end
  end
  return false
end

function YouTubeMusic.new(config)
  config = config or {}
  return setmetatable({
    config = config,
    display_name = "YouTube Music",
    default_open_target = config.open_host == "www.youtube.com" and "video" or "music",
    query_cache = {},
    query_waiters = {},
    music_category_id = config.category_id,
    category_waiters = nil,
  }, YouTubeMusic)
end

function YouTubeMusic:health(health)
  if self.config.api_key and self.config.api_key ~= "" then
    health.ok("YouTube Data API key is configured")
  else
    health.warn("YouTube Data API key is not configured")
  end
  if self.config.category_id then
    health.ok("YouTube Music video category ID is configured")
  else
    health.info("YouTube's Music video category will be resolved and cached on first search")
  end
end

function YouTubeMusic:_request(path, params, callback)
  http.request({
    url = API_URL .. path .. "?" .. util.query(params),
    headers = { ["x-goog-api-key"] = self.config.api_key },
  }, function(err, response, status)
    if err and status == 403 and has_quota_reason(response) then
      callback(
        "YouTube search quota is exhausted for this API project; try again after its quota resets",
        response,
        status
      )
      return
    end
    callback(err, response, status)
  end)
end

function YouTubeMusic:_category(callback)
  if self.music_category_id then
    callback(nil, self.music_category_id)
    return
  end
  if self.category_waiters then
    table.insert(self.category_waiters, callback)
    return
  end

  self.category_waiters = { callback }
  self:_request("/videoCategories", {
    part = "snippet",
    regionCode = self.config.region_code,
  }, function(err, response)
    local category_id
    if not err then
      for _, category in ipairs((response or {}).items or {}) do
        if category.snippet and category.snippet.title == "Music" then
          category_id = category.id
          break
        end
      end
      if not category_id then
        err = "YouTube did not return a Music video category for the configured region"
      end
    end
    self.music_category_id = category_id
    local waiters = self.category_waiters
    self.category_waiters = nil
    for _, waiter in ipairs(waiters) do
      waiter(err, category_id)
    end
  end)
end

function YouTubeMusic:_normalize(search_item, video)
  local id = search_item.id.videoId
  local snippet = search_item.snippet or {}
  local content = video.contentDetails or {}
  local external_url = watch_url(self.config.open_host or "music.youtube.com", id)
  return {
    id = id,
    kind = "video",
    service_kind = "youtube_video",
    uri = external_url,
    external_url = external_url,
    name = decode_html(snippet.title),
    subtitle = decode_html(snippet.channelTitle),
    description = decode_html(snippet.description),
    image_url = thumbnail_url(snippet.thumbnails),
    release_date = snippet.publishedAt,
    duration_ms = duration_ms(content.duration),
    licensed_content = content.licensedContent,
    region_restriction = content.regionRestriction,
    embeddable = video.status and video.status.embeddable,
    raw = { search = search_item, video = video },
  }
end

function YouTubeMusic:search(query, options, callback)
  query = query and vim.trim(query) or ""
  if query == "" then
    callback(nil, {})
    return
  end
  if not self.config.api_key or self.config.api_key == "" then
    callback("Set providers.youtube_music.api_key before searching YouTube")
    return
  end
  if self.query_cache[query] then
    callback(nil, self.query_cache[query])
    return
  end
  if self.query_waiters[query] then
    table.insert(self.query_waiters[query], callback)
    return
  end

  self.query_waiters[query] = { callback }
  local function finish(err, results)
    if not err then
      self.query_cache[query] = results
    end
    local waiters = self.query_waiters[query]
    self.query_waiters[query] = nil
    for _, waiter in ipairs(waiters) do
      waiter(err, results)
    end
  end

  options = options or {}
  self:_category(function(category_err, category_id)
    if category_err then
      finish(category_err)
      return
    end
    self:_request("/search", {
      part = "snippet",
      type = "video",
      videoCategoryId = category_id,
      q = query,
      maxResults = math.max(1, math.min(50, tonumber(options.limit) or 20)),
      regionCode = self.config.region_code,
      relevanceLanguage = self.config.relevance_language,
    }, function(search_err, response)
      if search_err then
        finish(search_err)
        return
      end
      local search_items = (response or {}).items or {}
      local ids = {}
      for _, item in ipairs(search_items) do
        if item.id and item.id.videoId then
          table.insert(ids, item.id.videoId)
        end
      end
      if #ids == 0 then
        finish(nil, {})
        return
      end

      self:_request("/videos", {
        part = "contentDetails,status",
        id = table.concat(ids, ","),
      }, function(video_err, videos_response)
        if video_err then
          finish(video_err)
          return
        end
        local videos = {}
        for _, video in ipairs((videos_response or {}).items or {}) do
          videos[video.id] = video
        end
        local results = {}
        for _, item in ipairs(search_items) do
          local id = item.id and item.id.videoId
          if id and videos[id] then
            table.insert(results, self:_normalize(item, videos[id]))
          end
        end
        finish(nil, results)
      end)
    end)
  end)
end

function YouTubeMusic:open(item, callback)
  if not item or not item.id then
    callback("A YouTube video ID is required")
    return
  end
  local selected_host
  for _, target in ipairs(self.open_targets) do
    if target.id == item.open_target then
      selected_host = target.host
      break
    end
  end
  local primary_url = selected_host and watch_url(selected_host, item.id)
    or item.external_url
    or watch_url(self.config.open_host or "music.youtube.com", item.id)
  local opened, open_err = util.open_url(primary_url)
  if opened then
    local destination = primary_url:find("music.youtube.com", 1, true) and "in YouTube Music"
      or "on YouTube"
    callback(nil, "Opened " .. (item.name or "video") .. " " .. destination)
    return
  end

  local fallback_host = self.config.fallback_host or "www.youtube.com"
  local fallback_url = watch_url(fallback_host, item.id)
  if fallback_url ~= primary_url then
    local fallback_opened, fallback_err = util.open_url(fallback_url)
    if fallback_opened then
      callback(nil, "Opened " .. (item.name or "video") .. " on YouTube")
      return
    end
    open_err = fallback_err
  end
  callback("Could not open YouTube: " .. tostring(open_err))
end

return YouTubeMusic
