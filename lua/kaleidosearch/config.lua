local palette = require('kaleidosearch.palette')

local M = {}

local default_config = {
  debug = false,
  highlight_group_prefix = 'WordColor_',
  case_sensitive = false,
  whole_word_match = false,
  token_colors = {
    enabled = true,
    model = 'gpt-4o',
    encoding = 'o200k_base',
    max_bytes = 200 * 1024,
    max_highlights = 20000,
    palette_size = 32,
    saturation = 0.55,
    lightness = 0.24,
    priority = 120,
    notify = true,
    highlight_group_prefix = 'KaleidosearchToken',
  },
  get_next_color = function(buf_state)
    return palette.next_color(buf_state)
  end,
  sanitize_group_name = function(color)
    return color:gsub('[^a-zA-Z0-9_]', '_')
  end,
  keymaps = {
    enabled = true,
    open = '<leader>cs',
    clear = '<leader>cc',
    add_new_word = '<leader>cn',
    add_cursor_word = '<leader>ca',
    colorize_all_words = '<leader>cw',
    colorize_all_WORDS = '<leader>cW',
    colorize_all_lines = '<leader>cl',
    colorize_tokens = '<leader>ct',
    opts = {
      noremap = true,
      silent = true,
    },
  },
}

function M.build(user_config)
  return vim.tbl_deep_extend('force', vim.deepcopy(default_config), user_config or {})
end

return M
