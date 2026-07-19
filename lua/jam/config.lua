local M = {}

M.defaults = {
  provider = "spotify",
  artwork = {
    enabled = true,
    backend = "auto",
    width = 38,
    height = 16,
    cache = true,
  },
  picker = {
    layout_strategy = "flex",
    layout_config = {
      width = 0.9,
      height = 0.8,
      horizontal = {
        preview_width = 0.45,
      },
      vertical = {
        preview_height = 0.45,
      },
    },
  },
  providers = {
    spotify = {
      client_id = nil,
      redirect_uri = "http://127.0.0.1:8765/callback",
      search = {
        debounce_ms = 250,
        limit = 30,
        mode = "live",
        types = { "track", "album", "artist", "playlist", "show", "episode" },
      },
      scopes = {
        "user-read-playback-state",
        "user-modify-playback-state",
        "user-library-read",
        "user-read-recently-played",
        "playlist-read-private",
      },
    },
    youtube_music = {
      api_key = vim.env.YOUTUBE_API_KEY,
      region_code = nil,
      relevance_language = nil,
      open_host = "music.youtube.com",
      fallback_host = "www.youtube.com",
      search = {
        debounce_ms = 0,
        limit = 20,
        mode = "submit",
        types = { "video" },
      },
    },
  },
}

M.values = vim.deepcopy(M.defaults)

function M.setup(opts)
  opts = opts or {}
  vim.validate("opts", opts, "table")
  M.values = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts)
  if opts.search then
    local provider = M.values.provider
    M.values.providers[provider].search =
      vim.tbl_deep_extend("force", M.values.providers[provider].search or {}, opts.search)
  end
  return M.values
end

return M
