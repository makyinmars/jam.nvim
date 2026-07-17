if vim.g.loaded_jam_nvim then
  return
end
vim.g.loaded_jam_nvim = true

vim.api.nvim_create_user_command("Jam", function(opts)
  require("jam").command(opts.args)
end, {
  nargs = "*",
  complete = function(arg_lead)
    return require("jam").complete(arg_lead)
  end,
  desc = "Search and control music with jam.nvim",
})
