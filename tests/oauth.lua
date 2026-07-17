local util = require("jam.util")
local http = require("jam.http")
local storage = require("jam.auth.storage")

local function available_port()
  local probe = vim.uv.new_tcp()
  assert(probe:bind("127.0.0.1", 0))
  local port = assert(probe:getsockname()).port
  probe:close()
  return port
end

storage.load = function()
  return nil
end
storage.save = function()
  return true
end
util.open_url = function()
  return true
end
http.form = function()
  error("token exchange must not run for a rejected callback")
end

local port = available_port()
local finished = false
local callback_error
local auth = require("jam.auth.spotify").new({
  client_id = "test-client-id",
  redirect_uri = string.format("http://127.0.0.1:%d/callback", port),
  scopes = {},
})

auth:login(function(err)
  callback_error = err
  finished = true
end)

vim.defer_fn(function()
  vim.system({
    "curl",
    "--fail",
    "--silent",
    string.format("http://127.0.0.1:%d/callback?state=invalid", port),
  })
end, 50)

assert(
  vim.wait(3000, function()
    return finished
  end),
  "OAuth callback server timed out"
)
assert(callback_error:find("invalid OAuth callback", 1, true))

port = available_port()
finished = false
callback_error = nil
local state
local exchanged = false
util.open_url = function(url)
  state = assert(url:match("[?&]state=([^&]+)"))
  return true
end
http.form = function(_, fields, callback)
  assert(fields.code == "test-code")
  assert(fields.code_verifier and fields.code_verifier ~= "")
  exchanged = true
  callback(nil, {
    access_token = "test-access-token",
    refresh_token = "test-refresh-token",
    expires_in = 3600,
  })
end

auth = require("jam.auth.spotify").new({
  client_id = "test-client-id",
  redirect_uri = string.format("http://127.0.0.1:%d/callback", port),
  scopes = {},
})
auth:login(function(err)
  callback_error = err
  finished = true
end)

vim.defer_fn(function()
  assert(state)
  vim.system({
    "curl",
    "--fail",
    "--silent",
    string.format("http://127.0.0.1:%d/callback?code=test-code&state=%s", port, state),
  })
end, 50)

assert(
  vim.wait(3000, function()
    return finished
  end),
  "valid OAuth callback server timed out"
)
assert(not callback_error, callback_error)
assert(exchanged, "valid OAuth callback did not exchange its code")

print("jam.nvim OAuth callback test passed")
