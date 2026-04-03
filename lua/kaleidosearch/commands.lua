local matcher = require('kaleidosearch.matcher')

local M = {}

function M.setup(api, execute_colored_search)
  vim.api.nvim_create_user_command('Kaleidosearch', function(args)
    if args.args and args.args ~= '' then
      execute_colored_search(matcher.split_input(args.args))
    else
      api.prompt_and_search()
    end
  end, {
    nargs = '*',
    desc = 'Highlight specific words with random colors',
  })

  vim.api.nvim_create_user_command('KaleidosearchClear', api.clear_all_highlights, {
    desc = 'Clear all word highlights',
  })

  vim.api.nvim_create_user_command('KaleidosearchAddWord', function(args)
    if args.args and args.args ~= '' then
      api.add_new_word(args.args)
    else
      api.add_new_word()
    end
  end, {
    nargs = '?',
    desc = 'Add a word to existing highlights',
  })

  vim.api.nvim_create_user_command('KaleidosearchToggleCursorWord', function()
    api.toggle_word_or_selection()
  end, {
    desc = 'Toggle highlight for word under cursor or selection',
  })

  vim.api.nvim_create_user_command('KaleidosearchColorLines', function()
    api.colorize_all_lines()
  end, {
    desc = 'Colorize all lines, identical lines share colors',
  })

  vim.api.nvim_create_user_command('KaleidosearchColorWords', function()
    api.colorize_all_buffer_words(true)
  end, {
    desc = "Colorize all vim 'word' tokens in the buffer",
  })

  vim.api.nvim_create_user_command('KaleidosearchColorWORDS', function()
    api.colorize_all_buffer_words(false)
  end, {
    desc = "Colorize all vim 'WORD' tokens in the buffer",
  })

  vim.api.nvim_create_user_command('KaleidosearchInfo', function()
    api.show_info()
  end, {
    desc = 'Show current Kaleidosearch session info',
  })
end

return M
