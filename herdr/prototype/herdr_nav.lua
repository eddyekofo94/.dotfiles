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

local function apply_maps()
  for key in pairs(directions) do
    vim.keymap.set("n", "<M-" .. key .. ">", function()
      navigate(key)
    end, { desc = "PROTOTYPE: Neovim window or Herdr pane " .. key })
  end
end

apply_maps()

local group = vim.api.nvim_create_augroup("HerdrNavigationPrototype", { clear = true })
vim.api.nvim_create_autocmd("User", {
  group = group,
  pattern = { "VeryLazy", "LazyDone" },
  callback = apply_maps,
})

-- Some local keymaps are installed after VimEnter without a common User event.
-- Reapply once after startup; this remains a prototype-only override.
vim.defer_fn(apply_maps, 1000)
