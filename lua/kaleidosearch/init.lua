local M = {}

-- Used colors tracking
local used_colors = {}
local current_color_index = 0
local palette_shift = 0

-- Helper function to convert HSL to RGB
local function hsl_to_rgb(h, s, l)
  if s == 0 then
    return { r = l, g = l, b = l }
  else
    local function hue_to_rgb(p, q, t)
      if t < 0 then t = t + 1 end
      if t > 1 then t = t - 1 end
      if t < 1 / 6 then return p + (q - p) * 6 * t end
      if t < 1 / 2 then return q end
      if t < 2 / 3 then return p + (q - p) * (2 / 3 - t) * 6 end
      return p
    end
    local q = l < 0.5 and l * (1 + s) or l + s - l * s
    local p = 2 * l - q
    return {
      r = hue_to_rgb(p, q, h + 1 / 3) * 255,
      g = hue_to_rgb(p, q, h) * 255,
      b = hue_to_rgb(p, q, h - 1 / 3) * 255
    }
  end
end

-- Generate a new color based on index
local function generate_color(index)
  local hue = ((index + palette_shift) * 137) % 360 / 360 -- Use a large prime number for equally distributed colors
  local rgb = hsl_to_rgb(hue, 0.5, 0.5)
  local r = math.floor(rgb.r + 0.5)
  local g = math.floor(rgb.g + 0.5)
  local b = math.floor(rgb.b + 0.5)
  return string.format("#%02X%02X%02X", r, g, b)
end

-- Smart color selection function
local function get_next_color()
  current_color_index = current_color_index + 1
  local new_color = generate_color(current_color_index)
  table.insert(used_colors, new_color)
  return new_color
end

local function clear_used_colors()
  for key in pairs(used_colors) do
    used_colors[key] = nil
  end
end

local function start_new_palette()
  current_color_index = 0
  palette_shift = (palette_shift + 29) % 360
  clear_used_colors()
end

-- Default configuration
local default_config = {
  debug = false,            -- Debug mode to print additional information
  highlight_group_prefix = "WordColor_",
  case_sensitive = false,   -- Add case sensitivity option
  whole_word_match = false, -- Only match whole words, not substrings
  get_next_color = get_next_color,
  sanitize_group_name = function(color)
    return color:gsub("[^a-zA-Z0-9_]", "_")
  end,
  keymaps = {
    enabled = true,
    -- Default keymaps
    open = "<leader>cs",            -- Open input prompt for search
    clear = "<leader>cc",           -- Clear highlights
    add_new_word = "<leader>cn",    -- Add a new word to existing highlights
    add_cursor_word = "<leader>ca", -- Add word under cursor to highlights
    colorize_all_words = "<leader>cw", -- Colorize all vim 'word' tokens in buffer
    colorize_all_WORDS = "<leader>cW", -- Colorize all vim 'WORD' tokens in buffer
    colorize_all_lines = "<leader>cl", -- Colorize all lines in the buffer
    -- Additional options for keymaps
    opts = {
      noremap = true,
      silent = true,
    }
  }
}

-- Debug logging
local function log(msg, level)
  level = level or vim.log.levels.INFO
  if M.config.debug or level == vim.log.levels.ERROR then
    print("[kaleidosearch] " .. msg, level)
  end
end

local repeat_actions = {
  search = "search",
  all_words = "all_words",
  all_WORDS = "all_WORDS",
  lines = "lines",
}

