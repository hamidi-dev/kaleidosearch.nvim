local M = {}

function M.attach(api, deps)
  local matcher = deps.matcher
  local palette = deps.palette
  local state = deps.state
  local repeat_actions = deps.repeat_actions
  local log = deps.log
  local current_context = deps.current_context
  local sync_public_state = deps.sync_public_state
  local sync_state_from_public = deps.sync_state_from_public
  local set_repeat = deps.set_repeat

  local function get_group_name(color)
    return api.config.highlight_group_prefix .. api.config.sanitize_group_name(color)
  end

  local function highlight_word(buffer, buf_state, word, line_nr, word_start, word_end)
    local word_key = matcher.normalize_word(word, api.config.case_sensitive)

    if not buf_state.word_colors[word_key] then
      buf_state.word_colors[word_key] = api.config.get_next_color(buf_state)
    end

    local color = buf_state.word_colors[word_key]
    local group_name = get_group_name(color)

    vim.api.nvim_set_hl(0, group_name, { fg = color })
    vim.api.nvim_buf_add_highlight(buffer, state.namespace, group_name, line_nr - 1, word_start - 1, word_end)
  end

  local function highlight_line(buffer, buf_state, line_content, line_nr)
    if not buf_state.line_colors[line_content] then
      buf_state.line_colors[line_content] = api.config.get_next_color(buf_state)
    end

    local color = buf_state.line_colors[line_content]
    local group_name = get_group_name(color)

    vim.api.nvim_set_hl(0, group_name, { bg = color })
    vim.api.nvim_buf_add_highlight(buffer, state.namespace, group_name, line_nr - 1, 0, -1)
  end

  local function colorize_words(buffer, buf_state, words_to_colorize)
    local lines = vim.api.nvim_buf_get_lines(buffer, 0, -1, false)

    for line_nr, line in ipairs(lines) do
      local search_line = api.config.case_sensitive and line or line:lower()

      for _, target_word in ipairs(words_to_colorize) do
        local pattern = api.config.case_sensitive and target_word or target_word:lower()
        local start_pos = 1

        log(string.format("Searching for pattern '%s' in line %d", pattern, line_nr))

        while true do
          local word_start, word_end = search_line:find(pattern, start_pos, true)
          if not word_start then
            break
          end

          local should_highlight = true

          if api.config.whole_word_match then
            local prev_char = word_start > 1 and search_line:sub(word_start - 1, word_start - 1) or nil
            local next_char = word_end < #search_line and search_line:sub(word_end + 1, word_end + 1) or nil

            local is_word_boundary_before = not prev_char or not matcher.is_keyword_char(prev_char)
            local is_word_boundary_after = not next_char or not matcher.is_keyword_char(next_char)

            should_highlight = is_word_boundary_before and is_word_boundary_after
          end

          if should_highlight then
            local original_word = line:sub(word_start, word_end)
            log(string.format("Found match at positions %d-%d: '%s'", word_start, word_end, original_word))
            highlight_word(buffer, buf_state, original_word, line_nr, word_start, word_end)
          end

          start_pos = word_end + 1
        end
      end
    end
  end

  local function colorize_lines(buffer, buf_state)
    local lines = vim.api.nvim_buf_get_lines(buffer, 0, -1, false)
    for line_nr, line in ipairs(lines) do
      highlight_line(buffer, buf_state, line, line_nr)
    end
  end

  local function execute_colored_search(words)
    if not words then
      return
    end

    api.apply_colorization(words)
    local _, buf_state = current_context()
    set_repeat(buf_state, repeat_actions.search)
  end

  function api.apply_colorization(words_to_colorize)
    words_to_colorize = matcher.unique_words(words_to_colorize or {}, api.config.case_sensitive)
    if #words_to_colorize == 0 then
      return
    end

    local buffer, buf_state = current_context()

    palette.start_new_palette(buf_state)
    state.clear_highlights(buffer, buf_state)
    vim.api.nvim_command('set nohlsearch')
    state.set_filetype_to_txt(buffer, buf_state)

    colorize_words(buffer, buf_state, words_to_colorize)

    local search_pattern = matcher.build_search_pattern(words_to_colorize, api.config.case_sensitive, api.config.whole_word_match)

    vim.fn.setreg('/', search_pattern)
    vim.api.nvim_command('nohlsearch')

    log('Words to colorize: ' .. vim.inspect(words_to_colorize))
    log('Search pattern set: ' .. search_pattern)

    buf_state.last_words = words_to_colorize
    sync_public_state(buffer, buf_state)
  end

  function api.colorize_all_buffer_words(use_word)
    local buffer = vim.api.nvim_get_current_buf()
    local words = matcher.collect_words_from_buffer(buffer, use_word, api.config.case_sensitive)

    if #words == 0 then
      return
    end

    api.apply_colorization(words)

    local _, buf_state = current_context()
    if use_word then
      set_repeat(buf_state, repeat_actions.all_words)
    else
      set_repeat(buf_state, repeat_actions.all_WORDS)
    end
  end

  function api.colorize_all_lines()
    local buffer, buf_state = current_context()

    palette.start_new_palette(buf_state)
    state.clear_highlights(buffer, buf_state)
    state.set_filetype_to_txt(buffer, buf_state)

    colorize_lines(buffer, buf_state)
    sync_public_state(buffer, buf_state)
    set_repeat(buf_state, repeat_actions.lines)
  end

  function api.clear_all_highlights()
    local buffer, buf_state = current_context()

    vim.api.nvim_command('set nohlsearch')
    state.clear_highlights(buffer, buf_state)
    buf_state.last_words = {}
    state.restore_original_filetype(buffer, buf_state)

    sync_public_state(buffer, buf_state)
  end

  function api.add_new_word(word)
    if not word or word == '' then
      vim.ui.input({
        prompt = 'Enter word to add to colorization: ',
        default = '',
      }, function(input)
        if input and input ~= '' then
          api.add_new_word(input)
        end
      end)
      return
    end

    local buffer, buf_state = current_context()
    sync_state_from_public(buffer, buf_state)

    local new_words = vim.deepcopy(buf_state.last_words or {})
    table.insert(new_words, word)
    buf_state.last_words = new_words
    sync_public_state(buffer, buf_state)

    api.apply_colorization(new_words)
    local _, active_state = current_context()
    set_repeat(active_state, repeat_actions.search)
  end

  function api.get_visual_selection()
    local reg_save = vim.fn.getreg('"')
    local regtype_save = vim.fn.getregtype('"')

    vim.cmd('normal! gvy')

    local selection = vim.fn.getreg('"')
    selection = selection:gsub('[\n\r]', ' '):gsub('%s+', ' '):gsub('^%s*(.-)%s*$', '%1')

    log("Visual selection (raw): '" .. vim.fn.getreg('"') .. "'")
    log("Visual selection (cleaned): '" .. selection .. "'")

    vim.fn.setreg('"', reg_save, regtype_save)
    return selection
  end

  function api.toggle_word(word)
    if not word or word == '' then
      return
    end

    local buffer, buf_state = current_context()
    sync_state_from_public(buffer, buf_state)

    local new_words = vim.deepcopy(buf_state.last_words or {})
    local word_index = nil

    for i, highlighted_word in ipairs(new_words) do
      local is_match
      if api.config.case_sensitive then
        is_match = highlighted_word == word
      else
        is_match = highlighted_word:lower() == word:lower()
      end

      if is_match then
        word_index = i
        break
      end
    end

    if word_index then
      table.remove(new_words, word_index)
    else
      table.insert(new_words, word)
    end

    buf_state.last_words = new_words
    sync_public_state(buffer, buf_state)

    if #new_words > 0 then
      api.apply_colorization(new_words)
    else
      api.clear_all_highlights()
    end

    local _, active_state = current_context()
    set_repeat(active_state, repeat_actions.search)
  end

  function api.toggle_word_under_cursor()
    local word = vim.fn.expand('<cword>')
    if word and word ~= '' then
      api.toggle_word(word)
    end
  end

  function api.toggle_word_or_selection()
    local mode = vim.fn.mode()

    if mode == 'v' or mode == 'V' or mode == '\22' then
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<Esc>', true, false, true), 'nx', false)

      local selected_text = api.get_visual_selection()
      log('Mode detected: Visual')
      log("Selected text: '" .. (selected_text or 'nil') .. "'")

      if selected_text and selected_text ~= '' then
        api.toggle_word(selected_text)
      end
    else
      log('Mode detected: Normal')
      api.toggle_word_under_cursor()
    end
  end

  function api.prompt_and_search()
    local buffer, buf_state = current_context()
    sync_state_from_public(buffer, buf_state)

    local default_input = ''
    if buf_state.last_words and #buf_state.last_words > 0 then
      default_input = table.concat(buf_state.last_words, ' ')
    end

    vim.ui.input({
      prompt = 'Enter words to colorize (space-separated): ',
      default = default_input,
      completion = 'file',
    }, function(input)
      if input then
        execute_colored_search(matcher.split_input(input))
      end
    end)
  end

  function api.repeat_last_action()
    local _, buf_state = current_context()

    if buf_state.repeat_action == repeat_actions.search then
      if buf_state.last_words and #buf_state.last_words > 0 then
        api.apply_colorization(buf_state.last_words)
      end
    elseif buf_state.repeat_action == repeat_actions.all_words then
      api.colorize_all_buffer_words(true)
    elseif buf_state.repeat_action == repeat_actions.all_WORDS then
      api.colorize_all_buffer_words(false)
    elseif buf_state.repeat_action == repeat_actions.lines then
      api.colorize_all_lines()
    end
  end

  function api.get_session_info()
    local buffer, buf_state = current_context()
    local token_count = #(buf_state.last_words or {})
    local line_count = vim.tbl_count(buf_state.line_colors)

    local mode = 'idle'
    if buf_state.repeat_action == repeat_actions.all_words then
      mode = 'all_words'
    elseif buf_state.repeat_action == repeat_actions.all_WORDS then
      mode = 'all_WORDS'
    elseif buf_state.repeat_action == repeat_actions.lines then
      mode = 'lines'
    elseif buf_state.repeat_action == repeat_actions.search then
      mode = 'search'
    elseif token_count > 0 then
      mode = 'search'
    elseif line_count > 0 then
      mode = 'lines'
    end

    return {
      buffer = buffer,
      filetype = vim.bo[buffer].filetype,
      mode = mode,
      repeat_action = buf_state.repeat_action or 'none',
      token_count = token_count,
      line_count = line_count,
      case_sensitive = api.config.case_sensitive,
      whole_word_match = api.config.whole_word_match,
    }
  end

  function api.show_info()
    local info = api.get_session_info()
    local message = string.format(
      'mode=%s repeat=%s tokens=%d lines=%d case_sensitive=%s whole_word=%s filetype=%s buffer=%d',
      info.mode,
      info.repeat_action,
      info.token_count,
      info.line_count,
      tostring(info.case_sensitive),
      tostring(info.whole_word_match),
      info.filetype,
      info.buffer
    )

    if vim.notify then
      vim.notify(message, vim.log.levels.INFO, { title = 'Kaleidosearch' })
    else
      print(message)
    end

    return message
  end

  return execute_colored_search
end

return M
