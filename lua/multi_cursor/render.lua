local config = require('multi_cursor.config')
local state_mod = require('multi_cursor.state')

---@class MultiCursorRenderModule
---@field ns integer
---@field sync fun(state: MultiCursorState, event: string|nil)
local M = {}
M.ns = vim.api.nvim_create_namespace('multi_cursor.nvim.render')

---@param bufnr integer
---@param row integer
---@param col integer
---@return integer
local function clamp_col(bufnr, row, col)
  local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1] or ''
  local max_col = #line
  if col < 0 then
    return 0
  end
  if col > max_col then
    return max_col
  end
  return col
end

---@param bufnr integer
---@param row integer
---@param col integer
---@param hl string
local function draw_cursor(bufnr, row, col, hl)
  local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1] or ''
  local line_len = #line
  if line_len == 0 then
    vim.api.nvim_buf_set_extmark(bufnr, M.ns, row, 0, {
      virt_text = { { ' ', hl } },
      virt_text_pos = 'overlay',
      priority = 250,
    })
    return
  end
  local s = clamp_col(bufnr, row, col)
  if s >= line_len then
    s = line_len - 1
  end
  local e = s + 1
  vim.api.nvim_buf_set_extmark(bufnr, M.ns, row, s, {
    end_row = row,
    end_col = e,
    hl_group = hl,
    priority = 250,
  })
end

---@param bufnr integer
---@param p MultiCursorCursorPos
---@param hl string
local function draw_selection(bufnr, p, hl)
  local sr, sc, er, ec = p.arow, p.acol, p.row, p.col
  if sr > er or (sr == er and sc > ec) then
    sr, er = er, sr
    sc, ec = ec, sc
  end
  if sr == er and sc == ec then
    return
  end
  if sr == er then
    vim.api.nvim_buf_set_extmark(bufnr, M.ns, sr, sc, {
      end_row = er,
      end_col = math.max(ec, sc + 1),
      hl_group = hl,
      priority = 200,
    })
    return
  end
  vim.api.nvim_buf_set_extmark(bufnr, M.ns, sr, sc, {
    end_row = er,
    end_col = ec,
    hl_group = hl,
    priority = 200,
  })
end

---@param state MultiCursorState
---@param event string|nil
local function sync_statusline(state, event)
  local setting = tonumber(config.values.set_statusline) or 0
  if setting <= 0 then
    return
  end
  if not state.enabled or #state.cursors == 0 then
    if state.statusline_initialized and state.statusline_prev ~= nil then
      vim.wo.statusline = state.statusline_prev
      state.statusline_initialized = false
      state.statusline_prev = nil
    end
    return
  end
  if not state.statusline_initialized then
    state.statusline_prev = vim.wo.statusline
    state.statusline_initialized = true
  end
  if event ~= nil then
    if setting == 1 then
      return
    end
    if setting == 2 and event ~= 'CursorHold' then
      return
    end
    if setting >= 3 and event ~= 'CursorHold' and event ~= 'CursorMoved' then
      return
    end
  end
  vim.wo.statusline =
    string.format('[MultiCursor %s %d/%d]', state.mode, state.current, #state.cursors)
end

---@param state MultiCursorState
---@param event string|nil
function M.sync(state, event)
  vim.api.nvim_buf_clear_namespace(state.bufnr, M.ns, 0, -1)
  sync_statusline(state, event)
  if not state.enabled or #state.cursors == 0 then
    return
  end

  local hls = config.values.highlights
  local from_i, to_i = 1, #state.cursors
  if state.single_region and #state.cursors > 0 then
    from_i = state.current
    to_i = state.current
  end
  for i = from_i, to_i do
    local p = state_mod.cursor_pos(state, i)
    if p then
      if state.mode == 'extend' then
        draw_selection(state.bufnr, p, hls.extend)
      end
      local insert_hl = hls.insert or hls.cursor
      local hl = i == state.current and hls.mono or hls.cursor
      if state.insert_active then
        hl = insert_hl
      end
      draw_cursor(state.bufnr, p.row, p.col, hl)
    end
  end
end

return M
