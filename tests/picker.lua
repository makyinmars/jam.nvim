vim.o.columns = 160
vim.o.lines = 50

local config = require("jam.config").setup({
  artwork = { enabled = false },
})

local search_requests = 0
local provider = {
  display_name = "Spotify",
  capabilities = {
    search = true,
    live_search = true,
    playback_control = true,
    queue = true,
    artwork = true,
  },
  search = function(_, query, _, callback)
    search_requests = search_requests + 1
    local delay = query == "slow" and 400 or query == "fast" and 700 or 20
    vim.defer_fn(function()
      callback(nil, {
        {
          id = "track-one",
          uri = "spotify:track:one",
          kind = "track",
          name = query .. " result one",
          subtitle = "Test Artist",
          description = "A   test\npodcast " .. string.rep("with a long description ", 20),
        },
        {
          id = "track-two",
          uri = "spotify:track:two",
          kind = "track",
          name = query .. " result two",
          subtitle = "Test Artist",
        },
      })
    end, delay)
  end,
}

require("jam.ui.picker").open(provider, config, { default_text = "swim bts" })

local prompt_buffer
assert(
  vim.wait(1000, function()
    for _, buffer in ipairs(vim.api.nvim_list_bufs()) do
      if vim.bo[buffer].filetype == "TelescopePrompt" then
        prompt_buffer = buffer
        return true
      end
    end
    return false
  end),
  "Telescope prompt did not open"
)

local action_state = require("telescope.actions.state")
local picker = action_state.get_current_picker(prompt_buffer)
assert(
  vim.wait(1000, function()
    return type(picker.manager) == "table" and picker.manager:num_results() == 2
  end),
  "search results did not populate"
)

local function visible_results()
  local lines = vim.api.nvim_buf_get_lines(picker.results_bufnr, 0, -1, false)
  return vim.tbl_filter(function(line)
    return line ~= ""
  end, lines)
end

assert(#visible_results() == 2, "search result buffer was blank before resize")
picker:set_selection(picker:get_row(1))
assert(
  vim.wait(1000, function()
    for _, buffer in ipairs(vim.api.nvim_list_bufs()) do
      if
        buffer ~= picker.results_bufnr
        and buffer ~= prompt_buffer
        and vim.api.nvim_buf_is_valid(buffer)
      then
        local preview = table.concat(vim.api.nvim_buf_get_lines(buffer, 0, -1, false), "\n")
        if preview:find("A test podcast", 1, true) and preview:find("…", 1, true) then
          return true
        end
      end
    end
    return false
  end),
  "preview description metadata did not render"
)
vim.o.columns = math.max(80, vim.o.columns - 20)
vim.o.lines = math.max(24, vim.o.lines - 5)
vim.cmd("doautocmd VimResized")
assert(
  vim.wait(1000, function()
    return #visible_results() == 2
  end),
  "search result buffer was blank after resize"
)
vim.wait(500, function()
  return false
end)
assert(search_requests == 1, "resizing triggered another provider search")

picker:set_prompt("slow")
assert(
  vim.wait(1000, function()
    return search_requests == 2
  end),
  "slow search did not start"
)
picker:set_prompt("fast")
assert(
  vim.wait(1000, function()
    return search_requests == 3
  end),
  "fast search did not start"
)
assert(
  vim.wait(2000, function()
    return table.concat(visible_results(), "\n"):find("fast result", 1, true) ~= nil
  end),
  "stale search completion blanked newer results"
)

require("telescope.actions").close(prompt_buffer)

local submit_requests = 0
local opened_video
local opened_target
local pending_submit_callback
local submit_provider = {
  display_name = "YouTube Music",
  default_open_target = "music",
  open_targets = {
    { id = "music", label = "YouTube Music" },
    { id = "video", label = "YouTube" },
  },
  capabilities = {
    search = true,
    open = true,
    live_search = false,
    artwork = true,
  },
  search = function(_, query, _, callback)
    submit_requests = submit_requests + 1
    pending_submit_callback = function()
      callback(nil, {
        {
          id = "video-one",
          uri = "https://music.youtube.com/watch?v=video-one",
          kind = "video",
          name = query .. " video",
          subtitle = "Test Channel",
        },
      })
    end
  end,
  open = function(_, item, callback)
    opened_video = item.id
    opened_target = item.open_target
    callback(nil, "Opened video")
  end,
}
local submit_config = require("jam.config").setup({
  provider = "youtube_music",
  artwork = { enabled = false },
})
require("jam.ui.picker").open(submit_provider, submit_config, { default_text = "explicit" })

local submit_buffer
assert(
  vim.wait(1000, function()
    for _, buffer in ipairs(vim.api.nvim_list_bufs()) do
      if vim.bo[buffer].filetype == "TelescopePrompt" and vim.fn.bufwinid(buffer) ~= -1 then
        submit_buffer = buffer
        return true
      end
    end
    return false
  end),
  "explicit-submit Telescope prompt did not open"
)
vim.wait(400, function()
  return false
end)
assert(submit_requests == 0, "submit-only provider searched while typing")
vim.api.nvim_set_current_win(vim.fn.bufwinid(submit_buffer))
local submit_mapping
for _, mapping in ipairs(vim.api.nvim_buf_get_keymap(submit_buffer, "i")) do
  if mapping.lhs == "<C-S>" then
    submit_mapping = mapping.callback
    break
  end
end
assert(submit_mapping, "submit-only provider did not map <C-s>")
for _, mapping in ipairs(vim.api.nvim_buf_get_keymap(submit_buffer, "i")) do
  if mapping.lhs == "<C-Q>" or mapping.lhs == "<C-P>" then
    assert(
      not (mapping.desc or ""):find("lua/jam/ui/picker.lua", 1, true),
      "submit-only provider mapped an unsupported playback action"
    )
  end
end
submit_mapping()
assert(
  vim.wait(1000, function()
    return submit_requests == 1
  end),
  "submit-only provider did not search after <C-s>"
)
local submit_picker = action_state.get_current_picker(submit_buffer)
assert(
  submit_picker.results_title:find("Loading", 1, true),
  "submitted search did not show a loading state"
)
pending_submit_callback()
assert(
  vim.wait(1000, function()
    return submit_picker.manager:num_results() == 1
  end),
  "submitted search results did not populate"
)
assert(
  not submit_picker.results_title:find("Loading", 1, true),
  "loading state did not clear after search"
)
assert(
  table
    .concat(vim.api.nvim_buf_get_lines(submit_picker.results_bufnr, 0, -1, false), "\n")
    :find("VIDEO", 1, true),
  "YouTube video result was not labelled VIDEO"
)
local select_mapping
local toggle_mapping
for _, mapping in ipairs(vim.api.nvim_buf_get_keymap(submit_buffer, "i")) do
  if mapping.lhs == "<CR>" then
    select_mapping = mapping.callback
  elseif mapping.lhs == "<C-T>" then
    toggle_mapping = mapping.callback
  end
end
assert(select_mapping, "search picker did not map selection")
assert(toggle_mapping, "YouTube picker did not map the open-target toggle")
toggle_mapping()
assert(
  submit_picker.results_title:match("Open: YouTube$"),
  "open target was not shown in picker title"
)
submit_picker:set_selection(submit_picker:get_row(1))
select_mapping()
assert(opened_video == "video-one", "provider open action was not used for a selected video")
assert(opened_target == "video", "selected video did not use the toggled YouTube target")
print("jam.nvim picker tests passed")
