local config = require("jam.config")
local artwork = require("jam.ui.artwork")

local M = {}

function M.check()
  vim.health.start("jam.nvim")

  if vim.fn.has("nvim-0.10") == 1 then
    vim.health.ok("Neovim 0.10 or newer")
  else
    vim.health.error("Neovim 0.10 or newer is required")
  end

  if pcall(require, "telescope") then
    vim.health.ok("telescope.nvim is available")
  else
    vim.health.error("telescope.nvim is required")
  end

  if vim.fn.executable("curl") == 1 then
    vim.health.ok("curl is executable")
  else
    vim.health.error("curl is required for provider API requests")
  end

  if vim.fn.executable("openssl") == 1 then
    vim.health.ok("openssl is executable")
  else
    vim.health.error("openssl is required for Spotify PKCE authentication")
  end

  local spotify = config.values.providers.spotify
  if spotify.client_id and spotify.client_id ~= "" then
    vim.health.ok("Spotify client ID is configured")
  else
    vim.health.warn("Spotify client ID is not configured")
  end

  local backend, reason = artwork.detect(config.values.artwork)
  if backend == "text" or backend == "none" then
    vim.health.warn("Artwork backend: " .. backend .. " (" .. reason .. ")")
  else
    vim.health.ok("Artwork backend: " .. backend .. " (" .. reason .. ")")
  end
end

return M
