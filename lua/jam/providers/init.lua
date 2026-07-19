local M = {
  instances = {},
}

local contract = require("jam.providers.contract")

local registry = {
  spotify = {
    display_name = "Spotify",
    create = function(provider_config)
      local Auth = require("jam.auth.spotify")
      local Provider = require("jam.providers.spotify")
      return Provider.new(provider_config, Auth.new(provider_config))
    end,
  },
  youtube_music = {
    display_name = "YouTube Music",
    create = function(provider_config)
      return require("jam.providers.youtube_music").new(provider_config)
    end,
  },
}

function M.get(name, config)
  name = name or config.provider
  if M.instances[name] then
    return M.instances[name]
  end
  local definition = registry[name]
  if not definition then
    error("jam.nvim provider is not available: " .. name)
  end

  local provider_config = config.providers[name] or {}
  M.instances[name] =
    contract.apply(definition.create(provider_config), name, definition.display_name)
  return M.instances[name]
end

function M.supports(provider, capability)
  return contract.supports(provider, capability)
end

function M.reset()
  M.instances = {}
end

return M
