local M = {}

-- Default configuration
local default_config = {
  highlight_group_prefix = "WordColor_",
  case_sensitive = false, -- Add case sensitivity option
  random_color_generator = function()
    local r, g, b = math.random(0, 255), math.random(0, 255), math.random(0, 255)
    return string.format("#%02x%02x%02x", r, g, b)
  end,
  sanitize_group_name = function(color)
    return color:gsub("[^a-zA-Z0-9_]", "_")
  end,
keymaps = {
  -- Set to false to disable default keymaps
  enabled = true,
  -- Default keymaps
  toggle = "<leader>cs",  -- Open input prompt for search
  clear = "<leader>cc",   -- Clear highlights
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

-- Function to save and set filetype to diff
local function set_filetype_to_diff()
  if not original_filetype then
    original_filetype = vim.bo.filetype
    vim.bo.filetype = "diff"
  end
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
    word_colors[word] = M.config.random_color_generator() -- Assign a random color if the word doesn't have one yet
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

-- Function to toggle word colorization based on user input
function M.toggle_colorize_and_search(args)
  -- If args are provided directly (via command), use them
  if args.args and args.args ~= "" then
    local words_to_colorize = vim.split(args.args, " ")
    M.apply_colorization(words_to_colorize)
    return
  end

  -- Otherwise, use dressing.nvim for input
  vim.ui.input({
    prompt = "Enter words to colorize (space-separated): ",
    default = "",
    completion = "file",
  }, function(input)
    if input then
      local words_to_colorize = vim.split(input, " ")
      M.apply_colorization(words_to_colorize)
    end
  end)
end

-- Function to apply the colorization
function M.apply_colorization(words_to_colorize)
  local buffer = vim.api.nvim_get_current_buf()

  -- Clear existing highlights
  clear_highlights(buffer)
  vim.api.nvim_command("set nohlsearch") -- Turn off search highlighting

  -- Set filetype to diff
  set_filetype_to_diff()

  -- Colorize the words
  colorize_words(buffer, words_to_colorize)

  -- Build regex pattern for search
  local case_flag = M.config.case_sensitive and "\\C" or "\\c"
  local search_pattern = "\\v" .. case_flag .. table.concat(words_to_colorize, "|")
  vim.fn.setreg("/", search_pattern) -- Set search register
  vim.api.nvim_command("nohlsearch") -- Disable default search highlighting
  print("Search pattern set: " .. search_pattern)
end

-- Function to clear all highlights
function M.clear_all_highlights()
  local buffer = vim.api.nvim_get_current_buf()
  vim.api.nvim_command("set nohlsearch") -- Turn off search highlighting
  clear_highlights(buffer)

  -- Restore original filetype
  restore_original_filetype()
end

-- Store the last used words for repeat functionality
M.last_words = nil

-- Function to execute the colorization and make it repeatable
local function execute_colored_search(words)
  if words then
    M.last_words = words
    M.apply_colorization(words)
    -- Make it repeatable
    vim.cmd([[silent! call repeat#set("\<Plug>KaleidosearchRepeat", v:count)]])
  end
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

  -- Toggle keymap - opens dressing.nvim input
  vim.keymap.set('n', keymaps.toggle, function()
    vim.ui.input({
      prompt = "Enter words to colorize (space-separated): ",
      default = "",
      completion = "file",
    }, function(input)
      if input then
        execute_colored_search(vim.split(input, " "))
      end
    end)
  end, vim.tbl_extend("force", keymaps.opts, { desc = "Color and search words" }))

  -- Clear keymap
  vim.keymap.set('n', keymaps.clear, function()
    M.clear_all_highlights()
  end, vim.tbl_extend("force", keymaps.opts, { desc = "Clear colored search highlights" }))
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
  end, {
    nargs = "*",
    desc = "Highlight specific words with random colors",
  })

  vim.api.nvim_create_user_command("KaleidosearchClear", M.clear_all_highlights, {
    desc = "Clear all word highlights",
  })
end

return M

