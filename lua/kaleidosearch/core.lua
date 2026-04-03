local actions = require('kaleidosearch.actions')
local commands = require('kaleidosearch.commands')
local config = require('kaleidosearch.config')
local keymaps = require('kaleidosearch.keymaps')
local matcher = require('kaleidosearch.matcher')
local palette = require('kaleidosearch.palette')
local state = require('kaleidosearch.state')

local M = {}

local repeat_actions = {
  search = 'search',
  all_words = 'all_words',
  all_WORDS = 'all_WORDS',
  lines = 'lines',
}

M.config = {}
M.last_words = nil
M.line_colors = {}
M.repeat_action = nil
M._public_buf = nil

local function log(msg, level)
  level = level or vim.log.levels.INFO
  if M.config.debug or level == vim.log.levels.ERROR then
    print('[kaleidosearch] ' .. msg, level)
  end
end

local function sync_public_state(bufnr, buf_state)
  M._public_buf = bufnr
  M.last_words = buf_state.last_words
  M.line_colors = buf_state.line_colors
  M.repeat_action = buf_state.repeat_action
end

local function sync_state_from_public(bufnr, buf_state)
  if M._public_buf ~= bufnr then
    return
  end

  if type(M.last_words) == 'table' and M.last_words ~= buf_state.last_words then
    buf_state.last_words = M.last_words
  end
end

local function current_context()
  local bufnr = vim.api.nvim_get_current_buf()
  local buf_state = state.get(bufnr)
  sync_public_state(bufnr, buf_state)
  return bufnr, buf_state
end

local function set_repeat(buf_state, action)
  buf_state.repeat_action = action
  sync_public_state(vim.api.nvim_get_current_buf(), buf_state)
  vim.cmd([[silent! call repeat#set("\<Plug>KaleidosearchRepeat", v:count)]])
end

local execute_colored_search = actions.attach(M, {
  matcher = matcher,
  palette = palette,
  state = state,
  repeat_actions = repeat_actions,
  log = log,
  current_context = current_context,
  sync_public_state = sync_public_state,
  sync_state_from_public = sync_state_from_public,
  set_repeat = set_repeat,
})

function M.setup(user_config)
  M.config = config.build(user_config)

  state.setup_autocmds(function(bufnr, buf_state)
    sync_public_state(bufnr, buf_state)
  end)

  keymaps.setup(M, M.config.keymaps)
  commands.setup(M, execute_colored_search)

  local bufnr = vim.api.nvim_get_current_buf()
  sync_public_state(bufnr, state.get(bufnr))
end

return M
