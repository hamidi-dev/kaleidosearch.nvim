local M = {}

M.namespace = vim.api.nvim_create_namespace('kaleidosearch_tokens')

local active = {}
local pending = {}
local jobs = {}
local generation = {}
local config = {}

local TOKEN_SPANS_SCRIPT = [=[
import json
import sys

try:
    import tiktoken

    model = sys.argv[1]
    fallback_encoding = sys.argv[2]
    text = sys.stdin.buffer.read().decode('utf-8')

    try:
        encoding = tiktoken.encoding_for_model(model)
    except KeyError:
        encoding = tiktoken.get_encoding(fallback_encoding)

    token_ids = encoding.encode(text, disallowed_special=())
    lengths = [len(encoding.decode_single_token_bytes(token_id)) for token_id in token_ids]
    print(json.dumps(lengths, separators=(',', ':')))
except Exception as exc:
    print(str(exc), file=sys.stderr)
    sys.exit(1)
]=]

local function hsl_to_rgb(h, s, l)
  if s == 0 then
    return { r = l, g = l, b = l }
  end

  local function hue_to_rgb(p, q, t)
    if t < 0 then
      t = t + 1
    end
    if t > 1 then
      t = t - 1
    end
    if t < 1 / 6 then
      return p + (q - p) * 6 * t
    end
    if t < 1 / 2 then
      return q
    end
    if t < 2 / 3 then
      return p + (2 / 3 - t) * 6 * (q - p)
    end
    return p
  end

  local q = l < 0.5 and l * (1 + s) or l + s - l * s
  local p = 2 * l - q

  return {
    r = hue_to_rgb(p, q, h + 1 / 3) * 255,
    g = hue_to_rgb(p, q, h) * 255,
    b = hue_to_rgb(p, q, h - 1 / 3) * 255,
  }
end

local function generate_color(index)
  local hue = (index * 137) % 360 / 360
  local rgb = hsl_to_rgb(hue, config.saturation, config.lightness)
  return string.format('#%02X%02X%02X', math.floor(rgb.r + 0.5), math.floor(rgb.g + 0.5), math.floor(rgb.b + 0.5))
end

local function notify(message, level)
  if config.notify == false then
    return
  end

  vim.notify(message, level or vim.log.levels.INFO, { title = 'Kaleidosearch' })
end

local function ensure_highlights()
  for index = 1, config.palette_size do
    vim.api.nvim_set_hl(0, config.highlight_group_prefix .. index, { bg = generate_color(index) })
  end
end

local function get_counter_cmd()
  if vim.fn.executable('uv') == 1 then
    return {
      'uv',
      'run',
      '--quiet',
      '--no-project',
      '--with',
      'tiktoken',
      'python',
      '-c',
      TOKEN_SPANS_SCRIPT,
      config.model,
      config.encoding,
    }
  end

  if vim.fn.executable('python3') == 1 then
    return { 'python3', '-c', TOKEN_SPANS_SCRIPT, config.model, config.encoding }
  end

  if vim.fn.executable('python') == 1 then
    return { 'python', '-c', TOKEN_SPANS_SCRIPT, config.model, config.encoding }
  end

  return nil
end

local function get_buffer_text(bufnr)
  return table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), '\n')
end

local function decode_json(text)
  if vim.json and vim.json.decode then
    return vim.json.decode(text)
  end

  return vim.fn.json_decode(text)
end

local function get_line_starts(bufnr)
  local starts = {}
  local offset = 0
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  for row, line in ipairs(lines) do
    starts[row] = offset
    offset = offset + #line + 1
  end

  return starts, lines
end

local function offset_to_position(offset, line_starts, lines)
  local low = 1
  local high = #line_starts
  local row = 1

  while low <= high do
    local mid = math.floor((low + high) / 2)
    if line_starts[mid] <= offset then
      row = mid
      low = mid + 1
    else
      high = mid - 1
    end
  end

  local col = offset - line_starts[row]
  local max_col = #(lines[row] or '')
  if col > max_col then
    col = max_col
  end

  return row - 1, col
end

function M.clear(bufnr, opts)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  opts = opts or {}

  if vim.api.nvim_buf_is_valid(bufnr) then
    vim.api.nvim_buf_clear_namespace(bufnr, M.namespace, 0, -1)
  end

  if jobs[bufnr] then
    vim.fn.jobstop(jobs[bufnr])
    jobs[bufnr] = nil
  end

  generation[bufnr] = (generation[bufnr] or 0) + 1
  active[bufnr] = nil
  pending[bufnr] = nil

  if not opts.silent then
    notify('Token colors cleared')
  end
end

