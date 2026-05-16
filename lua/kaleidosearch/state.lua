local M = {}

M.namespace = vim.api.nvim_create_namespace('kaleidosearch')

local buffer_states = {}

local function clear_table(tbl)
  for key in pairs(tbl) do
    tbl[key] = nil
  end
end

local function new_buffer_state()
  return {
    word_colors = {},
    line_colors = {},
    original_filetype = nil,
    last_words = {},
    repeat_action = nil,
    token_colors_force = false,
    used_colors = {},
    current_color_index = 0,
    palette_shift = 0,
  }
end

function M.get(buffer)
  local bufnr = buffer or vim.api.nvim_get_current_buf()
  if not buffer_states[bufnr] then
    buffer_states[bufnr] = new_buffer_state()
  end
  return buffer_states[bufnr]
end

function M.clear_highlights(buffer, buf_state)
  local state = buf_state or M.get(buffer)
  vim.api.nvim_buf_clear_namespace(buffer, M.namespace, 0, -1)
  clear_table(state.word_colors)
  clear_table(state.line_colors)
end

function M.set_filetype_to_txt(buffer, buf_state)
  local state = buf_state or M.get(buffer)
  if not state.original_filetype or state.original_filetype == '' then
    state.original_filetype = vim.bo[buffer].filetype
  end
  vim.bo[buffer].filetype = 'txt'
end

function M.restore_original_filetype(buffer, buf_state)
  local state = buf_state or M.get(buffer)
  if state.original_filetype then
    vim.bo[buffer].filetype = state.original_filetype
    state.original_filetype = nil
  end
end

function M.delete(buffer)
  buffer_states[buffer] = nil
end

function M.setup_autocmds(on_buf_enter)
  local group = vim.api.nvim_create_augroup('KaleidosearchState', { clear = true })

  vim.api.nvim_create_autocmd('BufEnter', {
    group = group,
    callback = function(args)
      if on_buf_enter then
        on_buf_enter(args.buf, M.get(args.buf))
      end
    end,
  })

  vim.api.nvim_create_autocmd({ 'BufDelete', 'BufWipeout' }, {
    group = group,
    callback = function(args)
      M.delete(args.buf)
    end,
  })
end

return M
