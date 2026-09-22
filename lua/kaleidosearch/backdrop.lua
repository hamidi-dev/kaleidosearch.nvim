local state = require('kaleidosearch.state')

local M = {}

function M.setup()
  local function define_highlight()
    vim.api.nvim_set_hl(0, 'KaleidosearchBackdrop', { default = true, link = 'Comment' })
  end

  define_highlight()
  vim.api.nvim_create_autocmd('ColorScheme', {
    group = vim.api.nvim_create_augroup('KaleidosearchBackdrop', { clear = true }),
    callback = define_highlight,
  })
end

function M.apply(buffer, config)
  if not config.enabled then
    return
  end

  -- Share the search namespace so clearing or changing modes removes the backdrop too.
  vim.api.nvim_buf_set_extmark(buffer, state.namespace, 0, 0, {
    end_row = vim.api.nvim_buf_line_count(buffer),
    end_col = 0,
    hl_group = config.highlight_group,
    priority = 1, -- Below the colored word highlights.
    right_gravity = false,
    end_right_gravity = true,
  })
end

return M
