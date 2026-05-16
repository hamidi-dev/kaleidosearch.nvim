local M = {}

function M.setup(api, keymaps)
  if not keymaps.enabled then
    return
  end

  local function set_keymap(mode, lhs, rhs, opts)
    if lhs and lhs ~= '' then
      vim.keymap.set(mode, lhs, rhs, opts)
    end
  end

  set_keymap('n', '<Plug>KaleidosearchRepeat', '<Cmd>lua require("kaleidosearch").repeat_last_action()<CR>', {
    silent = true,
  })

  set_keymap('n', keymaps.open, function()
    api.prompt_and_search()
  end, vim.tbl_extend('force', keymaps.opts, { desc = 'KaleidoSearch: Color and search words' }))

  set_keymap('n', keymaps.clear, function()
    api.clear_all_highlights()
  end, vim.tbl_extend('force', keymaps.opts, { desc = 'KaleidoSearch: Clear all color highlights' }))

  set_keymap('n', keymaps.add_new_word, function()
    api.add_new_word()
  end, vim.tbl_extend('force', keymaps.opts, { desc = 'KaleidoSearch: Add a word to existing highlights' }))

  set_keymap({ 'n', 'v' }, keymaps.add_cursor_word, function()
    api.toggle_word_or_selection()
  end, vim.tbl_extend('force', keymaps.opts, { desc = 'KaleidoSearch: Toggle highlight for word under cursor or selection' }))

  set_keymap('n', keymaps.colorize_all_lines, function()
    api.colorize_all_lines()
  end, vim.tbl_extend('force', keymaps.opts, { desc = 'KaleidoSearch: Colorize all lines in the buffer' }))

  set_keymap('n', keymaps.colorize_all_words, function()
    api.colorize_all_buffer_words(true)
  end, vim.tbl_extend('force', keymaps.opts, { desc = 'KaleidoSearch: Colorize all word tokens in the buffer' }))

  set_keymap('n', keymaps.colorize_all_WORDS, function()
    api.colorize_all_buffer_words(false)
  end, vim.tbl_extend('force', keymaps.opts, { desc = 'KaleidoSearch: Colorize all WORD tokens in the buffer' }))

  set_keymap('n', keymaps.colorize_tokens, function()
    api.colorize_tokens()
  end, vim.tbl_extend('force', keymaps.opts, { desc = 'KaleidoSearch: Colorize tiktoken tokens in the buffer' }))
end

return M