local function apply_lengths(bufnr, lengths)
  ensure_highlights()
  vim.api.nvim_buf_clear_namespace(bufnr, M.namespace, 0, -1)

  local line_starts, lines = get_line_starts(bufnr)
  local offset = 0
  local applied = 0

  for index, length in ipairs(lengths) do
    if type(length) == 'number' and length > 0 then
      local start_row, start_col = offset_to_position(offset, line_starts, lines)
      local end_row, end_col = offset_to_position(offset + length, line_starts, lines)

      if start_row ~= end_row or start_col ~= end_col then
        vim.api.nvim_buf_set_extmark(bufnr, M.namespace, start_row, start_col, {
          end_row = end_row,
          end_col = end_col,
          hl_group = config.highlight_group_prefix .. (((index - 1) % config.palette_size) + 1),
          priority = config.priority,
        })
        applied = applied + 1
      end

      offset = offset + length
    end
  end

  active[bufnr] = true
  notify(('Colored %d tiktoken tokens'):format(applied))
end

function M.colorize(opts)
  opts = opts or {}

  if config.enabled == false then
    notify('Token colors are disabled', vim.log.levels.WARN)
    return false
  end

  local bufnr = vim.api.nvim_get_current_buf()
  if vim.bo[bufnr].buftype ~= '' then
    notify('Token colors only work for normal buffers', vim.log.levels.WARN)
    return false
  end

  local text = get_buffer_text(bufnr)
  local force = opts.force == true

  if #text > config.max_bytes and not force then
    notify(('Token colors skipped: buffer is %.1f KB; use :KaleidosearchColorTokens! to force'):format(#text / 1024), vim.log.levels.WARN)
    return false
  end

  local cmd = get_counter_cmd()
  if not cmd then
    notify('Token colors need uv, python3, or python with tiktoken', vim.log.levels.ERROR)
    return false
  end

  generation[bufnr] = (generation[bufnr] or 0) + 1
  local current_generation = generation[bufnr]
  pending[bufnr] = current_generation

  local stdout = {}
  local stderr = {}
  local job_id
  job_id = vim.fn.jobstart(cmd, {
    stdin = 'pipe',
    stdout_buffered = true,
    stderr_buffered = true,
    on_stdout = function(_, data)
      stdout = data or {}
    end,
    on_stderr = function(_, data)
      stderr = data or {}
    end,
    on_exit = function(_, code)
      vim.schedule(function()
        if jobs[bufnr] == job_id then
          jobs[bufnr] = nil
        end

        if pending[bufnr] == current_generation then
          pending[bufnr] = nil
        end

        if not vim.api.nvim_buf_is_valid(bufnr) or generation[bufnr] ~= current_generation then
          return
        end

        if code ~= 0 then
          notify('Token color tokenizer failed: ' .. table.concat(stderr, ' '), vim.log.levels.ERROR)
          return
        end

        local ok, lengths = pcall(decode_json, table.concat(stdout, ''))
        if not ok or type(lengths) ~= 'table' then
          notify('Token color tokenizer returned invalid JSON', vim.log.levels.ERROR)
          return
        end

        if #lengths > config.max_highlights and not force then
          notify(('Token colors skipped: %d tokens; use :KaleidosearchColorTokens! to force'):format(#lengths), vim.log.levels.WARN)
          return
        end

        apply_lengths(bufnr, lengths)
      end)
    end,
  })

  if job_id <= 0 then
    active[bufnr] = nil
    pending[bufnr] = nil
    notify('Failed to start token color tokenizer', vim.log.levels.ERROR)
    return false
  end

  jobs[bufnr] = job_id
  vim.fn.chansend(job_id, text)
  vim.fn.chanclose(job_id, 'stdin')
  return true
end

function M.toggle()
  local bufnr = vim.api.nvim_get_current_buf()
  if active[bufnr] or pending[bufnr] then
    M.clear(bufnr)
    return true
  end

  return M.colorize()
end

function M.is_active(bufnr)
  return active[bufnr or vim.api.nvim_get_current_buf()] == true
end

function M.setup(user_config)
  config = vim.tbl_deep_extend('force', {
    enabled = true,
    model = 'gpt-4o',
    encoding = 'o200k_base',
    max_bytes = 200 * 1024,
    max_highlights = 20000,
    palette_size = 32,
    saturation = 0.55,
    lightness = 0.24,
    priority = 120,
    notify = true,
    highlight_group_prefix = 'KaleidosearchToken',
  }, user_config or {})

  local group = vim.api.nvim_create_augroup('KaleidosearchTokens', { clear = true })
  vim.api.nvim_create_autocmd({ 'TextChanged', 'TextChangedI', 'TextChangedT' }, {
    group = group,
    callback = function(args)
      if active[args.buf] or pending[args.buf] then
        M.clear(args.buf, { silent = true })
      end
    end,
  })

  vim.api.nvim_create_autocmd({ 'BufDelete', 'BufWipeout' }, {
    group = group,
    callback = function(args)
      if jobs[args.buf] then
        vim.fn.jobstop(jobs[args.buf])
      end
      active[args.buf] = nil
      pending[args.buf] = nil
      jobs[args.buf] = nil
      generation[args.buf] = nil
    end,
  })
end

return M
