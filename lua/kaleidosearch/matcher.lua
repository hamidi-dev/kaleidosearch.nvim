local M = {}

function M.normalize_word(word, case_sensitive)
  return case_sensitive and word or word:lower()
end

function M.unique_words(words, case_sensitive)
  local deduped_words = {}
  local seen = {}

  for _, word in ipairs(words) do
    if word and word ~= '' then
      local key = M.normalize_word(word, case_sensitive)
      if not seen[key] then
        seen[key] = true
        table.insert(deduped_words, word)
      end
    end
  end

  return deduped_words
end

local function collect_vim_word_tokens(line)
  local tokens = {}
  local start_pos = 0

  while true do
    local match = vim.fn.matchstrpos(line, [[\k\+]], start_pos)
    local token = match[1]
    local word_start = match[2]
    local word_end = match[3]

    if word_start < 0 or token == '' then
      break
    end

    table.insert(tokens, token)
    start_pos = word_end
  end

  return tokens
end

function M.collect_words_from_buffer(buffer, use_word, case_sensitive)
  local lines = vim.api.nvim_buf_get_lines(buffer, 0, -1, false)
  local words = {}
  local seen = {}

  for _, line in ipairs(lines) do
    local tokens = use_word and collect_vim_word_tokens(line) or vim.split(line, '%s+', { trimempty = true })

    for _, token in ipairs(tokens) do
      local key = M.normalize_word(token, case_sensitive)
      if not seen[key] then
        seen[key] = true
        table.insert(words, token)
      end
    end
  end

  return words
end

function M.is_keyword_char(char)
  return char and char ~= '' and vim.fn.match(char, [[\k]]) == 0
end

function M.build_search_pattern(words, case_sensitive, whole_word_match)
  local case_flag = case_sensitive and '\\C' or '\\c'
  local patterns = {}

  for _, word in ipairs(words) do
    local escaped_word = word:gsub('([%^%$%(%)%%%.%[%]%*%+%-%?])', '\\%1')
    if whole_word_match then
      table.insert(patterns, '\\<' .. escaped_word .. '\\>')
    else
      table.insert(patterns, escaped_word)
    end
  end

  if #patterns == 0 then
    return ''
  end

  return '\\m' .. case_flag .. '\\(' .. table.concat(patterns, '\\|') .. '\\)'
end

function M.split_input(input)
  local words = {}
  for word in (input or ''):gmatch('%S+') do
    table.insert(words, word)
  end
  return words
end

return M
