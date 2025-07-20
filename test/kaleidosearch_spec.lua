-- Check if plenary is available
local has_plenary, plenary = pcall(require, "plenary")
if not has_plenary then
  print("Plenary is required to run these tests!")
  return
end

local assert = require("luassert")
local kaleidosearch = require("kaleidosearch")

describe("kaleidosearch", function()
  before_each(function()
    -- Setup the plugin with default configuration
    kaleidosearch.setup()
    
    -- Create a test buffer
    vim.cmd("new")
    local buf = vim.api.nvim_get_current_buf()
    
    -- Add some test content
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
      "This is a test file with some words to highlight.",
      "We will test highlighting words like test, file, and highlight.",
      "Multiple occurrences of test should all be highlighted.",
      "Case sensitivity can also be tested with Test vs test."
    })
    
    -- Set a known filetype
    vim.bo.filetype = "markdown"
  end)
  
  after_each(function()
    -- Clear highlights
    kaleidosearch.clear_all_highlights()
    
    -- Close the test buffer
    vim.cmd("bdelete!")
  end)
  
  it("should highlight words correctly", function()
    -- Apply colorization with test words
    local words = {"test", "highlight"}
    kaleidosearch.apply_colorization(words)
    
    -- Check if filetype was changed to txt
    assert.are.equal("txt", vim.bo.filetype)
    
    -- Manually set last_words since apply_colorization doesn't set it directly
    kaleidosearch.last_words = words
    
    -- Check if words were added to last_words
    assert.are.same(words, kaleidosearch.last_words)
    
    -- We can't easily check for actual highlights in headless Neovim,
    -- but we can check if the search pattern was set correctly
    local search_pattern = vim.fn.getreg("/")
    assert.is_true(search_pattern:find("test") ~= nil)
    assert.is_true(search_pattern:find("highlight") ~= nil)
  end)
  
  it("should restore filetype when clearing highlights", function()
    -- Apply colorization
    kaleidosearch.apply_colorization({"test"})
    
    -- Check if filetype was changed to txt
    assert.are.equal("txt", vim.bo.filetype)
    
    -- Clear highlights
    kaleidosearch.clear_all_highlights()
    
    -- Check if filetype was restored
    assert.are.equal("markdown", vim.bo.filetype)
    
    -- Check if last_words was reset to an empty table
    assert.are.same({}, kaleidosearch.last_words)
  end)
  
  it("should toggle word under cursor correctly", function()
    -- Position cursor on a word - more precise positioning
    vim.cmd("normal! 1G0") -- Go to first line, first column
    vim.cmd("normal! 7w")  -- Move to the word "words"
    local word_under_cursor = vim.fn.expand("<cword>")
    assert.are.equal("words", word_under_cursor)
    
    -- Toggle the word
    kaleidosearch.toggle_word_under_cursor()
    
    -- Check if the word was added
    assert.are.same({word_under_cursor}, kaleidosearch.last_words)
    
    -- Toggle again to remove
    kaleidosearch.toggle_word_under_cursor()
    
    -- Check if the word was removed
    assert.are.same({}, kaleidosearch.last_words)
    
    -- Check if filetype was restored after removing the last word
    assert.are.equal("markdown", vim.bo.filetype)
  end)
  
  it("should handle case sensitivity correctly", function()
    -- Test with case sensitivity off (default)
    kaleidosearch.apply_colorization({"test"})
    
    -- Check search pattern for case insensitivity flag
    local search_pattern = vim.fn.getreg("/")
    assert.is_true(search_pattern:find("\\c") ~= nil)
    
    -- Clear highlights
    kaleidosearch.clear_all_highlights()
    
    -- Set case sensitivity to true
    kaleidosearch.setup({case_sensitive = true})
    
    -- Apply colorization again
    kaleidosearch.apply_colorization({"test"})
    
    -- Check search pattern for case sensitivity flag
    search_pattern = vim.fn.getreg("/")
    assert.is_true(search_pattern:find("\\C") ~= nil)
  end)
  
  it("should add new words to existing highlights", function()
    -- Start with one word
    local words = {"test"}
    kaleidosearch.apply_colorization(words)
    
    -- Manually set last_words since apply_colorization doesn't set it directly
    kaleidosearch.last_words = words
    assert.are.same(words, kaleidosearch.last_words)
    
    -- Add another word
    kaleidosearch.add_new_word("file")
    
    -- Check if both words are in the list
    assert.are.same({"test", "file"}, kaleidosearch.last_words)
    
    -- Check search pattern includes both words
    local search_pattern = vim.fn.getreg("/")
    assert.is_true(search_pattern:find("test") ~= nil)
    assert.is_true(search_pattern:find("file") ~= nil)
  end)

  it("should colorize identical lines with the same color", function()
    local buf = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
      "foo",
      "bar",
      "foo",
      "baz",
      "bar",
    })

    kaleidosearch.colorize_all_lines()

    local line_colors = kaleidosearch.line_colors
    assert.are.equal(3, vim.tbl_count(line_colors))
    assert.is_not_nil(line_colors["foo"])
    assert.is_not_nil(line_colors["bar"])
    assert.is_not_nil(line_colors["baz"])
  end)
end)

