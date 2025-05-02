-- Add the plugin directory to package.path
local plugin_dir = vim.fn.expand("<sfile>:p:h:h")

-- Find plenary in common locations
local plenary_paths = {
  vim.fn.stdpath("data") .. "/lazy/plenary.nvim",
  vim.fn.stdpath("data") .. "/site/pack/vendor/start/plenary.nvim",
  vim.fn.stdpath("data") .. "/site/pack/packer/start/plenary.nvim",
  vim.fn.stdpath("data") .. "/plugged/plenary.nvim"
}

for _, path in ipairs(plenary_paths) do
  if vim.fn.isdirectory(path) == 1 then
    vim.opt.rtp:prepend(path)
    print("Added Plenary from: " .. path)
    break
  end
end

-- Properly set up the Lua path to find the plugin
vim.opt.rtp:prepend(plugin_dir)

-- Wait a bit to ensure the runtime path is updated
vim.cmd("sleep 100m")

-- Set up the plugin
require("kaleidosearch").setup()

