return require("telescope").register_extension({
  exports = {
    jam = function(opts)
      require("jam").open(opts)
    end,
  },
})
