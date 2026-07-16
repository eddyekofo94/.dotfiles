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

local function record(message)
  local path = vim.env.HERDR_NAV_LOG
  if path and path ~= "" then
    vim.fn.writefile({ os.date("!%Y-%m-%dT%H:%M:%SZ") .. " nvim " .. message }, path, "a")
  end
end

local function navigate(key)
  local direction = directions[key]

  -- Keep the production tmux.lua exception byte-for-byte in behavior: these
  -- directions first give an active fzf-lua window a chance to own focus.
  if (key == "j" or key == "k") and _G.FzfLuaFocus and _G.FzfLuaFocus() then
    record(key .. " fzf-lua")
    return
  end

  local before = vim.fn.winnr()
  vim.cmd.wincmd(direction.nvim)
  if vim.fn.winnr() ~= before then
    record(key .. " local-window")
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

  record(key .. " herdr-edge exit=" .. result.code)
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
