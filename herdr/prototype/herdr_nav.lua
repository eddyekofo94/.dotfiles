-- PROTOTYPE ONLY: override Alt-h/j/k/l after the normal config loads.
-- The production tmux adapter remains untouched.

if not vim.env.HERDR_PANE_ID then
  vim.notify("Herdr navigation prototype requires a Herdr pane", vim.log.levels.WARN)
  return
end
local directions = {
  h = { nvim = "h", herdr = "left" },
  j = { nvim = "j", herdr = "down" },
  k = { nvim = "k", herdr = "up" },
  l = { nvim = "l", herdr = "right" },
}

local function navigate(key)
  local direction = directions[key]
  local before = vim.api.nvim_get_current_win()
  vim.cmd.wincmd(direction.nvim)
  if vim.api.nvim_get_current_win() ~= before then
    return
  end

  local result = vim.system({
    vim.env.HERDR_BIN_PATH or "herdr",
    "pane",
    "focus",
    "--direction",
    direction.herdr,
    "--current",
  }, { text = true }):wait()

  if result.code ~= 0 and result.stderr and result.stderr ~= "" then
    vim.notify(vim.trim(result.stderr), vim.log.levels.DEBUG)
  end
end

for key in pairs(directions) do
  vim.keymap.set("n", "<M-" .. key .. ">", function()
    navigate(key)
  end, { desc = "PROTOTYPE: Neovim window or Herdr pane " .. key })
end
