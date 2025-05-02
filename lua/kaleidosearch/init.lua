local M = {}

-- Color palette for distinct colors
local color_palette = {
  "#FF6B6B", -- Red
  "#4ECDC4", -- Teal
  "#45B7D1", -- Light Blue
  "#96CEB4", -- Sage Green
  "#FFEEAD", -- Light Yellow
  "#D4A5A5", -- Dusty Rose
  "#9B59B6", -- Purple
  "#3498DB", -- Blue
  "#E67E22", -- Orange
  "#2ECC71", -- Green
  "#F1C40F", -- Yellow
  "#E74C3C", -- Crimson
  "#1ABC9C", -- Turquoise
  "#9B59B6", -- Violet
  "#34495E", -- Navy Blue
}

local current_color_index = 0

-- Default configuration
local default_config = {
  highlight_group_prefix = "WordColor_",
  case_sensitive = false, -- Add case sensitivity option
  get_next_color = function()
    current_color_index = (current_color_index % #color_palette) + 1
    return color_palette[current_color_index]
  end,
  sanitize_group_name = function(color)
    return color:gsub("[^a-zA-Z0-9_]", "_")
  end,
  keymaps = {
    -- Set to false to disable default keymaps
    enabled = true,
    -- Default keymaps
    open = "<leader>cs",            -- Open input prompt for search
    clear = "<leader>cc",           -- Clear highlights
    add_new_word = "<leader>cn",    -- Add a new word to existing highlights
    add_cursor_word = "<leader>ca", -- Add word under cursor to highlights
    -- Additional options for keymaps
    opts = {
      noremap = true,
      silent = true,
    }
  }
}

-- Configuration table
M.config = {}

-- Table to store colors for each word
local word_colors = {}

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
local function clear_highlights(buffer)
  vim.api.nvim_buf_clear_namespace(buffer, 0, 0, -1)
  word_colors = {}
end

-- Function to highlight a specific word in the buffer
local function highlight_word(buffer, word, line_nr, word_start, word_end)
  if not word_colors[word] then
    word_colors[word] = M.config.get_next_color() -- Assign the next color from the palette if the word doesn't have one yet
  end
  local color = word_colors[word]
  local group_name = M.config.highlight_group_prefix .. M.config.sanitize_group_name(color)
  vim.api.nvim_command("highlight " .. group_name .. " guifg=" .. color)
  vim.api.nvim_buf_add_highlight(buffer, 0, group_name, line_nr - 1, word_start - 1, word_end)
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

      local start_pos = 1
      while true do
        local word_start, word_end = search_line:find(pattern, start_pos, true)
        if not word_start then break end
        -- Use the original line for highlighting to preserve case
        local original_word = line:sub(word_start, word_end)
        highlight_word(buffer, original_word, line_nr, word_start, word_end)
        start_pos = word_end + 1
      end
    end
  end
end

-- Function to apply the colorization
function M.apply_colorization(words_to_colorize)
  if not words_to_colorize or #words_to_colorize == 0 then
    return
  end

  local buffer = vim.api.nvim_get_current_buf()

  -- Clear existing highlights
  clear_highlights(buffer)
  vim.api.nvim_command("set nohlsearch") -- Turn off search highlighting

  -- Set filetype to txt - always do this when applying colorization
  set_filetype_to_txt()

  -- Colorize the words
  colorize_words(buffer, words_to_colorize)

  -- Build regex pattern for search
  local case_flag = M.config.case_sensitive and "\\C" or "\\c"
  local search_pattern = "\\v" .. case_flag .. table.concat(words_to_colorize, "|")
  vim.fn.setreg("/", search_pattern) -- Set search register
  vim.api.nvim_command("nohlsearch") -- Disable default search highlighting
  print("Search pattern set: " .. search_pattern)

  -- Store the words for later use
  M.last_words = words_to_colorize
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
  vim.cmd([[silent! call repeat#set("\<Plug>KaleidosearchRepeat", v:count)]])
end

-- Function to add word under cursor to colorization or remove it if already highlighted
function M.toggle_word_under_cursor()
  local word = vim.fn.expand("<cword>")
  if word and word ~= "" then
    local new_words = M.last_words or {}

    -- Check if the word is already highlighted
    local word_index = nil
    for i, highlighted_word in ipairs(new_words) do
      if highlighted_word == word then
        word_index = i
        break
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
    vim.cmd([[silent! call repeat#set("\<Plug>KaleidosearchRepeat", v:count)]])
  end
end

-- Function to execute the colorization and make it repeatable
local function execute_colored_search(words)
  if words then
    M.last_words = words
    M.apply_colorization(words)
    -- Make it repeatable
    vim.cmd([[silent! call repeat#set("\<Plug>KaleidosearchRepeat", v:count)]])
  end
end

-- Function to prompt for words and execute search
function M.prompt_and_search()
  vim.ui.input({
    prompt = "Enter words to colorize (space-separated): ",
    default = "",
    completion = "file",
  }, function(input)
    if input then
      execute_colored_search(vim.split(input, " "))
    end
  end)
end

-- Function to setup keymaps
local function setup_keymaps(keymaps)
  if not keymaps.enabled then
    return
  end

  -- Create the Plug mapping for repeat functionality
  vim.keymap.set('n', '<Plug>KaleidosearchRepeat', function()
    if M.last_words then
      execute_colored_search(M.last_words)
    end
  end, { silent = true })

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

  -- Toggle highlight for word under cursor keymap
  vim.keymap.set('n', keymaps.add_cursor_word, function()
    M.toggle_word_under_cursor()
  end, vim.tbl_extend("force", keymaps.opts, { desc = "KaleidoSearch: Toggle highlight for word under cursor" }))
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

  vim.api.nvim_create_user_command("KaleidosearchToggleCursorWord", M.toggle_word_under_cursor, {
    desc = "Toggle highlight for word under cursor",
  })
end

return M
