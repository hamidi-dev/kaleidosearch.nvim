-- KaleidoSearch dimmed non-match highlighting.
--
-- Implements the "custom color / gray for non-highlighted words" feature
-- requested in issue #5: text that is not part of a search match is drawn
-- in a dark gray color by default, which is easier on the eyes and
-- increases the contrast between matches and non-matches (similar to the
-- `flash` plugin). The color can be customized, e.g.:
--
--     require('kaleidosearch').setup({
--       unmatched_color = '#4b4b4b',
--     })
--
-- Integration note: call `M.dim_unmatched()` *before* the KaleidoSearch match
-- highlights are (re)added on every refresh so that the match highlights
-- take precedence on the matched regions.

local M = {}

local HIGHLIGHT_GROUP = 'KaleidoSearchUnmatched'

-- Dark gray: dimmed, but still readable.
local DEFAULT_UNMATCHED_COLOR = '#3d3d3d'

local default_opts = {
  -- Set to `false` to keep the default text color for non-matches.
  unmatched_enabled = true,
  unmatched_color = DEFAULT_UNMATCHED_COLOR,
}

local opts = default_opts

-- Id of the currently active dim match, or `nil` when inactive.
local dim_match_id = nil

--- Configure the non-match highlighting.
---@param options table|nil
---@return table M
function M.setup(options)
  opts = vim.tbl_deep_extend('force', default_opts, options or {})
  return M
end

--- (Re)create the `KaleidoSearchUnmatched` highlight group using the color
--- from the current configuration.
function M.refresh_group()
  vim.api.nvim_set_hl(0, HIGHLIGHT_GROUP, {
    fg = opts.unmatched_color,
  })
end

--- Remove the dim match from the buffer if it is active.
function M.clear()
  if dim_match_id ~= nil then
    vim.fn.matchdelete(dim_match_id)
    dim_match_id = nil
  end
end

--- Dim every text of the current buffer that is not covered by a match.
---
--- A whole-line match is added with the `KaleidoSearchUnmatched` group.
--- KaleidoSearch (re)adds its match highlights after this call, so they
--- take precedence on the matched regions and only the non-matched text
--- remains dimmed.
function M.dim_unmatched()
  if not opts.unmatched_enabled then
    M.clear()
    return
  end

  M.clear()
  M.refresh_group()

  -- `.*` spans the full content of every line; the KaleidoSearch matches
  -- are added on top afterwards.
  dim_match_id = vim.fn.matchadd(HIGHLIGHT_GROUP, '.*', 1)
end

return M
