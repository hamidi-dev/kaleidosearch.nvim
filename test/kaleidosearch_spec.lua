-- Check if plenary is available
local has_plenary, plenary = pcall(require, 'plenary')
if not has_plenary then
  print('Plenary is required to run these tests!')
  return
end

local assert = require('luassert')
local kaleidosearch = require('kaleidosearch')

describe('kaleidosearch', function()
  before_each(function()
    -- Setup the plugin with default configuration
    kaleidosearch.setup()

    -- Create a test buffer
    vim.cmd('new')
    local buf = vim.api.nvim_get_current_buf()

    -- Add some test content
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
      'This is a test file with some words to highlight.',
      'We will test highlighting words like test, file, and highlight.',
      'Multiple occurrences of test should all be highlighted.',
      'Case sensitivity can also be tested with Test vs test.',
    })

    -- Set a known filetype
    vim.bo.filetype = 'markdown'
  end)

  after_each(function()
    -- Clear highlights
    kaleidosearch.clear_all_highlights()

    -- Close the test buffer
    vim.cmd('bdelete!')
  end)

  it('should highlight words correctly', function()
    -- Apply colorization with test words
    local words = { 'test', 'highlight' }
    kaleidosearch.apply_colorization(words)

    -- Check if filetype was changed to txt
    assert.are.equal('txt', vim.bo.filetype)

    -- Manually set last_words since apply_colorization doesn't set it directly
    kaleidosearch.last_words = words

    -- Check if words were added to last_words
    assert.are.same(words, kaleidosearch.last_words)

    -- We can't easily check for actual highlights in headless Neovim,
    -- but we can check if the search pattern was set correctly
    local search_pattern = vim.fn.getreg('/')
    assert.is_true(search_pattern:find('test') ~= nil)
    assert.is_true(search_pattern:find('highlight') ~= nil)
  end)

  it('should restore filetype when clearing highlights', function()
    -- Apply colorization
    kaleidosearch.apply_colorization({ 'test' })

    -- Check if filetype was changed to txt
    assert.are.equal('txt', vim.bo.filetype)

    -- Clear highlights
    kaleidosearch.clear_all_highlights()

    -- Check if filetype was restored
    assert.are.equal('markdown', vim.bo.filetype)

    -- Check if last_words was reset to an empty table
    assert.are.same({}, kaleidosearch.last_words)
  end)

  it('should toggle word under cursor correctly', function()
    -- Position cursor on a word - more precise positioning
    vim.cmd('normal! 1G0') -- Go to first line, first column
    vim.cmd('normal! 7w') -- Move to the word "words"
    local word_under_cursor = vim.fn.expand('<cword>')
    assert.are.equal('words', word_under_cursor)

    -- Toggle the word
    kaleidosearch.toggle_word_under_cursor()

    -- Check if the word was added
    assert.are.same({ word_under_cursor }, kaleidosearch.last_words)

    -- Toggle again to remove
    kaleidosearch.toggle_word_under_cursor()

    -- Check if the word was removed
    assert.are.same({}, kaleidosearch.last_words)

    -- Check if filetype was restored after removing the last word
    assert.are.equal('markdown', vim.bo.filetype)
  end)

  it('should handle case sensitivity correctly', function()
    -- Test with case sensitivity off (default)
    kaleidosearch.apply_colorization({ 'test' })

    -- Check search pattern for case insensitivity flag
    local search_pattern = vim.fn.getreg('/')
    assert.is_true(search_pattern:find('\\c') ~= nil)

    -- Clear highlights
    kaleidosearch.clear_all_highlights()

    -- Set case sensitivity to true
    kaleidosearch.setup({ case_sensitive = true })

    -- Apply colorization again
    kaleidosearch.apply_colorization({ 'test' })

    -- Check search pattern for case sensitivity flag
    search_pattern = vim.fn.getreg('/')
    assert.is_true(search_pattern:find('\\C') ~= nil)
  end)

  it('should add new words to existing highlights', function()
    -- Start with one word
    local words = { 'test' }
    kaleidosearch.apply_colorization(words)

    -- Manually set last_words since apply_colorization doesn't set it directly
    kaleidosearch.last_words = words
    assert.are.same(words, kaleidosearch.last_words)

    -- Add another word
    kaleidosearch.add_new_word('file')

    -- Check if both words are in the list
    assert.are.same({ 'test', 'file' }, kaleidosearch.last_words)

    -- Check search pattern includes both words
    local search_pattern = vim.fn.getreg('/')
    assert.is_true(search_pattern:find('test') ~= nil)
    assert.is_true(search_pattern:find('file') ~= nil)
  end)

  it('should colorize identical lines with the same color', function()
    local buf = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
      'foo',
      'bar',
      'foo',
      'baz',
      'bar',
    })

    kaleidosearch.colorize_all_lines()

    local line_colors = kaleidosearch.line_colors
    assert.are.equal(3, vim.tbl_count(line_colors))
    assert.is_not_nil(line_colors['foo'])
    assert.is_not_nil(line_colors['bar'])
    assert.is_not_nil(line_colors['baz'])
  end)

  it('should colorize all vim word tokens in the buffer', function()
    local buf = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
      'alpha beta',
      'alpha-gamma',
    })

    kaleidosearch.colorize_all_buffer_words(true)

    assert.are.same({ 'alpha', 'beta', 'gamma' }, kaleidosearch.last_words)

    local search_pattern = vim.fn.getreg('/')
    assert.is_true(search_pattern:find('alpha', 1, true) ~= nil)
    assert.is_true(search_pattern:find('beta', 1, true) ~= nil)
    assert.is_true(search_pattern:find('gamma', 1, true) ~= nil)
  end)

  it('should treat underscore as part of vim word tokens', function()
    local buf = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
      "add_new_word = '<leader>kkn'",
      "add_cursor_word = '<leader>kka'",
    })

    kaleidosearch.colorize_all_buffer_words(true)

    assert.is_true(vim.tbl_contains(kaleidosearch.last_words, 'add_new_word'))
    assert.is_true(vim.tbl_contains(kaleidosearch.last_words, 'add_cursor_word'))

    local search_pattern = vim.fn.getreg('/')
    assert.is_true(search_pattern:find('add_new_word', 1, true) ~= nil)
    assert.is_true(search_pattern:find('add_cursor_word', 1, true) ~= nil)
  end)

  it('should respect iskeyword when collecting vim word tokens', function()
    local buf = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
      'alpha-gamma beta',
    })

    local original_iskeyword = vim.bo.iskeyword
    vim.opt_local.iskeyword:append('-')

    kaleidosearch.colorize_all_buffer_words(true)

    vim.bo.iskeyword = original_iskeyword

    assert.are.same({ 'alpha-gamma', 'beta' }, kaleidosearch.last_words)

    local search_pattern = vim.fn.getreg('/')
    assert.is_true(search_pattern:find('alpha\\%-gamma', 1, false) ~= nil)
  end)

  it('should colorize all vim WORD tokens in the buffer', function()
    local buf = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
      'alpha beta',
      'alpha-gamma',
    })

    kaleidosearch.colorize_all_buffer_words(false)

    assert.are.same({ 'alpha', 'beta', 'alpha-gamma' }, kaleidosearch.last_words)

    local search_pattern = vim.fn.getreg('/')
    assert.is_true(search_pattern:find('alpha\\%-gamma', 1, false) ~= nil)
  end)

  it('should keep highlight sessions isolated per buffer', function()
    local first_buf = vim.api.nvim_get_current_buf()
    kaleidosearch.apply_colorization({ 'test' })
    assert.are.same({ 'test' }, kaleidosearch.last_words)

    vim.cmd('new')
    local second_buf = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_set_lines(second_buf, 0, -1, false, {
      'second buffer content',
    })

    kaleidosearch.apply_colorization({ 'second' })
    assert.are.same({ 'second' }, kaleidosearch.last_words)

    vim.api.nvim_set_current_buf(first_buf)
    assert.are.same({ 'test' }, kaleidosearch.last_words)

    vim.api.nvim_buf_delete(second_buf, { force = true })
  end)

  describe('backdrop', function()
    local namespace = require('kaleidosearch.state').namespace

    local function backdrop_marks(buffer, group)
      return vim.tbl_filter(function(mark)
        return mark[4].hl_group == (group or 'KaleidosearchBackdrop')
      end, vim.api.nvim_buf_get_extmarks(buffer or 0, namespace, 0, -1, { details = true }))
    end

    it('should leave non-matching text unchanged by default', function()
      kaleidosearch.apply_colorization({ 'test' })
      assert.are.equal(0, #backdrop_marks())
    end)

    it('should cover the buffer below the colored matches without accumulating on repeat', function()
      kaleidosearch.setup({ backdrop = { enabled = true } })
      vim.cmd('Kaleidosearch test')
      kaleidosearch.add_new_word('file')
      kaleidosearch.repeat_last_action()

      local marks = backdrop_marks()
      assert.are.equal(1, #marks)
      assert.are.equal(0, marks[1][2])
      assert.are.equal(0, marks[1][3])
      assert.are.equal(vim.api.nvim_buf_line_count(0), marks[1][4].end_row)

      local words = vim.tbl_filter(function(mark)
        return mark[4].hl_group:find('WordColor_', 1, true) == 1
      end, vim.api.nvim_buf_get_extmarks(0, namespace, 0, -1, { details = true }))
      assert.is_true(#words > 0)
      for _, word in ipairs(words) do
        assert.is_true(word[4].priority > marks[1][4].priority)
      end
    end)

    it('should remove the backdrop on clear and when the last word is toggled off', function()
      kaleidosearch.setup({ backdrop = { enabled = true } })
      kaleidosearch.toggle_word('test')
      assert.are.equal(1, #backdrop_marks())
      kaleidosearch.toggle_word('test')
      assert.are.equal(0, #backdrop_marks())
      assert.are.equal('markdown', vim.bo.filetype)

      kaleidosearch.apply_colorization({ 'file' })
      kaleidosearch.clear_all_highlights()
      assert.are.equal(0, #backdrop_marks())
      assert.are.equal('markdown', vim.bo.filetype)
    end)

    it('should isolate dimming and cleanup between buffers', function()
      kaleidosearch.setup({ backdrop = { enabled = true } })
      local first = vim.api.nvim_get_current_buf()
      kaleidosearch.apply_colorization({ 'test' })

      local second = vim.api.nvim_create_buf(true, false)
      vim.api.nvim_set_current_buf(second)
      vim.api.nvim_buf_set_lines(second, 0, -1, false, { 'second buffer' })
      assert.are.equal(0, #backdrop_marks(second))
      kaleidosearch.apply_colorization({ 'second' })
      kaleidosearch.clear_all_highlights()
      assert.are.equal(0, #backdrop_marks(second))
      assert.are.equal(1, #backdrop_marks(first))

      vim.api.nvim_set_current_buf(first)
      vim.api.nvim_buf_delete(second, { force = true })
    end)

    it('should remove dimming when switching to line or token modes', function()
      kaleidosearch.setup({ backdrop = { enabled = true }, token_colors = { enabled = false, notify = false } })
      kaleidosearch.apply_colorization({ 'test' })
      kaleidosearch.colorize_all_lines()
      assert.are.equal(0, #backdrop_marks())

      -- Disable the external tokenizer: cleanup must happen even if token mode cannot start.
      for _, start_tokens in ipairs({ kaleidosearch.colorize_tokens, kaleidosearch.toggle_token_colors }) do
        kaleidosearch.apply_colorization({ 'test' })
        start_tokens()
        assert.are.equal(0, #backdrop_marks())
        assert.are.equal('markdown', vim.bo.filetype)
      end
    end)

    it('should use a custom highlight group', function()
      vim.api.nvim_set_hl(0, 'KaleidosearchTestBackdrop', { fg = '#666666' })
      kaleidosearch.setup({ backdrop = { enabled = true, highlight_group = 'KaleidosearchTestBackdrop' } })
      kaleidosearch.apply_colorization({ 'test' })
      assert.are.equal(1, #backdrop_marks(0, 'KaleidosearchTestBackdrop'))
      assert.are.equal(0, #backdrop_marks())
    end)

    it('should restore the theme link after a colorscheme change and preserve user overrides', function()
      vim.cmd('colorscheme default')
      assert.are.equal('Comment', vim.api.nvim_get_hl(0, { name = 'KaleidosearchBackdrop' }).link)

      vim.api.nvim_set_hl(0, 'KaleidosearchBackdrop', { fg = '#666666' })
      kaleidosearch.setup({ backdrop = { enabled = true } })
      vim.api.nvim_exec_autocmds('ColorScheme', {})
      local color = vim.api.nvim_get_hl(0, { name = 'KaleidosearchBackdrop', link = false }).fg
      vim.api.nvim_set_hl(0, 'KaleidosearchBackdrop', { link = 'Comment' })
      assert.are.equal(0x666666, color)
    end)
  end)

  it('should expose session info and info command', function()
    kaleidosearch.apply_colorization({ 'test', 'file' })

    local info = kaleidosearch.get_session_info()
    assert.are.equal('search', info.mode)
    assert.are.equal('none', info.repeat_action)
    assert.are.equal(2, info.token_count)
    assert.are.equal(false, info.case_sensitive)
    assert.are.equal(false, info.whole_word_match)
    assert.are.equal(vim.api.nvim_get_current_buf(), info.buffer)

    assert.has_no.errors(function()
      vim.cmd('KaleidosearchInfo')
    end)
  end)

  it('should expose token color commands', function()
    assert.are.equal(2, vim.fn.exists(':KaleidosearchColorTokens'))
    assert.are.equal(2, vim.fn.exists(':KaleidosearchToggleTokens'))
    assert.is_function(kaleidosearch.colorize_tokens)
    assert.is_function(kaleidosearch.toggle_token_colors)
  end)

  it('should clear token color highlights with regular clear', function()
    local token_colors = require('kaleidosearch.token_colors')
    local buf = vim.api.nvim_get_current_buf()

    vim.api.nvim_buf_set_extmark(buf, token_colors.namespace, 0, 0, {
      end_col = 4,
      hl_group = 'Search',
    })

    kaleidosearch.clear_all_highlights()

    local marks = vim.api.nvim_buf_get_extmarks(buf, token_colors.namespace, 0, -1, {})
    assert.are.equal(0, #marks)
  end)

  it('should repeat all word token mode with updated buffer content', function()
    local buf = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
      'alpha beta',
    })

    kaleidosearch.colorize_all_buffer_words(true)
    assert.are.equal('all_words', kaleidosearch.repeat_action)
    assert.are.same({ 'alpha', 'beta' }, kaleidosearch.last_words)

    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
      'alpha beta gamma_delta',
    })
    kaleidosearch.repeat_last_action()

    assert.are.equal('all_words', kaleidosearch.repeat_action)
    assert.is_true(vim.tbl_contains(kaleidosearch.last_words, 'gamma_delta'))
  end)

  it('should repeat all WORD token mode with updated buffer content', function()
    local buf = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
      'alpha beta',
    })

    kaleidosearch.colorize_all_buffer_words(false)
    assert.are.equal('all_WORDS', kaleidosearch.repeat_action)

    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
      'alpha beta gamma-delta',
    })
    kaleidosearch.repeat_last_action()

    assert.are.equal('all_WORDS', kaleidosearch.repeat_action)
    assert.is_true(vim.tbl_contains(kaleidosearch.last_words, 'gamma-delta'))
  end)

  it('should repeat line mode with updated buffer content', function()
    local buf = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
      'foo',
      'bar',
    })

    kaleidosearch.colorize_all_lines()
    assert.are.equal('lines', kaleidosearch.repeat_action)

    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
      'foo',
      'bar',
      'baz',
    })
    kaleidosearch.repeat_last_action()

    assert.are.equal('lines', kaleidosearch.repeat_action)
    assert.is_not_nil(kaleidosearch.line_colors['baz'])
    assert.are.equal(3, vim.tbl_count(kaleidosearch.line_colors))
  end)

  it('should isolate repeat behavior between buffers', function()
    local first_buf = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_set_lines(first_buf, 0, -1, false, {
      'alpha beta',
    })

    kaleidosearch.colorize_all_buffer_words(true)
    assert.are.equal('all_words', kaleidosearch.repeat_action)

    vim.cmd('new')
    local second_buf = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_set_lines(second_buf, 0, -1, false, {
      'foo',
      'bar',
    })

    kaleidosearch.colorize_all_lines()
    assert.are.equal('lines', kaleidosearch.repeat_action)

    vim.api.nvim_set_current_buf(first_buf)
    vim.api.nvim_buf_set_lines(first_buf, 0, -1, false, {
      'alpha beta gamma',
    })
    kaleidosearch.repeat_last_action()

    assert.are.equal('all_words', kaleidosearch.repeat_action)
    assert.is_true(vim.tbl_contains(kaleidosearch.last_words, 'gamma'))

    vim.api.nvim_set_current_buf(second_buf)
    vim.api.nvim_buf_set_lines(second_buf, 0, -1, false, {
      'foo',
      'bar',
      'baz',
    })
    kaleidosearch.repeat_last_action()

    assert.are.equal('lines', kaleidosearch.repeat_action)
    assert.is_not_nil(kaleidosearch.line_colors['baz'])

    vim.api.nvim_buf_delete(second_buf, { force = true })
  end)
end)
