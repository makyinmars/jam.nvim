local config = require("jam.config")
local artwork = require("jam.ui.artwork")
local providers = require("jam.providers")

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

  local ok, active = pcall(providers.get, config.values.provider, config.values)
  if ok and active.health then
    vim.health.start(active.display_name)
    active:health(vim.health)
  else
    vim.health.error(ok and (active.display_name .. " does not provide health checks") or active)
  end

  vim.health.start("Artwork")
  local backend, reason = artwork.detect(config.values.artwork)
  if backend == "text" or backend == "none" then
    vim.health.warn("Artwork backend: " .. backend .. " (" .. reason .. ")")
    if backend == "text" then
      vim.health.info(
        "Install chafa, or install image.nvim and use a compatible terminal, to display artwork"
      )
    end
  else
    vim.health.ok("Artwork backend: " .. backend .. " (" .. reason .. ")")
  end
end

return M
