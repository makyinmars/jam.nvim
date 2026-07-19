local M = {}

M.capabilities = {
  "search",
  "open",
  "live_search",
  "auth",
  "playback_control",
  "queue",
  "now_playing",
  "playlists",
  "album_tracks",
  "artist_top_tracks",
  "show_episodes",
  "artwork",
}

function M.apply(provider, name, display_name)
  provider.name = provider.name or name
  provider.display_name = provider.display_name or display_name or name
  provider.capabilities = vim.tbl_extend("force", {}, provider.capabilities or {})
  for _, capability in ipairs(M.capabilities) do
    if provider.capabilities[capability] == nil then
      provider.capabilities[capability] = false
    end
  end
  return provider
end

function M.supports(provider, capability)
  return provider.capabilities and provider.capabilities[capability] == true
end

return M
