local M = {}

local function decode_body(body)
  if body == "" then
    return nil
  end
  local ok, decoded = pcall(vim.json.decode, body)
  return ok and decoded or body
end

function M.request(opts, callback)
  vim.validate("opts", opts, "table")
  vim.validate("callback", callback, "function")

  if vim.fn.executable("curl") ~= 1 then
    callback("curl is required to access music provider APIs")
    return
  end

  local args = {
    "curl",
    "--silent",
    "--show-error",
    "--location",
    "--request",
    opts.method or "GET",
    "--write-out",
    "\n%{http_code}",
  }

  for key, value in pairs(opts.headers or {}) do
    vim.list_extend(args, { "--header", key .. ": " .. value })
  end
  if opts.body then
    vim.list_extend(args, { "--data", opts.body })
  end
  table.insert(args, opts.url)

  return vim.system(args, { text = true }, function(result)
    vim.schedule(function()
      if result.code ~= 0 then
        callback(vim.trim(result.stderr ~= "" and result.stderr or "HTTP request failed"))
        return
      end

      local body, status = result.stdout:match("^(.*)\n(%d%d%d)$")
      status = tonumber(status)
      if not status then
        callback("Provider returned an invalid HTTP response")
        return
      end

      local decoded = decode_body(body)
      if status < 200 or status >= 300 then
        local message = type(decoded) == "table"
            and (decoded.error_description or decoded.message or (decoded.error and decoded.error.message))
          or decoded
        callback(string.format("HTTP %d: %s", status, message or "request failed"), decoded, status)
        return
      end
      callback(nil, decoded, status)
    end)
  end)
end

function M.form(url, fields, callback)
  local util = require("jam.util")
  return M.request({
    method = "POST",
    url = url,
    headers = { ["Content-Type"] = "application/x-www-form-urlencoded" },
    body = util.query(fields),
  }, callback)
end

return M
