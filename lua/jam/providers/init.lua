local M = {
  instances = {},
}

function M.get(name, config)
  name = name or config.provider
  if M.instances[name] then
    return M.instances[name]
  end
  if name ~= "spotify" then
    error("jam.nvim provider is not available: " .. name)
  end

  local provider_config = config.providers[name]
  local Auth = require("jam.auth.spotify")
  local Provider = require("jam.providers.spotify")
  local auth = Auth.new(provider_config)
  M.instances[name] = Provider.new(provider_config, auth)
  return M.instances[name]
end

function M.reset()
  M.instances = {}
end

return M
