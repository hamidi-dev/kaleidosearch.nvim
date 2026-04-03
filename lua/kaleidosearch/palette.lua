local M = {}

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
      return p + (q - p) * (2 / 3 - t) * 6
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

local function generate_color(index, palette_shift)
  local hue = ((index + palette_shift) * 137) % 360 / 360
  local rgb = hsl_to_rgb(hue, 0.5, 0.5)
  local r = math.floor(rgb.r + 0.5)
  local g = math.floor(rgb.g + 0.5)
  local b = math.floor(rgb.b + 0.5)
  return string.format('#%02X%02X%02X', r, g, b)
end

local function clear_table(tbl)
  for key in pairs(tbl) do
    tbl[key] = nil
  end
end

function M.start_new_palette(buf_state)
  buf_state.current_color_index = 0
  buf_state.palette_shift = (buf_state.palette_shift + 29) % 360
  clear_table(buf_state.used_colors)
end

function M.next_color(buf_state)
  buf_state.current_color_index = buf_state.current_color_index + 1
  local new_color = generate_color(buf_state.current_color_index, buf_state.palette_shift)
  table.insert(buf_state.used_colors, new_color)
  return new_color
end

return M
