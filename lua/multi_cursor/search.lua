local M = {}

---@return MultiCursorPosTuple
local function win_cursor_pos()
  local p = vim.api.nvim_win_get_cursor(0)
  return { p[1] - 1, p[2] }
end

---@generic T
---@param row integer
---@param col integer
---@param fn fun():T
---@return T
local function with_cursor(row, col, fn)
  local save = vim.api.nvim_win_get_cursor(0)
  vim.api.nvim_win_set_cursor(0, { row + 1, col })
  local ok, out = pcall(fn)
  vim.api.nvim_win_set_cursor(0, save)
  if not ok then
    error(out)
  end
  return out
end

---@param text string
---@return string
function M.escape_literal(text)
  return vim.fn.escape(text, '\\/.*$^~[]')
end

---@return string|nil
function M.word_pattern()
  local w = vim.fn.expand('<cword>')
  if w == nil or w == '' then
    return nil
  end
  return [[\V\<]] .. M.escape_literal(w) .. [[\>]]
end

---@return MultiCursorWordStartTuple|nil
function M.current_word_start()
  local pat = M.word_pattern()
  if not pat then
    return nil
  end
  local cur = win_cursor_pos()
  return with_cursor(cur[1], cur[2], function()
    local pos = vim.fn.searchpos(pat, 'cnW')
    if pos[1] == 0 then
      return nil
    end
    return { pos[1] - 1, pos[2] - 1, pat }
  end)
end

---@param row integer
---@param col integer
---@param pat string
---@param backward boolean
---@return MultiCursorPosTuple|nil
function M.find_from(row, col, pat, backward)
  -- Match VM behavior: searches follow Vim's wrapscan semantics.
  local flags = backward and 'bn' or 'n'
  return with_cursor(row, col, function()
    local pos = vim.fn.searchpos(pat, flags)
    if pos[1] == 0 then
      return nil
    end
    return { pos[1] - 1, pos[2] - 1 }
  end)
end

---@param bufnr integer
---@param pat string
---@return table[]
function M.buffer_matches(bufnr, pat)
  local out = {}
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  for row, line in ipairs(lines) do
    local s = 0
    while true do
      local m = vim.fn.matchstrpos(line, pat, s)
      local text = m[1]
      local start_col = m[2]
      local end_col = m[3]
      if text == '' or start_col < 0 then
        break
      end
      table.insert(out, { row = row - 1, col = start_col })
      s = math.max(end_col, start_col + 1)
    end
  end
  return out
end

---@param bufnr integer
---@param pat string
---@param start_row integer
---@param start_col integer
---@param end_row integer
---@param end_col integer
---@return table[]
function M.buffer_matches_in_range(bufnr, pat, start_row, start_col, end_row, end_col)
  local out = {}
  if start_row > end_row or (start_row == end_row and start_col > end_col) then
    start_row, end_row = end_row, start_row
    start_col, end_col = end_col, start_col
  end

  local lines = vim.api.nvim_buf_get_lines(bufnr, start_row, end_row + 1, false)
  for off, line in ipairs(lines) do
    local row = start_row + off - 1
    local s = 0
    local row_min = (row == start_row) and start_col or 0
    local row_max = (row == end_row) and end_col or #line
    while true do
      local m = vim.fn.matchstrpos(line, pat, s)
      local text = m[1]
      local sc = m[2]
      local ec = m[3]
      if text == '' or sc < 0 then
        break
      end
      if sc >= row_min and sc <= row_max then
        table.insert(out, { row = row, col = sc })
      end
      s = math.max(ec, sc + 1)
      if s > row_max then
        break
      end
    end
  end
  return out
end

return M
