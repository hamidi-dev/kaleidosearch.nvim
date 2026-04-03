local M = {}

function M.setup(api, keymaps)
  if not keymaps.enabled then
    return
  end

  vim.keymap.set('n', '<Plug>KaleidosearchRepeat', '<Cmd>lua require("kaleidosearch").repeat_last_action()<CR>', {
    silent = true,
  })

  vim.keymap.set('n', keymaps.open, function()
    api.prompt_and_search()
  end, vim.tbl_extend('force', keymaps.opts, { desc = 'KaleidoSearch: Color and search words' }))

  vim.keymap.set('n', keymaps.clear, function()
    api.clear_all_highlights()
  end, vim.tbl_extend('force', keymaps.opts, { desc = 'KaleidoSearch: Clear colored search highlights' }))

  vim.keymap.set('n', keymaps.add_new_word, function()
    api.add_new_word()
  end, vim.tbl_extend('force', keymaps.opts, { desc = 'KaleidoSearch: Add a word to existing highlights' }))

  vim.keymap.set({ 'n', 'v' }, keymaps.add_cursor_word, function()
    api.toggle_word_or_selection()
  end, vim.tbl_extend('force', keymaps.opts, { desc = 'KaleidoSearch: Toggle highlight for word under cursor or selection' }))

  vim.keymap.set('n', keymaps.colorize_all_lines, function()
    api.colorize_all_lines()
  end, vim.tbl_extend('force', keymaps.opts, { desc = 'KaleidoSearch: Colorize all lines in the buffer' }))

  vim.keymap.set('n', keymaps.colorize_all_words, function()
    api.colorize_all_buffer_words(true)
  end, vim.tbl_extend('force', keymaps.opts, { desc = 'KaleidoSearch: Colorize all word tokens in the buffer' }))

  vim.keymap.set('n', keymaps.colorize_all_WORDS, function()
    api.colorize_all_buffer_words(false)
  end, vim.tbl_extend('force', keymaps.opts, { desc = 'KaleidoSearch: Colorize all WORD tokens in the buffer' }))
end

return M