local function set_repeat(action)
  M.repeat_action = action
  vim.cmd([[silent! call repeat#set("\<Plug>KaleidosearchRepeat", v:count)]])
end

local function run_repeat_action()
  if M.repeat_action == repeat_actions.search then
    if M.last_words and #M.last_words > 0 then
      M.apply_colorization(M.last_words)
    end
  elseif M.repeat_action == repeat_actions.all_words then
    M.colorize_all_buffer_words(true)
  elseif M.repeat_action == repeat_actions.all_WORDS then
    M.colorize_all_buffer_words(false)
  elseif M.repeat_action == repeat_actions.lines then
    M.colorize_all_lines()
  end
end

function M.repeat_last_action()
  run_repeat_action()
end

-- Configuration table
M.config = {}

-- Table to store colors for each word
local word_colors = {}
-- Table to store colors for each line
local line_colors = {}

-- expose line colors for testing
M.line_colors = line_colors

-- Variable to store the original filetype
local original_filetype

-- Function to save and set filetype to txt
local function set_filetype_to_txt()
  if not original_filetype or original_filetype == "" then
    original_filetype = vim.bo.filetype
  end
  vim.bo.filetype = "txt"
end

-- Function to restore the original filetype
local function restore_original_filetype()
  if original_filetype then
    vim.bo.filetype = original_filetype
    original_filetype = nil
  end
end

-- Function to clear all highlights from a buffer
local function clear_table(tbl)
  for key in pairs(tbl) do
    tbl[key] = nil
  end
end

local function clear_highlights(buffer)
  vim.api.nvim_buf_clear_namespace(buffer, 0, 0, -1)
  clear_table(word_colors)
  clear_table(line_colors)
end

-- Function to highlight a specific word in the buffer
local function highlight_word(buffer, word, line_nr, word_start, word_end)
  -- Use lowercase version of the word as key when case_sensitive is false
  local word_key = M.config.case_sensitive and word or word:lower()

  if not word_colors[word_key] then
    word_colors[word_key] = M.config.get_next_color() -- Assign the next color from the palette if the word doesn't have one yet
  end
  local color = word_colors[word_key]
  local group_name = M.config.highlight_group_prefix .. M.config.sanitize_group_name(color)
  vim.api.nvim_command("highlight " .. group_name .. " guifg=" .. color)
  vim.api.nvim_buf_add_highlight(buffer, 0, group_name, line_nr - 1, word_start - 1, word_end)
end

-- Function to highlight a specific line in the buffer
local function highlight_line(buffer, line_content, line_nr)
  if not line_colors[line_content] then
    line_colors[line_content] = M.config.get_next_color()
  end
  local color = line_colors[line_content]
  local group_name = M.config.highlight_group_prefix .. M.config.sanitize_group_name(color)
  vim.api.nvim_command("highlight " .. group_name .. " guibg=" .. color)
  vim.api.nvim_buf_add_highlight(buffer, 0, group_name, line_nr - 1, 0, -1)
end

local function normalize_word(word)
  return M.config.case_sensitive and word or word:lower()
end

local function unique_words(words)
  local deduped_words = {}
  local seen = {}

  for _, word in ipairs(words) do
    if word and word ~= "" then
      local key = normalize_word(word)
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

    if word_start < 0 or token == "" then
      break
    end

    table.insert(tokens, token)
    start_pos = word_end
  end

  return tokens
end

local function is_keyword_char(char)
  return char and char ~= "" and vim.fn.match(char, [[\k]]) == 0
end

local function collect_words_from_buffer(buffer, use_word)
  local lines = vim.api.nvim_buf_get_lines(buffer, 0, -1, false)
  local words = {}
  local seen = {}

  for _, line in ipairs(lines) do
    local tokens = use_word and collect_vim_word_tokens(line) or vim.split(line, "%s+", { trimempty = true })

    for _, token in ipairs(tokens) do
      local key = normalize_word(token)
      if not seen[key] then
        seen[key] = true
        table.insert(words, token)
      end
    end
  end

  return words
end

-- Function to colorize words in the buffer
local function colorize_words(buffer, words_to_colorize)
  local lines = vim.api.nvim_buf_get_lines(buffer, 0, -1, false)
  for line_nr, line in ipairs(lines) do
    local search_line = M.config.case_sensitive and line or line:lower()

    for _, target_word in ipairs(words_to_colorize) do
      local pattern = target_word -- Exact match
      if not M.config.case_sensitive then
        pattern = pattern:lower()
      end

      log(string.format("Searching for pattern '%s' in line %d", pattern, line_nr))
      local start_pos = 1

      while true do
        local word_start, word_end

        if M.config.whole_word_match then
          -- check word boundaries
          -- First find the pattern
          word_start, word_end = search_line:find(pattern, start_pos, true)
          if not word_start then break end

          -- Then check if it's a whole word by examining characters before and after
          local prev_char = word_start > 1 and search_line:sub(word_start - 1, word_start - 1) or nil
          local next_char = word_end < #search_line and search_line:sub(word_end + 1, word_end + 1) or nil

          -- Check if the match is surrounded by non-word characters or string boundaries
          local is_word_boundary_before = not prev_char or not is_keyword_char(prev_char)
          local is_word_boundary_after = not next_char or not is_keyword_char(next_char)

          -- If not a whole word, move to next potential match
          if not (is_word_boundary_before and is_word_boundary_after) then
            start_pos = word_end + 1
            goto continue
          end
        else
          -- Simple substring matching
          word_start, word_end = search_line:find(pattern, start_pos, true)
          if not word_start then break end
        end

        local original_word = line:sub(word_start, word_end)
        log(string.format("Found match at positions %d-%d: '%s'", word_start, word_end, original_word))
        highlight_word(buffer, original_word, line_nr, word_start, word_end)
        start_pos = word_end + 1
        ::continue::
      end
    end
  end
end

-- Function to colorize all lines in the buffer
local function colorize_lines(buffer)
  local lines = vim.api.nvim_buf_get_lines(buffer, 0, -1, false)
  for line_nr, line in ipairs(lines) do
    highlight_line(buffer, line, line_nr)
  end
end

-- Function to apply the colorization
function M.apply_colorization(words_to_colorize)
  words_to_colorize = unique_words(words_to_colorize or {})
  if not words_to_colorize or #words_to_colorize == 0 then
    return
  end

  local buffer = vim.api.nvim_get_current_buf()

  -- Clear existing highlights
  start_new_palette()
  clear_highlights(buffer)
  vim.api.nvim_command("set nohlsearch") -- Turn off search highlighting

  -- Set filetype to txt - always do this when applying colorization
  set_filetype_to_txt()

  -- Colorize the words
  colorize_words(buffer, words_to_colorize)

  -- Build regex pattern for search
  local case_flag = M.config.case_sensitive and "\\C" or "\\c"

  -- Create a pattern that will work with Vim's search
  local patterns = {}
  for _, word in ipairs(words_to_colorize) do
    -- Escape special regex characters
    local escaped_word = word:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "\\%1")

    if M.config.whole_word_match then
      -- For whole word matching, use \< and \> word boundary markers
      table.insert(patterns, "\\<" .. escaped_word .. "\\>")
    else
      table.insert(patterns, escaped_word)
    end
  end

  -- Join patterns with OR operator
  local search_pattern
  if #patterns > 0 then
    -- Use magic mode (\m) instead of very magic (\v) for more predictable behavior
    search_pattern = "\\m" .. case_flag .. "\\(" .. table.concat(patterns, "\\|") .. "\\)"
  else
    search_pattern = ""
  end

  -- Set the search register and disable highlighting
  vim.fn.setreg("/", search_pattern)
  vim.api.nvim_command("nohlsearch")
  log("Words to colorize: " .. vim.inspect(words_to_colorize))
  log("Search pattern set: " .. search_pattern)
  M.last_words = words_to_colorize
end

-- Function to colorize all words (vim 'word' or 'WORD') in the current buffer
function M.colorize_all_buffer_words(use_word)
  local buffer = vim.api.nvim_get_current_buf()
  local words = collect_words_from_buffer(buffer, use_word)

  if #words == 0 then
    return
  end

  M.apply_colorization(words)
  if use_word then
    set_repeat(repeat_actions.all_words)
  else
    set_repeat(repeat_actions.all_WORDS)
  end
end

-- Function to colorize all lines in the current buffer
function M.colorize_all_lines()
  local buffer = vim.api.nvim_get_current_buf()
  start_new_palette()
  clear_highlights(buffer)
  set_filetype_to_txt()
  colorize_lines(buffer)
  set_repeat(repeat_actions.lines)
end

-- Function to clear all highlights
function M.clear_all_highlights()
  local buffer = vim.api.nvim_get_current_buf()
  vim.api.nvim_command("set nohlsearch") -- Turn off search highlighting
  clear_highlights(buffer)

  -- Reset last_words to an empty table instead of nil
  M.last_words = {}

  -- Restore original filetype
  restore_original_filetype()
end

-- Store the last used words for repeat functionality
M.last_words = nil

-- Function to add a new word to existing highlighted words
function M.add_new_word(word)
  if not word or word == "" then
    -- Prompt for word if not provided
    vim.ui.input({
      prompt = "Enter word to add to colorization: ",
      default = "",
    }, function(input)
      if input and input ~= "" then
        M.add_new_word(input)
      end
    end)
    return
  end

  -- Add the new word to the existing list
  local new_words = M.last_words or {}
  table.insert(new_words, word)
  M.last_words = new_words

  -- Apply colorization with the updated list
  M.apply_colorization(new_words)

  -- Make it repeatable
  set_repeat(repeat_actions.search)
end

-- Function to get visual selection
function M.get_visual_selection()
  -- Save the current register content
  local reg_save = vim.fn.getreg('"')
  local regtype_save = vim.fn.getregtype('"')

  -- Yank the visual selection into the unnamed register
  vim.cmd('normal! gvy')

  -- Get the content of the unnamed register
  local selection = vim.fn.getreg('"')

  -- Clean up the selection - remove newlines and extra whitespace
  selection = selection:gsub("[\n\r]", " "):gsub("%s+", " "):gsub("^%s*(.-)%s*$", "%1")
  log("Visual selection (raw): '" .. vim.fn.getreg('"') .. "'")
  log("Visual selection (cleaned): '" .. selection .. "'")
  vim.fn.setreg('"', reg_save, regtype_save)
  return selection
end

-- Function to toggle a word (add or remove from highlights)
function M.toggle_word(word)
  if word and word ~= "" then
    local new_words = M.last_words or {}

    local word_index = nil
    for i, highlighted_word in ipairs(new_words) do
      if M.config.case_sensitive then
        -- Case sensitive comparison
        if highlighted_word == word then
          word_index = i
          break
        end
      else
        -- Case insensitive comparison
        if highlighted_word:lower() == word:lower() then
          word_index = i
          break
        end
      end
    end

    if word_index then
      -- Word is already highlighted, remove it
      table.remove(new_words, word_index)

      -- If this was the last word, restore original filetype
      if #new_words == 0 then
        restore_original_filetype()
      end
    else
      -- Word is not highlighted, add it
      table.insert(new_words, word)
    end

    M.last_words = new_words

    -- Apply colorization with the updated list
    if #new_words > 0 then
      M.apply_colorization(new_words)
    else
      -- Clear highlights if no words remain
      M.clear_all_highlights()
      -- Ensure last_words is an empty table rather than nil
      M.last_words = {}
    end

    -- Make it repeatable
    set_repeat(repeat_actions.search)
  end
end

-- Function to toggle word under cursor
function M.toggle_word_under_cursor()
  local word = vim.fn.expand("<cword>")
  if word and word ~= "" then
    M.toggle_word(word)
  end
end

-- Function to toggle word under cursor or selected text
function M.toggle_word_or_selection()
  local mode = vim.fn.mode()
  if mode == 'v' or mode == 'V' or mode == '\22' then -- Visual modes
    -- Exit visual mode to avoid issues
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<Esc>', true, false, true), 'nx', false)

    local selected_text = M.get_visual_selection()
    log("Mode detected: Visual")
    log("Selected text: '" .. (selected_text or "nil") .. "'")
    if selected_text and selected_text ~= "" then
      M.toggle_word(selected_text)
    end
  else
    log("Mode detected: Normal")
    M.toggle_word_under_cursor()
  end
end

-- Function to execute the colorization and make it repeatable
local function execute_colored_search(words)
  if words then
    M.last_words = words
    M.apply_colorization(words)
    -- Make it repeatable
    set_repeat(repeat_actions.search)
  end
end

-- Function to prompt for words and execute search
function M.prompt_and_search()
  -- Prepare default input with existing words if available
  local default_input = ""
  if M.last_words and #M.last_words > 0 then
    default_input = table.concat(M.last_words, " ")
  end

  vim.ui.input({
    prompt = "Enter words to colorize (space-separated): ",
    default = default_input,
    completion = "file",
  }, function(input)
    if input then
      local words = {}
      for word in input:gmatch("%S+") do
        table.insert(words, word)
      end
      execute_colored_search(words)
    end
  end)
end

-- Function to setup keymaps
local function setup_keymaps(keymaps)
  if not keymaps.enabled then
    return
  end

  -- Create the Plug mapping for repeat functionality
  vim.keymap.set('n', '<Plug>KaleidosearchRepeat', '<Cmd>lua require("kaleidosearch").repeat_last_action()<CR>',
    { silent = true })

  -- Open prompt keymap
  vim.keymap.set('n', keymaps.open, function()
    M.prompt_and_search()
  end, vim.tbl_extend("force", keymaps.opts, { desc = "KaleidoSearch: Color and search words" }))

  -- Clear keymap
  vim.keymap.set('n', keymaps.clear, function()
    M.clear_all_highlights()
  end, vim.tbl_extend("force", keymaps.opts, { desc = "KaleidoSearch: Clear colored search highlights" }))

  -- Add word keymap
  vim.keymap.set('n', keymaps.add_new_word, function()
    M.add_new_word()
  end, vim.tbl_extend("force", keymaps.opts, { desc = "KaleidoSearch: Add a word to existing highlights" }))

  -- Toggle highlight for word under cursor or visual selection keymap
  vim.keymap.set({ 'n', 'v' }, keymaps.add_cursor_word, function()
      M.toggle_word_or_selection()
    end,
    vim.tbl_extend("force", keymaps.opts, { desc = "KaleidoSearch: Toggle highlight for word under cursor or selection" }))
  -- Colorize all lines keymap
  vim.keymap.set('n', keymaps.colorize_all_lines, function()
    M.colorize_all_lines()
  end, vim.tbl_extend("force", keymaps.opts, { desc = "KaleidoSearch: Colorize all lines in the buffer" }))

  -- Colorize all vim 'word' tokens keymap
  vim.keymap.set('n', keymaps.colorize_all_words, function()
    M.colorize_all_buffer_words(true)
  end, vim.tbl_extend("force", keymaps.opts, { desc = "KaleidoSearch: Colorize all word tokens in the buffer" }))

  -- Colorize all vim 'WORD' tokens keymap
  vim.keymap.set('n', keymaps.colorize_all_WORDS, function()
    M.colorize_all_buffer_words(false)
  end, vim.tbl_extend("force", keymaps.opts, { desc = "KaleidoSearch: Colorize all WORD tokens in the buffer" }))
end

-- Setup function for plugin configuration
function M.setup(user_config)
  M.config = vim.tbl_deep_extend("force", default_config, user_config or {})

  -- Setup keymaps
  setup_keymaps(M.config.keymaps)

  -- Create commands for user interaction
  vim.api.nvim_create_user_command("Kaleidosearch", function(args)
    if args.args and args.args ~= "" then
      execute_colored_search(vim.split(args.args, " "))
    else
      M.prompt_and_search()
    end
  end, {
    nargs = "*",
    desc = "Highlight specific words with random colors",
  })

  vim.api.nvim_create_user_command("KaleidosearchClear", M.clear_all_highlights, {
    desc = "Clear all word highlights",
  })

  vim.api.nvim_create_user_command("KaleidosearchAddWord", function(args)
    if args.args and args.args ~= "" then
      M.add_new_word(args.args)
    else
      M.add_new_word()
    end
  end, {
    nargs = "?",
    desc = "Add a word to existing highlights",
  })

  vim.api.nvim_create_user_command("KaleidosearchToggleCursorWord", function()
    M.toggle_word_or_selection()
  end, {
    desc = "Toggle highlight for word under cursor or selection",
  })

  vim.api.nvim_create_user_command("KaleidosearchColorLines", function()
    M.colorize_all_lines()
  end, {
    desc = "Colorize all lines, identical lines share colors",
  })

  vim.api.nvim_create_user_command("KaleidosearchColorWords", function()
    M.colorize_all_buffer_words(true)
  end, {
    desc = "Colorize all vim 'word' tokens in the buffer",
  })

  vim.api.nvim_create_user_command("KaleidosearchColorWORDS", function()
    M.colorize_all_buffer_words(false)
  end, {
    desc = "Colorize all vim 'WORD' tokens in the buffer",
  })
end

return M
