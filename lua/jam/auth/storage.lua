local M = {}

local function path(provider)
  return vim.fs.joinpath(vim.fn.stdpath("data"), "jam.nvim", provider .. ".json")
end

function M.load(provider)
  local file = path(provider)
  if not vim.uv.fs_stat(file) then
    return nil
  end
  local lines = vim.fn.readfile(file)
  if #lines == 0 then
    return nil
  end
  local ok, data = pcall(vim.json.decode, table.concat(lines, "\n"))
  return ok and data or nil
end

function M.save(provider, value)
  local file = path(provider)
  vim.fn.mkdir(vim.fs.dirname(file), "p")
  local ok, error_message = pcall(vim.fn.writefile, { vim.json.encode(value) }, file)
  if not ok then
    return false, error_message
  end
  vim.uv.fs_chmod(file, 384) -- 0600
  return true
end

function M.clear(provider)
  vim.fn.delete(path(provider))
end

return M
