-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

local map = vim.keymap.set

map("n", "<leader>tf", function()
  LazyVim.format.toggle()
end, { desc = "Toggle Auto Format (Global)" })

map("n", "<leader>tF", function()
  LazyVim.format.toggle(true)
end, { desc = "Toggle Auto Format (Buffer)" })

vim.api.nvim_create_user_command("FormatDisable", function(args)
  LazyVim.format.enable(false, args.bang)
end, {
  bang = true,
  desc = "Disable auto format (! = buffer)",
})

vim.api.nvim_create_user_command("FormatEnable", function(args)
  LazyVim.format.enable(true, args.bang)
end, {
  bang = true,
  desc = "Enable auto format (! = buffer)",
})

vim.api.nvim_create_user_command("FormatToggle", function(args)
  LazyVim.format.toggle(args.bang)
end, {
  bang = true,
  desc = "Toggle auto format (! = buffer)",
})

vim.keymap.set("n", "<leader>fd", function()
  local fname = vim.fn.expand("%:p")
  local ext = vim.fn.expand("%:e")
  local newname = fname:gsub("%.lua$", "_copy.lua")
  if fname == newname then
    newname = fname .. ".copy"
  end
  vim.cmd("write")
  vim.fn.system({ "cp", fname, newname })
  vim.cmd("edit " .. newname)
end, { desc = "Duplicate current config file" })

if vim.fn.executable("lazygit") == 1 then
  map("n", "<leader>lg", function()
    Snacks.lazygit({ cwd = LazyVim.root.git() })
  end, { desc = "Lazygit (Root Dir)" })
  map("n", "<leader>lG", function()
    Snacks.lazygit()
  end, { desc = "Lazygit (cwd)" })
end
