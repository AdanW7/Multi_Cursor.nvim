local config = require('multi_cursor.config')
local state_mod = require('multi_cursor.state')
local render = require('multi_cursor.render')
local search = require('multi_cursor.search')
local picker = require('multi_cursor.picker')

---@class MultiCursorActionsModule
local M = {}
local run_menu
local is_extended

---@param bufnr integer
---@param row integer
---@return integer
local function line_len(bufnr, row)
  local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1] or ''
  return #line
end

---@param bufnr integer
---@param row integer
---@param col integer
---@return integer
local function clamp(bufnr, row, col)
  local max_col = line_len(bufnr, row)
  if col < 0 then
    return 0
  end
  if col > max_col then
    return max_col
  end
  return col
end

---@param state MultiCursorState
local function focus_current(state)
  local p = state_mod.cursor_pos(state, state.current)
  if p then
    local row = math.max(1, math.min(p.row + 1, vim.api.nvim_buf_line_count(state.bufnr)))
    local col = clamp(state.bufnr, row - 1, p.col)
    vim.api.nvim_win_set_cursor(0, { row, col })
  end
end

---@param state MultiCursorState
local function ensure_started(state)
  if #state.cursors > 0 then
    return
  end
  local p = vim.api.nvim_win_get_cursor(0)
  state_mod.add_cursor(state, p[1] - 1, p[2], {})
end

---@param state MultiCursorState
local function ensure_anchor_for_cursor_mode(state)
  if state.mode ~= 'cursor' then
    return
  end
  for i = 1, #state.cursors do
    local p = state_mod.cursor_pos(state, i)
    if p then
      state_mod.set_anchor(state, i, p.row, p.col)
    end
  end
end

---@param state MultiCursorState
---@param spec table|nil
local function remember_dot(state, spec)
  state.last_dot = spec
end

---@param spec table|nil
function M.set_last_dot(spec)
  local state = state_mod.current()
  remember_dot(state, spec)
end

---@param state MultiCursorState
---@param asc boolean
---@return integer[]
local function sorted_indices(state, asc)
  if state.single_region and #state.cursors > 0 then
    return { math.max(1, math.min(state.current, #state.cursors)) }
  end
  return asc and state_mod.sort_indices_asc(state) or state_mod.sort_indices_desc(state)
end

---@param state MultiCursorState
local function finalize(state)
  ensure_anchor_for_cursor_mode(state)
  render.sync(state)
  focus_current(state)
end

---@param state MultiCursorState
---@return boolean
local function should_reindent(state)
  local ft = vim.bo[state.bufnr].filetype
  if ft == nil or ft == '' then
    return false
  end
  local list = config.values.reindent_filetypes
  if type(list) ~= 'table' then
    return false
  end
  for _, v in ipairs(list) do
    if v == ft then
      return true
    end
  end
  return false
end

---@return nil
function M.clear()
  local state = state_mod.current()
  local had_enabled = state.enabled and #state.cursors > 0
  if state.statusline_initialized and state.statusline_prev ~= nil then
    vim.wo.statusline = state.statusline_prev
  end
  state_mod.clear(state)
  render.sync(state)
  if had_enabled and not config.values.silent_exit then
    vim.notify('Exited MultiCursor.', vim.log.levels.INFO)
  end
end

---@return nil
function M.reselect_last()
  local state = state_mod.current()
  local last = vim.deepcopy(state.last_cursors or {})
  state_mod.clear(state)
  state.last_cursors = last
  if state_mod.restore_last(state) then
    finalize(state)
  end
end

---@return nil
function M.add_cursor_at_pos()
  local state = state_mod.current()
  local p = vim.api.nvim_win_get_cursor(0)
  local was_empty = #state.cursors == 0
  state_mod.add_cursor(state, p[1] - 1, p[2], { toggle = true })
  if was_empty and #state.cursors > 0 and config.values.add_cursor_at_pos_no_mappings then
    state.maps_enabled = false
  end
  finalize(state)
end

---@param update_search boolean|nil
---@return nil
function M.add_cursor_at_word(update_search)
  local state = state_mod.current()
  local found = search.current_word_start()
  if not found then
    return false
  end
  local row, col, pat = found[1], found[2], found[3]
  if update_search then
    state.search = { pat }
  end
  state_mod.add_cursor(state, row, col, {})
  finalize(state)
  return true
end

---@param delta integer
---@param count integer|nil
---@return nil
function M.add_cursor_vertical(delta, count)
  local state = state_mod.current()
  ensure_started(state)
  count = count or vim.v.count1

  local current = state_mod.cursor_pos(state, state.current)
  if not current then
    return
  end
  local target_col = current.col
  local row = current.row
  local max_row = vim.api.nvim_buf_line_count(state.bufnr) - 1

  local added = 0
  while added < count do
    row = row + delta
    if row < 0 or row > max_row then
      break
    end

    local len = line_len(state.bufnr, row)
    local is_empty_line = len == 0
    local skip = false
    if is_empty_line then
      -- Vertical cursor placement should skip truly empty lines.
      skip = true
    elseif config.values.skip_shorter_lines then
      if target_col > len then
        skip = true
      end
    end

    if not skip then
      state_mod.add_cursor(state, row, clamp(state.bufnr, row, target_col), {})
      added = added + 1
    end
  end

  finalize(state)
end

local function clear_native_search_highlight()
  pcall(function()
    vim.cmd('silent! nohlsearch')
  end)
end

---@return nil
function M.toggle_mode()
  local state = state_mod.current()
  if #state.cursors == 0 then
    return
  end
  state.mode = (state.mode == 'cursor') and 'extend' or 'cursor'
  state.extend_manual = state.mode == 'extend'
  if state.mode == 'cursor' then
    ensure_anchor_for_cursor_mode(state)
  end
  finalize(state)
end

---@return nil
function M.toggle_single_region()
  local state = state_mod.current()
  ensure_started(state)
  state.single_region = not state.single_region
  if state.single_region then
    state.current = math.max(1, math.min(state.current, #state.cursors))
  end
  finalize(state)
end

---@param delta integer
---@return nil
function M.goto_region(delta)
  local state = state_mod.current()
  if #state.cursors == 0 then
    return
  end
  local n = #state.cursors
  state.current = ((state.current - 1 + delta) % n) + 1
  finalize(state)
end

---@param delta integer
---@return nil
function M.seek_region(delta)
  M.goto_region(delta)
  if delta > 0 then
    vim.cmd.normal({ args = { '<C-f>' }, bang = true })
  else
    vim.cmd.normal({ args = { '<C-b>' }, bang = true })
  end
end

---@return nil
function M.toggle_multiline()
  local state = state_mod.current()
  ensure_started(state)
  state.multiline = not state.multiline
  finalize(state)
end

---@param mode 'bol'|'first_nonblank'|'eol'
---@return nil
function M.merge_to_beol(mode)
  local state = state_mod.current()
  ensure_started(state)
  state.mode = 'cursor'
  state.extend_manual = false

  for i = 1, #state.cursors do
    local p = state_mod.cursor_pos(state, i)
    if p then
      local line = vim.api.nvim_buf_get_lines(state.bufnr, p.row, p.row + 1, false)[1] or ''
      local col = 0
      if mode == 'eol' then
        col = #line
      elseif mode == 'first_nonblank' then
        local s = line:find('%S')
        col = s and (s - 1) or 0
      end
      state_mod.set_pos(state, i, p.row, col)
      state_mod.set_anchor(state, i, p.row, col)
    end
  end

  finalize(state)
end

---@return nil
function M.invert_direction()
  local state = state_mod.current()
  if #state.cursors == 0 then
    return
  end
  if state.mode ~= 'extend' then
    return
  end
  state.direction = (state.direction == 1) and -1 or 1
  for _, i in ipairs(sorted_indices(state, false)) do
    local p = state_mod.cursor_pos(state, i)
    if p then
      state_mod.set_pos(state, i, p.arow, p.acol)
      state_mod.set_anchor(state, i, p.row, p.col)
    end
  end
  finalize(state)
end

---@param delta integer
---@return nil
function M.shift_selection(delta)
  local state = state_mod.current()
  ensure_started(state)
  if state.mode ~= 'extend' then
    state.mode = 'extend'
  end
  state.extend_manual = true

  for i = 1, #state.cursors do
    local p = state_mod.cursor_pos(state, i)
    if p then
      local col = clamp(state.bufnr, p.row, p.col + delta)
      state_mod.set_pos(state, i, p.row, col)
    end
  end
  render.sync(state)
  focus_current(state)
end

---@return boolean
function M.seed_word_search()
  local state = state_mod.current()
  local found = search.current_word_start()
  if not found then
    return false
  end

  local row, col, pat = found[1], found[2], found[3]
  state.search = { pat }
  clear_native_search_highlight()

  local idx = state_mod.exists_at(state, row, col)
  if idx then
    state.current = idx
  else
    state_mod.add_cursor(state, row, col, {})
  end
  finalize(state)
  return true
end

---@return nil
function M.find_under()
  local state = state_mod.current()
  local found = search.current_word_start()
  if not found then
    return
  end

  local row, col, pat = found[1], found[2], found[3]
  if #state.search == 0 then
    state.search = { pat }
  end
  clear_native_search_highlight()

  local already = state_mod.exists_at(state, row, col)
  if already then
    state.current = already
    return M.find_next(false)
  end

  state_mod.add_cursor(state, row, col, {})
  finalize(state)
end

---@return nil
function M.find_subword_under()
  local state = state_mod.current()
  local found = search.current_subword_start()
  if not found then
    return
  end

  local row, col, pat = found[1], found[2], found[3]
  if #state.search == 0 then
    state.search = { pat }
  end
  clear_native_search_highlight()

  local already = state_mod.exists_at(state, row, col)
  if already then
    state.current = already
    return M.find_next(false)
  end

  state_mod.add_cursor(state, row, col, {})
  finalize(state)
end

---@return boolean
function M.find_under_visual()
  local state = state_mod.current()
  local p1 = vim.fn.getpos("'<")
  local p2 = vim.fn.getpos("'>")
  local sr, sc = p1[2] - 1, p1[3] - 1
  local er, ec = p2[2] - 1, p2[3]
  if sr < 0 or er < 0 then
    return false
  end
  if sr > er or (sr == er and sc > ec) then
    sr, er = er, sr
    sc, ec = ec, sc
  end

  local selected = table.concat(vim.api.nvim_buf_get_text(state.bufnr, sr, sc, er, ec, {}), '\n')
  if selected == '' then
    return false
  end
  local pat = [[\V]] .. search.escape_literal(selected)
  state.search = { pat }
  clear_native_search_highlight()

  local idx = state_mod.exists_at(state, sr, sc)
  if idx then
    state.current = idx
    return true
  end
  state_mod.add_cursor(state, sr, sc, {})
  finalize(state)
  return true
end

---@return boolean
function M.find_all_under_visual()
  local state = state_mod.current()
  local p1 = vim.fn.getpos("'<")
  local p2 = vim.fn.getpos("'>")
  local sr, sc = p1[2] - 1, p1[3] - 1
  local er, ec = p2[2] - 1, p2[3]
  if sr < 0 or er < 0 then
    return false
  end
  if sr > er or (sr == er and sc > ec) then
    sr, er = er, sr
    sc, ec = ec, sc
  end
  local selected = table.concat(vim.api.nvim_buf_get_text(state.bufnr, sr, sc, er, ec, {}), '\n')
  if selected == '' then
    return false
  end
  local pat = [[\V]] .. search.escape_literal(selected)
  state.search = { pat }
  clear_native_search_highlight()
  if #state.cursors > 0 then
    state_mod.clear(state)
  end
  local matches = search.buffer_matches(state.bufnr, pat)
  for _, m in ipairs(matches) do
    state_mod.add_cursor(state, m.row, m.col, {})
  end
  if #state.cursors == 0 then
    return false
  end
  local idx = state_mod.exists_at(state, sr, sc)
  state.current = idx or 1
  finalize(state)
  return true
end

---@param backward boolean
---@return nil
function M.find_next(backward)
  local state = state_mod.current()
  ensure_started(state)
  state.nav_direction = backward and -1 or 1
  local pat = state.search[1] or search.word_pattern()
  if not pat then
    return
  end
  state.search = { pat }
  clear_native_search_highlight()

  local p = state_mod.cursor_pos(state, state.current)
  if not p then
    return
  end

  local start_col = p.col + (backward and -1 or 1)
  if start_col < 0 then
    start_col = 0
  end
  local next_pos = search.find_from(p.row, start_col, pat, backward)
  if not next_pos then
    return
  end

  local idx = state_mod.exists_at(state, next_pos[1], next_pos[2])
  if idx then
    state.current = idx
  else
    state_mod.add_cursor(state, next_pos[1], next_pos[2], {})
  end
  finalize(state)
end

---@param backward boolean|nil
---@return nil
function M.skip_current(backward)
  local state = state_mod.current()
  if #state.cursors == 0 then
    return
  end
  if backward == nil then
    backward = state.nav_direction == -1
  end
  local removed = state_mod.cursor_pos(state, state.current)
  state_mod.remove_cursor(state, state.current)
  if #state.cursors == 0 then
    render.sync(state)
    return
  end

  if not removed then
    M.find_next(backward)
    return
  end

  local pat = state.search[1] or search.word_pattern()
  if not pat then
    finalize(state)
    return
  end
  state.search = { pat }
  clear_native_search_highlight()

  local start_col = removed.col + (backward and -1 or 1)
  if start_col < 0 then
    start_col = 0
  end

  local next_pos = search.find_from(removed.row, start_col, pat, backward)
  if not next_pos then
    finalize(state)
    return
  end

  local idx = state_mod.exists_at(state, next_pos[1], next_pos[2])
  if idx then
    state.current = idx
  else
    state_mod.add_cursor(state, next_pos[1], next_pos[2], {})
  end
  finalize(state)
end

---@return nil
function M.remove_current()
  local state = state_mod.current()
  if #state.cursors == 0 then
    return
  end
  state_mod.remove_cursor(state, state.current)
  if #state.cursors > 0 then
    finalize(state)
  else
    render.sync(state)
  end
end

---@return nil
function M.select_all()
  local state = state_mod.current()
  local pat = state.search[1] or search.word_pattern()
  if not pat then
    return
  end
  state.search = { pat }
  clear_native_search_highlight()

  if #state.cursors > 0 then
    state_mod.clear(state)
  end

  local matches = search.buffer_matches(state.bufnr, pat)
  for _, m in ipairs(matches) do
    state_mod.add_cursor(state, m.row, m.col, {})
  end
  state.current = 1
  finalize(state)
end

local function selection_range(p)
  local sr, sc, er, ec = p.arow, p.acol, p.row, p.col
  if sr > er or (sr == er and sc > ec) then
    sr, er = er, sr
    sc, ec = ec, sc
  end
  sc = clamp(state_mod.current().bufnr, sr, sc)
  ec = clamp(state_mod.current().bufnr, er, ec)
  if sr == er and ec < sc then
    ec = sc
  end
  if sr == er and sc == ec then
    ec = sc
  end
  return sr, sc, er, ec
end

---@param state MultiCursorState
---@param p MultiCursorCursorPos
---@return integer, integer, integer, integer
local function action_selection_range(state, p)
  local sr, sc, er, ec = selection_range(p)
  if state.mode == 'extend' and state.extend_manual and is_extended(p) then
    ec = clamp(state.bufnr, er, ec + 1)
  end
  return sr, sc, er, ec
end

local function pos_leq(r1, c1, r2, c2)
  return (r1 < r2) or (r1 == r2 and c1 <= c2)
end

local function in_range(row, col, sr, sc, er, ec)
  return pos_leq(sr, sc, row, col) and pos_leq(row, col, er, ec)
end

local function overlaps_range(p, sr, sc, er, ec)
  local r1, c1, r2, c2 = selection_range(p)
  return not (pos_leq(r2, c2, sr, sc) or pos_leq(er, ec, r1, c1))
end

---@param consume boolean|nil
---@return string
local function register_name(consume)
  local state = state_mod.current()
  if type(state.pending_register) == 'string' and state.pending_register ~= '' then
    ---@type string
    local reg = state.pending_register
    if consume then
      state.pending_register = nil
    end
    return reg
  end
  local vreg = vim.v.register
  if type(vreg) ~= 'string' or vreg == '' then
    return '"'
  end
  ---@type string
  local reg = vreg
  return reg
end

local split_lines

---@param reg string
---@return string, boolean
local function normalize_register(reg)
  if reg:match('^[A-Z]$') then
    return reg:lower(), true
  end
  return reg, false
end

---@param kind string
---@return string
local function vim_regtype(kind)
  return kind == 'line' and 'V' or 'v'
end

---@param items string[]
---@param kind string
---@return string|string[]
local function vim_regvalue(items, kind)
  if kind == 'line' then
    return vim.deepcopy(items)
  end
  return table.concat(items, '\n')
end

---@param lhs string[]
---@param rhs string[]
---@return string[]
local function concat_items(lhs, rhs)
  local merged = {}
  local n = math.max(#lhs, #rhs)
  for i = 1, n do
    merged[i] = (lhs[i] or '') .. (rhs[i] or '')
  end
  return merged
end

---@param reg string
---@return MultiCursorRegister|nil
local function read_vim_register(reg)
  local ok_val, raw = pcall(vim.fn.getreg, reg, 1, true)
  if not ok_val then
    return nil
  end
  local items = {}
  if type(raw) == 'table' then
    items = vim.deepcopy(raw)
  elseif type(raw) == 'string' then
    if raw == '' then
      return nil
    end
    items = split_lines(raw)
  else
    return nil
  end
  if #items == 0 then
    return nil
  end
  local ok_type, regtype = pcall(vim.fn.getregtype, reg)
  local kind = (ok_type and type(regtype) == 'string' and regtype:sub(1, 1) == 'V') and 'line'
    or 'char'
  return { items = items, kind = kind }
end

---@param reg string
---@param payload MultiCursorRegister
local function write_named_register(reg, payload)
  state_mod.registers[reg] = {
    items = vim.deepcopy(payload.items),
    kind = payload.kind,
  }
  pcall(vim.fn.setreg, reg, vim_regvalue(payload.items, payload.kind), vim_regtype(payload.kind))
end

---@param payload MultiCursorRegister
local function rotate_numbered_delete_registers(payload)
  for i = 9, 2, -1 do
    local prev = tostring(i - 1)
    local cur = tostring(i)
    local existing = state_mod.registers[prev]
    if type(existing) == 'table' and type(existing.items) == 'table' and #existing.items > 0 then
      write_named_register(cur, existing)
    else
      state_mod.registers[cur] = nil
      pcall(vim.fn.setreg, cur, '', 'v')
    end
  end
  write_named_register('1', payload)
end

---@param items string[]
---@param kind string
---@param reg string|nil
---@param opts { as_delete?: boolean }|nil
local function store_yank(items, kind, reg, opts)
  reg = reg or '"'
  if reg == '_' then
    return
  end
  local target, append = normalize_register(reg)
  ---@type MultiCursorRegister
  local payload = {
    items = vim.deepcopy(items),
    kind = kind,
  }
  if append then
    ---@type MultiCursorRegister|nil
    local existing = state_mod.registers[target]
    if not (type(existing) == 'table' and type(existing.items) == 'table') then
      existing = read_vim_register(target)
    end
    if type(existing) == 'table' and type(existing.items) == 'table' then
      payload = {
        items = concat_items(existing.items, payload.items),
        kind = kind,
      }
    end
  end

  state_mod.registers[target] = payload
  if target == '"' and opts and opts.as_delete then
    rotate_numbered_delete_registers(payload)
  end
  state_mod.registers['"'] = {
    items = vim.deepcopy(payload.items),
    kind = payload.kind,
  }

  pcall(vim.fn.setreg, target, vim_regvalue(payload.items, payload.kind), vim_regtype(payload.kind))
  if target ~= '"' then
    pcall(vim.fn.setreg, '"', vim_regvalue(payload.items, payload.kind), vim_regtype(payload.kind))
  else
    pcall(vim.fn.setreg, '"', vim_regvalue(payload.items, payload.kind), vim_regtype(payload.kind))
  end
  if config.values.persistent_registers then
    state_mod.save_persistent_registers()
  end
end

local function get_yank(reg)
  reg = reg or '"'
  if reg == '_' then
    return nil
  end
  local target = normalize_register(reg)
  if target == '"' then
    local from_vim = read_vim_register(target)
    if from_vim then
      state_mod.registers[target] = from_vim
      return from_vim
    end
  end
  local found = state_mod.registers[target] or state_mod.registers['"']
  if found and type(found.items) == 'table' and #found.items > 0 then
    return found
  end
  local from_vim = read_vim_register(target)
  if from_vim then
    state_mod.registers[target] = from_vim
    if target ~= '"' then
      state_mod.registers['"'] = from_vim
    end
    return from_vim
  end
  return state_mod.registers['"']
end

local line_text

---@param state MultiCursorState
---@param opts { as_delete?: boolean }|nil
local function store_selection_yank_exact(state, opts)
  local reg = register_name(true)
  local idxs = sorted_indices(state, true)
  local items = {}
  for _, i in ipairs(idxs) do
    local p = state_mod.cursor_pos(state, i)
    if p and not (p.row == p.arow and p.col == p.acol) then
      local sr, sc, er, ec = action_selection_range(state, p)
      local lines = vim.api.nvim_buf_get_text(state.bufnr, sr, sc, er, ec, {})
      table.insert(items, table.concat(lines, '\n'))
    elseif p then
      table.insert(items, line_text(state.bufnr, p.row))
    end
  end
  store_yank(items, 'char', reg, opts)
end

line_text = function(bufnr, row)
  return vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1] or ''
end

is_extended = function(p)
  return not (p.row == p.arow and p.col == p.acol)
end

split_lines = function(text)
  return vim.split(text, '\n', { plain = true })
end

local function getchar_char()
  local g = vim.fn.getchar()
  if type(g) == 'number' then
    return vim.fn.nr2char(g)
  end
  if type(g) == 'string' then
    return g
  end
  return ''
end

local function end_pos_from_text(sr, sc, text)
  local lines = split_lines(text)
  if #lines <= 1 then
    return sr, sc + vim.fn.strchars(lines[1] or '')
  end
  return sr + #lines - 1, vim.fn.strchars(lines[#lines] or '')
end

local function replace_line(bufnr, row, text)
  local old = line_text(bufnr, row)
  vim.api.nvim_buf_set_text(bufnr, row, 0, row, #old, { text })
end

---@param changed boolean
---@return boolean
local function undojoin_next(changed)
  if changed then
    pcall(function()
      vim.cmd('silent! undojoin')
    end)
  end
  return true
end

local function prompt_regex()
  local pat = vim.fn.input('MultiCursor regex: ')
  if pat == nil or pat == '' then
    return nil
  end
  return pat
end

local function read_regex_chars(count)
  count = math.max(1, count or vim.v.count1 or 1)
  local out = {}
  for _ = 1, count do
    local c = getchar_char()
    if not c or c == '' then
      break
    end
    table.insert(out, c)
  end
  return table.concat(out, '')
end

---@param regex string|nil
---@param remove boolean|nil
---@param count integer|nil
---@return boolean
function M.goto_regex(regex, remove, count)
  local state = state_mod.current()
  ensure_started(state)

  if regex == nil or regex == '' then
    regex = read_regex_chars(count)
  end
  if regex == nil or regex == '' then
    return false
  end

  local idxs = sorted_indices(state, false)
  for _, i in ipairs(idxs) do
    local p = state_mod.cursor_pos(state, i)
    if p then
      local found = search.find_from(p.row, p.col, regex, false)
      if found then
        state_mod.set_pos(state, i, found[1], found[2])
        state_mod.set_anchor(state, i, found[1], found[2])
      elseif remove then
        state_mod.remove_cursor(state, i)
      end
    end
  end

  if #state.cursors == 0 then
    render.sync(state)
    return false
  end
  finalize(state)
  return true
end

---@param pat string|nil
---@param opts { select_all?: boolean, force_picker?: boolean }|nil
---@return boolean
function M.find_by_regex(pat, opts)
  opts = opts or {}
  local state = state_mod.current()
  local prompted = false
  if pat == nil then
    pat = prompt_regex()
    prompted = true
  elseif pat == '' then
    return false
  end
  if not pat then
    return false
  end

  state.search = { pat }
  local matches = search.buffer_matches(state.bufnr, pat)
  if #matches == 0 then
    return false
  end

  local interactive_picker = (prompted or opts.force_picker == true)
    and (config.values.picker or 'auto') ~= 'none'
  local select_many = opts.select_all == true or interactive_picker

  local function apply_choice(chosen, visible)
    if select_many then
      local source = matches
      if type(visible) == 'table' and #visible > 0 then
        source = visible
      end
      if #state.cursors > 0 then
        state_mod.clear(state)
      end
      for _, m in ipairs(source) do
        state_mod.add_cursor(state, m.row, m.col, {})
      end
      if #state.cursors > 0 then
        local idx = 1
        if chosen then
          local at = state_mod.exists_at(state, chosen.row, chosen.col)
          if at then
            idx = at
          end
        end
        state.current = idx
        finalize(state)
      end
      return
    end

    local picked = chosen
    if not picked then
      local p = vim.api.nvim_win_get_cursor(0)
      picked = search.find_from(p[1] - 1, p[2], pat, false)
      if picked then
        picked = { row = picked[1], col = picked[2] }
      end
    end
    if not picked then
      return
    end
    state_mod.add_cursor(state, picked.row, picked.col, {})
    finalize(state)
  end

  if interactive_picker then
    return picker.select_matches(state.bufnr, pat, matches, apply_choice)
  end

  apply_choice(nil)
  if select_many then
    return #state.cursors > 0
  end
  return true
end

---@param pat string|nil
---@param opts { select_all?: boolean }|nil
---@return boolean
function M.find_visual_by_regex(pat, opts)
  opts = opts or {}
  local state = state_mod.current()
  if pat == nil then
    pat = prompt_regex()
  elseif pat == '' then
    return false
  end
  if not pat then
    return false
  end

  local p1 = vim.fn.getpos("'<")
  local p2 = vim.fn.getpos("'>")
  local start_row, start_col = p1[2] - 1, p1[3] - 1
  local end_row, end_col = p2[2] - 1, p2[3] - 1
  if start_row < 0 or end_row < 0 then
    return false
  end

  state.search = { pat }
  if #state.cursors > 0 then
    state_mod.clear(state)
  end

  local matches =
    search.buffer_matches_in_range(state.bufnr, pat, start_row, start_col, end_row, end_col)
  if not opts.select_all and #matches > 0 then
    matches = { matches[1] }
  end
  for _, m in ipairs(matches) do
    state_mod.add_cursor(state, m.row, m.col, {})
  end
  if #state.cursors == 0 then
    return false
  end
  state.current = 1
  finalize(state)
  return true
end

---@return boolean
function M.visual_cursors()
  local state = state_mod.current()
  local p1 = vim.fn.getpos("'<")
  local p2 = vim.fn.getpos("'>")
  local start_row, start_col = p1[2] - 1, p1[3] - 1
  local end_row = p2[2] - 1
  if start_row < 0 or end_row < 0 then
    return false
  end
  if start_row > end_row then
    start_row, end_row = end_row, start_row
  end
  if #state.cursors > 0 then
    state_mod.clear(state)
  end
  for row = start_row, end_row do
    state_mod.add_cursor(state, row, start_col, {})
  end
  if #state.cursors == 0 then
    return false
  end
  state.current = 1
  finalize(state)
  return true
end

---@return boolean
function M.visual_add()
  local state = state_mod.current()
  if #state.cursors > 0 and state.mode ~= 'extend' then
    M.select_operator_with_motion('iw')
  end
  local p1 = vim.fn.getpos("'<")
  local p2 = vim.fn.getpos("'>")
  local sr, sc = p1[2] - 1, p1[3] - 1
  local er, ec = p2[2] - 1, p2[3] - 1
  if sr < 0 or er < 0 then
    return false
  end
  if sr > er or (sr == er and sc > ec) then
    sr, er = er, sr
    sc, ec = ec, sc
  end
  sc = clamp(state.bufnr, sr, sc)
  ec = clamp(state.bufnr, er, ec)
  state_mod.add_cursor(state, sr, sc, {})
  local idx = state.current
  state_mod.set_anchor(state, idx, sr, sc)
  state_mod.set_pos(state, idx, er, ec)
  state.mode = 'extend'
  state.extend_manual = false
  finalize(state)
  return true
end

---@return boolean
function M.visual_subtract()
  local state = state_mod.current()
  if #state.cursors == 0 then
    return false
  end
  local p1 = vim.fn.getpos("'<")
  local p2 = vim.fn.getpos("'>")
  local sr, sc = p1[2] - 1, p1[3] - 1
  local er, ec = p2[2] - 1, p2[3]
  if sr < 0 or er < 0 then
    return false
  end
  if sr > er or (sr == er and sc > ec) then
    sr, er = er, sr
    sc, ec = ec, sc
  end
  for i = #state.cursors, 1, -1 do
    local p = state_mod.cursor_pos(state, i)
    if p and overlaps_range(p, sr, sc, er, ec) then
      state_mod.remove_cursor(state, i)
    end
  end
  if #state.cursors == 0 then
    render.sync(state)
    return true
  end
  finalize(state)
  return true
end

---@return boolean
function M.visual_reduce()
  local state = state_mod.current()
  if #state.cursors == 0 then
    return false
  end
  local p1 = vim.fn.getpos("'<")
  local p2 = vim.fn.getpos("'>")
  local sr, sc = p1[2] - 1, p1[3] - 1
  local er, ec = p2[2] - 1, p2[3]
  if sr < 0 or er < 0 then
    return false
  end
  if sr > er or (sr == er and sc > ec) then
    sr, er = er, sr
    sc, ec = ec, sc
  end
  for i = #state.cursors, 1, -1 do
    local p = state_mod.cursor_pos(state, i)
    if p and not in_range(p.row, p.col, sr, sc, er, ec) then
      state_mod.remove_cursor(state, i)
    end
  end
  if #state.cursors == 0 then
    render.sync(state)
    return true
  end
  finalize(state)
  return true
end

local function entries_for_state(state, asc)
  local idxs = sorted_indices(state, asc)
  local out = {}
  for _, idx in ipairs(idxs) do
    local p = state_mod.cursor_pos(state, idx)
    if p then
      local sr, sc, er, ec = action_selection_range(state, p)
      local selected = is_extended(p)
      local text
      if selected then
        text = table.concat(vim.api.nvim_buf_get_text(state.bufnr, sr, sc, er, ec, {}), '\n')
      else
        text = line_text(state.bufnr, p.row)
      end
      table.insert(out, {
        idx = idx,
        pos = p,
        sr = sr,
        sc = sc,
        er = er,
        ec = ec,
        selected = selected,
        text = text,
      })
    end
  end
  return out
end

---@return nil
function M.align()
  local state = state_mod.current()
  ensure_started(state)
  local max_col = 1
  local asc = entries_for_state(state, true)
  for _, e in ipairs(asc) do
    max_col = math.max(max_col, e.sc)
  end
  for i = #asc, 1, -1 do
    local e = asc[i]
    local pad = max_col - e.sc
    if pad > 0 then
      vim.api.nvim_buf_set_text(state.bufnr, e.sr, e.sc, e.sr, e.sc, { string.rep(' ', pad) })
      state_mod.set_pos(state, e.idx, e.pos.row, e.pos.col + pad)
      state_mod.set_anchor(state, e.idx, e.pos.arow, e.pos.acol + pad)
    end
  end
  finalize(state)
end

local function pad_to_target(state, entries, targets)
  local max_target = 0
  for _, t in ipairs(targets) do
    max_target = math.max(max_target, t)
  end
  for i = #entries, 1, -1 do
    local e = entries[i]
    local current_target = targets[i]
    local pad = max_target - current_target
    if pad > 0 then
      vim.api.nvim_buf_set_text(state.bufnr, e.sr, e.sc, e.sr, e.sc, { string.rep(' ', pad) })
      state_mod.set_pos(state, e.idx, e.pos.row, e.pos.col + pad)
      state_mod.set_anchor(state, e.idx, e.pos.arow, e.pos.acol + pad)
    end
  end
end

---@param count integer|nil
---@param ch string|nil
---@return nil
function M.align_char(count, ch)
  local state = state_mod.current()
  ensure_started(state)
  count = count or 1
  if ch == nil or ch == '' then
    ch = getchar_char()
  end
  if ch == nil or ch == '' then
    return
  end
  local asc = entries_for_state(state, true)
  local targets = {}
  for _, e in ipairs(asc) do
    local line = line_text(state.bufnr, e.pos.row)
    local at, start = e.sc, 1
    local found = nil
    for _ = 1, count do
      local s = line:find(ch, start, true)
      if not s then
        break
      end
      found = s - 1
      start = s + 1
    end
    at = found or at
    table.insert(targets, at)
  end
  pad_to_target(state, asc, targets)
  finalize(state)
end

---@param rx string|nil
---@return nil
function M.align_regex(rx)
  local state = state_mod.current()
  ensure_started(state)
  if rx == nil or rx == '' then
    rx = vim.fn.input('Align regex: ')
  end
  if rx == nil or rx == '' then
    return
  end
  local asc = entries_for_state(state, true)
  local targets = {}
  for _, e in ipairs(asc) do
    local line = line_text(state.bufnr, e.pos.row)
    local m = vim.fn.matchstrpos(line, rx, 0)
    local sc = m[2]
    if sc == nil or sc < 0 then
      sc = e.sc
    end
    table.insert(targets, sc)
  end
  pad_to_target(state, asc, targets)
  finalize(state)
end

---@return nil
function M.duplicate()
  local state = state_mod.current()
  ensure_started(state)
  local desc = entries_for_state(state, false)
  for _, e in ipairs(desc) do
    if e.selected then
      vim.api.nvim_buf_set_text(state.bufnr, e.er, e.ec, e.er, e.ec, split_lines(e.text))
    else
      vim.api.nvim_buf_set_lines(state.bufnr, e.pos.row + 1, e.pos.row + 1, false, { e.text })
    end
  end
  finalize(state)
end

---@return nil
function M.transpose()
  local state = state_mod.current()
  ensure_started(state)
  local asc = entries_for_state(state, true)
  if #asc < 2 then
    return
  end
  local values = {}
  for i, e in ipairs(asc) do
    values[i] = e.text
  end
  local rotated = {}
  for i = 1, #values do
    rotated[i] = values[(i % #values) + 1]
  end
  for i = #asc, 1, -1 do
    local e = asc[i]
    local text = rotated[i]
    if e.selected then
      vim.api.nvim_buf_set_text(state.bufnr, e.sr, e.sc, e.er, e.ec, split_lines(text))
    else
      replace_line(state.bufnr, e.pos.row, text)
    end
  end
  finalize(state)
end

---@return nil
function M.rotate()
  -- VM rotate corresponds to non-inline transposition; our transpose path
  -- already rotates region payloads in sequence.
  M.transpose()
end

local function surround_pair(ch)
  local pairs = {
    ['('] = { '(', ')' },
    ['['] = { '[', ']' },
    ['{'] = { '{', '}' },
    ['<'] = { '<', '>' },
    [')'] = { '(', ')' },
    [']'] = { '[', ']' },
    ['}'] = { '{', '}' },
    ['>'] = { '<', '>' },
    ['"'] = { '"', '"' },
    ["'"] = { "'", "'" },
    ['`'] = { '`', '`' },
  }
  if pairs[ch] then
    return pairs[ch][1], pairs[ch][2]
  end
  return nil, nil
end

---@param ch string|nil
---@return boolean
function M.surround(ch)
  local state = state_mod.current()
  if #state.cursors == 0 then
    return false
  end
  if state.mode ~= 'extend' then
    M.select_operator_with_motion('iw')
  end
  if state.mode ~= 'extend' then
    return false
  end

  if ch == nil or ch == '' then
    ch = getchar_char()
  end
  if ch == nil or ch == '' then
    return false
  end

  local open, close = surround_pair(ch)
  if not open then
    if ch == 't' or ch == '<' then
      local tag = vim.fn.input('Tag: ')
      if tag == nil or tag == '' then
        return false
      end
      local name = (tag:match('^%s*([%w:_-]+)') or ''):gsub('^%s+', '')
      if name == '' then
        return false
      end
      open = '<' .. tag .. '>'
      close = '</' .. name .. '>'
    else
      return false
    end
  end

  local asc = entries_for_state(state, true)
  for i = #asc, 1, -1 do
    local e = asc[i]
    local wrapped = open .. e.text .. close
    vim.api.nvim_buf_set_text(state.bufnr, e.sr, e.sc, e.er, e.ec, split_lines(wrapped))
    state_mod.set_anchor(state, e.idx, e.sr, e.sc)
    local nr, nc = end_pos_from_text(e.sr, e.sc, wrapped)
    state_mod.set_pos(state, e.idx, nr, nc)
  end
  state.mode = 'extend'
  state.extend_manual = false
  finalize(state)
  return true
end

---@return boolean
function M.merge_regions()
  local state = state_mod.current()
  if #state.cursors == 0 then
    return false
  end
  if state.mode ~= 'extend' then
    finalize(state)
    return true
  end

  local ranges = {}
  for _, i in ipairs(state_mod.sort_indices_asc(state)) do
    local p = state_mod.cursor_pos(state, i)
    if p then
      local sr, sc, er, ec = selection_range(p)
      table.insert(ranges, { sr = sr, sc = sc, er = er, ec = ec })
    end
  end
  if #ranges <= 1 then
    finalize(state)
    return true
  end

  table.sort(ranges, function(a, b)
    if a.sr == b.sr then
      return a.sc < b.sc
    end
    return a.sr < b.sr
  end)

  local merged = { ranges[1] }
  for i = 2, #ranges do
    local cur = ranges[i]
    local last = merged[#merged]
    local overlaps = (cur.sr < last.er)
      or (cur.sr == last.er and cur.sc <= last.ec)
      or (last.sr < cur.er and cur.sr <= last.er)
    if overlaps then
      if cur.er > last.er or (cur.er == last.er and cur.ec > last.ec) then
        last.er = cur.er
        last.ec = cur.ec
      end
    else
      table.insert(merged, cur)
    end
  end

  for i = #state.cursors, 1, -1 do
    state_mod.remove_cursor(state, i)
  end
  for _, r in ipairs(merged) do
    state_mod.add_cursor(state, r.sr, r.ec, {})
    local idx = state.current
    state_mod.set_anchor(state, idx, r.sr, r.sc)
    state_mod.set_pos(state, idx, r.er, r.ec)
  end
  state.mode = 'extend'
  state.extend_manual = false
  finalize(state)
  return true
end

local function eval_transform(expr, text, i, n)
  local e = expr
  e = e:gsub('%%t', vim.fn.string(text))
  e = e:gsub('%%f', tostring(tonumber(text) or 0.0))
  e = e:gsub('%%n', tostring(math.floor(tonumber(text) or 0)))
  e = e:gsub('%%i', tostring(i))
  e = e:gsub('%%N', tostring(n))
  local ok, out = pcall(vim.fn.eval, e)
  if not ok then
    return text
  end
  return tostring(out)
end

---@param expr string|nil
---@return nil
function M.transform_regions(expr)
  local state = state_mod.current()
  ensure_started(state)
  if expr == nil or expr == '' then
    expr = vim.fn.input('Transform expression: ')
  end
  if expr == nil or expr == '' then
    return
  end
  local asc = entries_for_state(state, true)
  local n = #asc
  for i = #asc, 1, -1 do
    local e = asc[i]
    local replacement = eval_transform(expr, e.text, i, n)
    if e.selected then
      vim.api.nvim_buf_set_text(state.bufnr, e.sr, e.sc, e.er, e.ec, split_lines(replacement))
    else
      replace_line(state.bufnr, e.pos.row, replacement)
    end
  end
  finalize(state)
end

---@param pat string|nil
---@param repl string|nil
---@return boolean
function M.replace_pattern_in_regions(pat, repl)
  local state = state_mod.current()
  ensure_started(state)
  if state.mode ~= 'extend' then
    return false
  end
  if pat == nil or pat == '' then
    pat = vim.fn.input('Replace pattern: ')
  end
  if pat == nil or pat == '' then
    return false
  end
  if repl == nil then
    repl = vim.fn.input('Replacement: ')
  end
  repl = repl or ''

  local asc = entries_for_state(state, true)
  for i = #asc, 1, -1 do
    local e = asc[i]
    local t = e.text:gsub(pat, repl)
    vim.api.nvim_buf_set_text(state.bufnr, e.sr, e.sc, e.er, e.ec, split_lines(t))
  end
  finalize(state)
  return true
end

---@param pattern string|nil
---@return boolean
function M.subtract_pattern(pattern)
  local state = state_mod.current()
  ensure_started(state)
  if state.mode ~= 'extend' then
    return false
  end
  if pattern == nil or pattern == '' then
    pattern = vim.fn.input('Subtract pattern: ')
  end
  if pattern == nil or pattern == '' then
    return false
  end
  local asc = entries_for_state(state, true)
  for i = #asc, 1, -1 do
    local e = asc[i]
    local t = e.text:gsub(pattern, '')
    vim.api.nvim_buf_set_text(state.bufnr, e.sr, e.sc, e.er, e.ec, split_lines(t))
  end
  finalize(state)
  return true
end

---@return nil
function M.delete_regions()
  local state = state_mod.current()
  ensure_started(state)
  local desc = entries_for_state(state, false)
  local changed = false
  for _, e in ipairs(desc) do
    if e.selected then
      changed = undojoin_next(changed)
      local max_row = math.max(0, vim.api.nvim_buf_line_count(state.bufnr) - 1)
      local sr = math.max(0, math.min(e.sr, max_row))
      local er = math.max(0, math.min(e.er, max_row))
      local sc = clamp(state.bufnr, sr, e.sc)
      local ec = clamp(state.bufnr, er, e.ec)
      if sr == er and ec < sc then
        ec = sc
      end
      vim.api.nvim_buf_set_text(state.bufnr, sr, sc, er, ec, { '' })
      state_mod.set_pos(state, e.idx, sr, sc)
      state_mod.set_anchor(state, e.idx, sr, sc)
    else
      local l = line_text(state.bufnr, e.pos.row)
      if #l > 0 and e.pos.col < #l then
        changed = undojoin_next(changed)
        vim.api.nvim_buf_set_text(
          state.bufnr,
          e.pos.row,
          e.pos.col,
          e.pos.row,
          e.pos.col + 1,
          { '' }
        )
      end
    end
  end
  state.mode = 'cursor'
  state.extend_manual = false
  finalize(state)
end

---@param text string|nil
---@return nil
function M.change_regions(text)
  local state = state_mod.current()
  ensure_started(state)
  if state.mode == 'extend' then
    store_selection_yank_exact(state, { as_delete = true })
  end
  if text == nil then
    text = vim.fn.input('Change to: ')
  end
  if text == nil then
    return
  end
  local desc = entries_for_state(state, false)
  local changed = false
  for _, e in ipairs(desc) do
    if e.selected then
      changed = undojoin_next(changed)
      vim.api.nvim_buf_set_text(state.bufnr, e.sr, e.sc, e.er, e.ec, split_lines(text))
      state_mod.set_pos(state, e.idx, e.sr, e.sc + #text)
      state_mod.set_anchor(state, e.idx, e.sr, e.sc + #text)
    else
      local l = line_text(state.bufnr, e.pos.row)
      local c = math.min(e.pos.col, #l)
      changed = undojoin_next(changed)
      vim.api.nvim_buf_set_text(state.bufnr, e.pos.row, c, e.pos.row, c, split_lines(text))
      state_mod.set_pos(state, e.idx, e.pos.row, c + #text)
      state_mod.set_anchor(state, e.idx, e.pos.row, c + #text)
    end
  end
  state.mode = 'cursor'
  state.extend_manual = false
  finalize(state)
end

---@param ch string|nil
---@return boolean
function M.replace_chars(ch)
  local state = state_mod.current()
  ensure_started(state)

  if state.mode == 'extend' then
    if ch == nil or ch == '' then
      ch = getchar_char()
    end
    if ch == nil or ch == '' then
      return false
    end

    local asc = entries_for_state(state, true)
    for i = #asc, 1, -1 do
      local e = asc[i]
      if e.selected then
        local width = math.max(1, vim.fn.strchars(e.text))
        local repl = string.rep(ch, width)
        vim.api.nvim_buf_set_text(state.bufnr, e.sr, e.sc, e.er, e.ec, split_lines(repl))
        local nr, nc = end_pos_from_text(e.sr, e.sc, repl)
        state_mod.set_anchor(state, e.idx, e.sr, e.sc)
        state_mod.set_pos(state, e.idx, nr, nc)
      else
        local line = line_text(state.bufnr, e.pos.row)
        if e.pos.col < #line then
          vim.api.nvim_buf_set_text(
            state.bufnr,
            e.pos.row,
            e.pos.col,
            e.pos.row,
            e.pos.col + 1,
            { ch }
          )
        end
      end
    end
    finalize(state)
    return true
  end

  if ch == nil or ch == '' then
    ch = getchar_char()
  end
  if ch == nil or ch == '' then
    return false
  end
  M.apply_normal('r' .. ch, false)
  return true
end

---@param op string
---@param motion string
---@return boolean
function M.operator_with_motion(op, motion)
  local state = state_mod.current()
  ensure_started(state)
  if not op or not motion or op == '' or motion == '' then
    return false
  end
  if op == 'y' and state.mode ~= 'extend' then
    if not M.select_operator_with_motion(motion) then
      return false
    end
    store_selection_yank_exact(state)
    for i = 1, #state.cursors do
      local p = state_mod.cursor_pos(state, i)
      if p then
        local sr, sc = selection_range(p)
        state_mod.set_pos(state, i, sr, sc)
        state_mod.set_anchor(state, i, sr, sc)
      end
    end
    state.mode = 'cursor'
    state.extend_manual = false
    remember_dot(state, nil)
    finalize(state)
    return true
  end
  if op == 'd' and state.mode ~= 'extend' then
    if not M.select_operator_with_motion(motion) then
      return false
    end
    store_selection_yank_exact(state, { as_delete = true })
    M.delete_regions()
    remember_dot(state, { kind = 'operator', op = 'd', motion = motion })
    return true
  end
  if op == 'c' and state.mode ~= 'extend' then
    if not M.select_operator_with_motion(motion) then
      return false
    end
    store_selection_yank_exact(state, { as_delete = true })
    M.delete_regions()
    M.begin_insert('insert')
    remember_dot(state, nil)
    return true
  end
  if op == 'd' and state.mode == 'extend' then
    store_selection_yank_exact(state, { as_delete = true })
    M.delete_regions()
    remember_dot(state, { kind = 'operator', op = 'd', motion = motion })
    return true
  end
  if op == 'c' and state.mode == 'extend' then
    M.change_regions(nil)
    remember_dot(state, nil)
    return true
  end
  if op == 'y' and state.mode == 'extend' then
    M.yank()
    remember_dot(state, nil)
    return true
  end
  M.apply_normal(op .. motion, false)
  if op == 'd' then
    remember_dot(state, { kind = 'operator', op = 'd', motion = motion })
  else
    remember_dot(state, nil)
  end
  return true
end

---@param include_count boolean|nil
local function read_motion(include_count)
  local ch1 = getchar_char()
  if not ch1 or ch1 == '' then
    return nil
  end
  local need_second = ({ i = true, a = true, g = true, f = true, F = true, t = true, T = true })[ch1]
  local motion = ch1
  if need_second then
    local ch2 = getchar_char()
    if ch2 and ch2 ~= '' then
      motion = motion .. ch2
    end
  end
  if include_count and vim.v.count > 0 then
    motion = tostring(vim.v.count) .. motion
  end
  return motion
end

---@param keys string
---@return nil
local function apply_operator_motion(keys)
  -- Operator-motion probing should be deterministic and avoid recursive map loops.
  vim.cmd.normal({ args = { keys }, bang = true })
end

---@param motion string
---@return string|nil
local function mapped_motion_rhs(motion)
  if type(motion) ~= 'string' or motion == '' then
    return nil
  end
  local count = motion:match('^%d+')
  local base = count and motion:sub(#count + 1) or motion
  for _, mode in ipairs({ 'o', 'n' }) do
    local map = vim.fn.maparg(base, mode, false, true)
    local rhs = type(map) == 'table' and map.rhs or nil
    if type(rhs) == 'string' and rhs ~= '' then
      return (count or '') .. rhs
    end
  end
  return nil
end

---@param op string
---@return boolean
function M.operator_prompt(op)
  local motion = read_motion(true)
  if not motion then
    return false
  end
  return M.operator_with_motion(op, motion)
end

---@param motion string
---@return boolean
function M.select_operator_with_motion(motion)
  local state = state_mod.current()
  ensure_started(state)
  if not motion or motion == '' then
    return false
  end

  local save = vim.api.nvim_win_get_cursor(0)
  local reg_before = vim.fn.getreg('"')
  local regtype_before = vim.fn.getregtype('"')
  local idxs = sorted_indices(state, false)
  local any = false

  vim.g.multi_cursor_bypass_maps = 1
  for _, i in ipairs(idxs) do
    local p = state_mod.cursor_pos(state, i)
    if p then
      local resolved_motion = mapped_motion_rhs(motion) or motion
      local row = math.max(1, math.min(p.row + 1, vim.api.nvim_buf_line_count(state.bufnr)))
      local col = clamp(state.bufnr, row - 1, p.col)
      vim.api.nvim_win_set_cursor(0, { row, col })
      local before1 = vim.fn.getpos("'[")
      local before2 = vim.fn.getpos("']")
      apply_operator_motion('y' .. resolved_motion)
      local p1 = vim.fn.getpos("'[")
      local p2 = vim.fn.getpos("']")
      local p1r = p1[2] - 1
      local p2r = p2[2] - 1
      local cur_row = row - 1
      local touched_current_row = (p1r <= cur_row and cur_row <= p2r)
        or (p2r <= cur_row and cur_row <= p1r)
      local marks_changed = p1[2] ~= before1[2]
        or p1[3] ~= before1[3]
        or p2[2] ~= before2[2]
        or p2[3] ~= before2[3]
      if p1[2] > 0 and p2[2] > 0 and touched_current_row and marks_changed then
        local sr, sc = p1[2] - 1, math.max(0, p1[3] - 1)
        local er, ec = p2[2] - 1, math.max(0, p2[3])
        sc = clamp(state.bufnr, sr, sc)
        ec = clamp(state.bufnr, er, ec)
        if sr > er or (sr == er and sc > ec) then
          sr, er = er, sr
          sc, ec = ec, sc
        end
        state_mod.set_anchor(state, i, sr, sc)
        state_mod.set_pos(state, i, er, ec)
        any = true
      end
    end
  end
  vim.g.multi_cursor_bypass_maps = 0
  pcall(vim.fn.setreg, '"', reg_before, regtype_before)

  local max_row = vim.api.nvim_buf_line_count(state.bufnr)
  local row = math.max(1, math.min(save[1], max_row))
  local col = clamp(state.bufnr, row - 1, save[2])
  vim.api.nvim_win_set_cursor(0, { row, col })

  if any then
    state.mode = 'extend'
    state.extend_manual = false
    finalize(state)
    return true
  end
  return false
end

---@return boolean
function M.select_operator_prompt()
  local motion = read_motion(true)
  if not motion then
    return false
  end
  return M.select_operator_with_motion(motion)
end

---@param motion string
---@return boolean
function M.find_operator_with_motion(motion)
  local state = state_mod.current()
  ensure_started(state)
  if not motion or motion == '' then
    return false
  end

  local pat = state.search[1] or search.word_pattern()
  if not pat then
    return false
  end
  state.search = { pat }

  local save = vim.api.nvim_win_get_cursor(0)
  local reg_before = vim.fn.getreg('"')
  local regtype_before = vim.fn.getregtype('"')
  local idxs = sorted_indices(state, true)
  local hits = {}

  vim.g.multi_cursor_bypass_maps = 1
  for _, i in ipairs(idxs) do
    local p = state_mod.cursor_pos(state, i)
    if p then
      local resolved_motion = mapped_motion_rhs(motion) or motion
      local row = math.max(1, math.min(p.row + 1, vim.api.nvim_buf_line_count(state.bufnr)))
      local col = clamp(state.bufnr, row - 1, p.col)
      vim.api.nvim_win_set_cursor(0, { row, col })
      apply_operator_motion('y' .. resolved_motion)
      local p1 = vim.fn.getpos("'[")
      local p2 = vim.fn.getpos("']")
      if p1[2] > 0 and p2[2] > 0 then
        local start_row = math.min(p1[2], p2[2]) - 1
        local end_row = math.max(p1[2], p2[2]) - 1
        local last_col = line_len(state.bufnr, end_row)
        local ms = search.buffer_matches_in_range(state.bufnr, pat, start_row, 0, end_row, last_col)
        for _, m in ipairs(ms) do
          table.insert(hits, m)
        end
      end
    end
  end
  vim.g.multi_cursor_bypass_maps = 0
  pcall(vim.fn.setreg, '"', reg_before, regtype_before)
  vim.api.nvim_win_set_cursor(0, save)

  for _, m in ipairs(hits) do
    state_mod.add_cursor(state, m.row, m.col, {})
  end
  finalize(state)
  return true
end

---@return boolean
function M.find_operator_prompt()
  local motion = read_motion(true)
  if not motion then
    return false
  end
  return M.find_operator_with_motion(motion)
end

---@param n integer|nil
---@return nil
function M.remove_every_n_regions(n)
  local state = state_mod.current()
  ensure_started(state)
  n = tonumber(n) or vim.v.count
  if not n or n <= 1 then
    n = 2
  end
  local idxs = state_mod.sort_indices_asc(state)
  for pos = #idxs, 1, -1 do
    local idx = idxs[pos]
    if pos % n == 0 then
      state_mod.remove_cursor(state, idx)
    end
  end
  if #state.cursors > 0 then
    state.current = math.min(state.current, #state.cursors)
    finalize(state)
  else
    render.sync(state)
  end
end

---@return boolean
function M.remove_last_region()
  local state = state_mod.current()
  if #state.cursors == 0 then
    return false
  end
  state_mod.remove_cursor(state, #state.cursors)
  if #state.cursors == 0 then
    render.sync(state)
  else
    finalize(state)
  end
  return true
end

---@return boolean
function M.one_region_per_line()
  local state = state_mod.current()
  if #state.cursors == 0 then
    return false
  end
  local keep = {}
  local seen = {}
  for _, idx in ipairs(state_mod.sort_indices_asc(state)) do
    local p = state_mod.cursor_pos(state, idx)
    if p and not seen[p.row] then
      seen[p.row] = true
      keep[idx] = true
    end
  end
  for i = #state.cursors, 1, -1 do
    if not keep[i] then
      state_mod.remove_cursor(state, i)
    end
  end
  if #state.cursors == 0 then
    render.sync(state)
    return true
  end
  finalize(state)
  return true
end

---@return boolean
function M.remove_empty_lines()
  local state = state_mod.current()
  if #state.cursors == 0 then
    return false
  end
  for i = #state.cursors, 1, -1 do
    local p = state_mod.cursor_pos(state, i)
    if p and p.row == p.arow and p.col == p.acol then
      local line = line_text(state.bufnr, p.row)
      if line == '' and p.col == 0 then
        state_mod.remove_cursor(state, i)
      end
    end
  end
  if #state.cursors == 0 then
    render.sync(state)
    return true
  end
  finalize(state)
  return true
end

---@param shrink boolean
---@return boolean
function M.shrink_or_enlarge(shrink)
  local state = state_mod.current()
  if #state.cursors == 0 then
    return false
  end
  if state.mode ~= 'extend' then
    state.mode = 'extend'
    state.extend_manual = true
  end

  local dir = state.direction
  local first = shrink and ((dir == 1) and -1 or 1) or ((dir == 1) and 1 or -1)
  local second = shrink and ((dir == 1) and 1 or -1) or ((dir == 1) and -1 or 1)

  M.shift_selection(first)
  M.invert_direction()
  M.shift_selection(second)
  if state.direction ~= dir then
    M.invert_direction()
  end
  return true
end

---@return boolean
function M.split_lines()
  local state = state_mod.current()
  if #state.cursors == 0 then
    return false
  end
  local entries = entries_for_state(state, true)
  local new_regs = {}
  for _, e in ipairs(entries) do
    if not e.selected or e.sr == e.er then
      table.insert(new_regs, { sr = e.sr, sc = e.sc, er = e.er, ec = e.ec })
    else
      for row = e.sr, e.er do
        if row == e.sr then
          table.insert(new_regs, {
            sr = row,
            sc = e.sc,
            er = row,
            ec = line_len(state.bufnr, row),
          })
        elseif row < e.er then
          table.insert(new_regs, {
            sr = row,
            sc = 0,
            er = row,
            ec = line_len(state.bufnr, row),
          })
        else
          table.insert(new_regs, { sr = row, sc = 0, er = row, ec = e.ec })
        end
      end
    end
  end

  for i = #state.cursors, 1, -1 do
    state_mod.remove_cursor(state, i)
  end
  for _, r in ipairs(new_regs) do
    local sr = math.max(0, r.sr)
    local er = math.max(0, r.er)
    local sc = clamp(state.bufnr, sr, r.sc)
    local ec = clamp(state.bufnr, er, r.ec)
    state_mod.add_cursor(state, sr, ec, {})
    local idx = state.current
    state_mod.set_anchor(state, idx, sr, sc)
    state_mod.set_pos(state, idx, er, ec)
  end
  state.mode = 'extend'
  state.extend_manual = false
  finalize(state)
  return true
end

---@param increase boolean
---@param all_types boolean
---@param count integer|nil
---@param gcount boolean
---@return boolean
function M.increase_or_decrease(increase, all_types, count, gcount)
  local state = state_mod.current()
  ensure_started(state)
  local old_nrformats = vim.bo.nrformats
  if all_types then
    local has_alpha = false
    for _, v in ipairs(vim.opt_local.nrformats:get()) do
      if v == 'alpha' then
        has_alpha = true
        break
      end
    end
    if not has_alpha then
      vim.opt_local.nrformats:append({ 'alpha' })
    end
  end

  local cnt = tonumber(count) or vim.v.count1 or 1
  local key = (increase and '<C-a>' or '<C-x>')
  local tc_key = vim.api.nvim_replace_termcodes(key, true, false, true)

  local save = vim.api.nvim_win_get_cursor(0)
  vim.g.multi_cursor_bypass_maps = 1
  local idxs = sorted_indices(state, gcount and true or false)
  local gcur = cnt
  for _, i in ipairs(idxs) do
    local p = state_mod.cursor_pos(state, i)
    if p then
      local row = math.max(1, math.min(p.row + 1, vim.api.nvim_buf_line_count(state.bufnr)))
      local col = clamp(state.bufnr, row - 1, p.col)
      vim.api.nvim_win_set_cursor(0, { row, col })

      local tick = vim.b.changedtick or 0
      local prefix = ''
      if gcount then
        if gcur > 1 then
          prefix = tostring(gcur)
        end
      elseif cnt > 1 then
        prefix = tostring(cnt)
      end
      vim.cmd.normal({ args = { prefix .. tc_key }, bang = true })
      if gcount and (vim.b.changedtick or 0) > tick then
        gcur = gcur + cnt
      end

      local cur = vim.api.nvim_win_get_cursor(0)
      state_mod.set_pos(state, i, cur[1] - 1, cur[2])
      state_mod.set_anchor(state, i, cur[1] - 1, cur[2])
    end
  end
  local max_row = vim.api.nvim_buf_line_count(state.bufnr)
  local row = math.max(1, math.min(save[1], max_row))
  local col = clamp(state.bufnr, row - 1, save[2])
  vim.api.nvim_win_set_cursor(0, { row, col })
  vim.g.multi_cursor_bypass_maps = 0
  state.mode = 'cursor'
  state.extend_manual = false
  finalize(state)

  if all_types then
    vim.bo.nrformats = old_nrformats
  end
  return true
end

---@return boolean
function M.toggle_whole_word()
  local state = state_mod.current()
  local pat = state.search[1]
  if not pat or pat == '' then
    return false
  end
  local inner = pat
  local wrapped = false
  if inner:sub(1, 4) == [[\V\<]] and inner:sub(-2) == [[\>]] then
    inner = inner:sub(5, -3)
    wrapped = true
  elseif inner:sub(1, 2) == [[\<]] and inner:sub(-2) == [[\>]] then
    inner = inner:sub(3, -3)
    wrapped = true
  end
  if wrapped then
    state.search = { inner }
  else
    state.search = { [[\<]] .. inner .. [[\>]] }
  end
  return true
end

---@param cmd string|nil
---@return boolean
function M.run_normal(cmd)
  if cmd == nil or cmd == '' then
    cmd = vim.fn.input('Normal command: ')
  end
  if cmd == nil or cmd == '' then
    return false
  end
  local state = state_mod.current()
  state.last_normal = cmd
  M.apply_normal(cmd, false)
  return true
end

local function run_visual_builtin(state, bufnr, entries, cmd)
  local fn = nil
  if cmd == 'gU' or cmd == 'U' then
    fn = string.upper
  elseif cmd == 'gu' or cmd == 'u' then
    fn = string.lower
  elseif cmd == '~' then
    fn = function(t)
      return t:gsub('%a', function(c)
        return (c:lower() == c) and c:upper() or c:lower()
      end)
    end
  end
  if not fn then
    return false
  end
  for i = #entries, 1, -1 do
    local e = entries[i]
    local t = fn(e.text)
    vim.api.nvim_buf_set_text(bufnr, e.sr, e.sc, e.er, e.ec, split_lines(t))
    state_mod.set_anchor(state, e.idx, e.sr, e.sc)
    state_mod.set_pos(state, e.idx, e.er, e.ec)
  end
  return true
end

---@param cmd string|nil
---@return boolean
function M.run_visual(cmd)
  local state = state_mod.current()
  ensure_started(state)
  if state.mode ~= 'extend' then
    return false
  end
  if cmd == nil or cmd == '' then
    cmd = vim.fn.input('Visual command: ')
  end
  if cmd == nil or cmd == '' then
    return false
  end
  state.last_visual = cmd
  local asc = entries_for_state(state, true)
  local applied = run_visual_builtin(state, state.bufnr, asc, cmd)
  if not applied then
    return M.run_normal(cmd)
  end
  finalize(state)
  return true
end

---@param pattern string|nil
---@param invert boolean|nil
---@return nil
function M.filter_regions(pattern, invert)
  local state = state_mod.current()
  ensure_started(state)
  if pattern == nil or pattern == '' then
    pattern = vim.fn.input('Filter pattern: ')
  end
  if pattern == nil or pattern == '' then
    return
  end
  for i = #state.cursors, 1, -1 do
    local p = state_mod.cursor_pos(state, i)
    if p then
      local keep = line_text(state.bufnr, p.row):find(pattern) ~= nil
      if invert then
        keep = not keep
      end
      if not keep then
        state_mod.remove_cursor(state, i)
      end
    end
  end
  render.sync(state)
  focus_current(state)
end

---@param start_num integer|nil
---@param step integer|nil
---@param append boolean|nil
---@return nil
function M.number_regions(start_num, step, append)
  local state = state_mod.current()
  ensure_started(state)
  start_num = start_num or 1
  step = step or 1
  local asc = entries_for_state(state, true)
  local separator = ''
  for i = #asc, 1, -1 do
    local e = asc[i]
    local n = tostring(start_num + (i - 1) * step)
    local text = append and (separator .. n) or (n .. separator)
    local t = append and (e.text .. text) or (text .. e.text)
    if e.selected then
      vim.api.nvim_buf_set_text(state.bufnr, e.sr, e.sc, e.er, e.ec, split_lines(t))
    else
      replace_line(state.bufnr, e.pos.row, t)
    end
  end
  finalize(state)
end

local function parse_numbers_expr(expr)
  if expr == nil or expr == '' then
    return nil
  end
  if not expr:find('^%-?%d') then
    return nil
  end

  local parts = vim.split(expr, '/', { plain = true, trimempty = false })
  local i = 1
  while i < #parts do
    if parts[i]:sub(-1) == '\\' then
      parts[i] = parts[i]:sub(1, -2) .. '/' .. parts[i + 1]
      table.remove(parts, i + 1)
    else
      i = i + 1
    end
  end

  local cleaned = {}
  for _, p in ipairs(parts) do
    if p ~= '' then
      table.insert(cleaned, p)
    end
  end
  if #cleaned == 0 then
    return nil
  end

  local start_num = tonumber(cleaned[1])
  if start_num == nil then
    return nil
  end
  if #cleaned == 1 then
    return start_num, 1, ''
  end

  local second_num = tonumber(cleaned[2])
  if #cleaned == 2 then
    if second_num ~= nil then
      return start_num, second_num, ''
    end
    return start_num, 1, cleaned[2]
  end

  local step = tonumber(cleaned[2]) or 1
  return start_num, step, cleaned[3] or ''
end

---@param start_num integer|nil
---@param append boolean|nil
---@param expr string|nil
---@return boolean
function M.number_regions_prompt(start_num, append, expr)
  start_num = start_num or 1
  if expr == nil then
    expr = vim.fn.input('Expression > ', tostring(start_num) .. '/1/')
  end
  if expr == nil or expr == '' then
    return false
  end

  local n0, step, sep = parse_numbers_expr(expr)
  if n0 == nil then
    return false
  end

  local state = state_mod.current()
  ensure_started(state)
  local asc = entries_for_state(state, true)
  for i = #asc, 1, -1 do
    local e = asc[i]
    local n = tostring(n0 + (i - 1) * step)
    local injected = append and (sep .. n) or (n .. sep)
    local t = append and (e.text .. injected) or (injected .. e.text)
    if e.selected then
      vim.api.nvim_buf_set_text(state.bufnr, e.sr, e.sc, e.er, e.ec, split_lines(t))
    else
      replace_line(state.bufnr, e.pos.row, t)
    end
  end
  finalize(state)
  return true
end

---@param start_num integer|nil
---@param append boolean|nil
---@return boolean
function M.number_regions_zero(start_num, append)
  start_num = tonumber(start_num) or 0
  M.number_regions(start_num, 1, append)
  return true
end

---@param line string
---@param col integer
---@return integer|nil, integer|nil
local function keyword_range_on_line(line, col)
  local n = #line
  if n == 0 then
    return nil, nil
  end
  local cur = math.max(0, math.min(col, n))
  local idx = cur + 1
  if idx <= n and line:sub(idx, idx):match('[%w_]') then
    local s = idx
    while s > 1 and line:sub(s - 1, s - 1):match('[%w_]') do
      s = s - 1
    end
    local e = idx
    while e <= n and line:sub(e, e):match('[%w_]') do
      e = e + 1
    end
    return s - 1, e - 1
  end
  local fs, fe = line:find('[%w_]+', idx)
  if not fs or not fe then
    return nil, nil
  end
  return fs - 1, fe
end

---@param mode string|nil
---@return nil
function M.case_convert(mode)
  local state = state_mod.current()
  ensure_started(state)
  local single_region_before = state.single_region
  state.single_region = false
  local has_selection = false
  for i = 1, #state.cursors do
    local p = state_mod.cursor_pos(state, i)
    if p and is_extended(p) then
      has_selection = true
      break
    end
  end
  if state.mode ~= 'extend' or not has_selection then
    M.select_operator_with_motion('iw')
  end
  local asc = entries_for_state(state, true)
  local function snake(t)
    local s = t:gsub('::', '/')
    s = s:gsub('(%u+)(%u%l)', '%1_%2')
    s = s:gsub('(%l%d?)(%u)', '%1_%2')
    s = s:gsub('([%l%d])(%u)', '%1_%2')
    s = s:gsub('[%.%-]', '_')
    s = s:gsub('%s+', '_')
    return s:lower()
  end

  local function camel(t)
    local s = t:gsub('[%.%-]', '_'):gsub('%s+', '_')
    if not s:find('_') and s:find('%l') then
      return s:gsub('^.', string.lower)
    end
    s = s:gsub('_?(.)', function(c)
      return c == '' and '' or c:upper()
    end)
    return s:gsub('^.', string.lower)
  end

  local function pascal(t)
    local c = camel(t)
    return c:gsub('^.', string.upper)
  end

  local function title(t)
    return snake(t):gsub('_', ' '):gsub('(%a)([%w_]*)', function(a, b)
      return a:upper() .. b:lower()
    end)
  end

  local function capitalize(t)
    if t == '' then
      return t
    end
    return t:sub(1, 1):upper() .. t:sub(2):lower()
  end

  local function conv(t)
    if mode == 'upper' then
      return t:upper()
    elseif mode == 'title' then
      return title(t)
    elseif mode == 'capitalize' then
      return capitalize(t)
    elseif mode == 'camel' then
      return camel(t)
    elseif mode == 'pascal' then
      return pascal(t)
    elseif mode == 'snake' then
      return snake(t)
    elseif mode == 'snake_upper' then
      return snake(t):upper()
    elseif mode == 'dash' then
      return snake(t):gsub('_', '-')
    elseif mode == 'dot' then
      return snake(t):gsub('_', '.')
    elseif mode == 'space' then
      return snake(t):gsub('_', ' ')
    end
    return t:lower()
  end
  local function apply_keyword_fallback(e)
    local line = line_text(state.bufnr, e.pos.row)
    local ws, we = keyword_range_on_line(line, e.pos.col)
    if ws == nil or we == nil then
      return false
    end
    local piece = line:sub(ws + 1, we)
    local repl = conv(piece)
    vim.api.nvim_buf_set_text(state.bufnr, e.pos.row, ws, e.pos.row, we, { repl })
    return true
  end
  for i = #asc, 1, -1 do
    local e = asc[i]
    local t = conv(e.text)
    if e.selected then
      vim.api.nvim_buf_set_text(state.bufnr, e.sr, e.sc, e.er, e.ec, split_lines(t))
      if e.text:find('[%a]') == nil then
        apply_keyword_fallback(e)
      end
    else
      apply_keyword_fallback(e)
    end
  end
  state.mode = 'cursor'
  state.extend_manual = false
  state.single_region = single_region_before
  finalize(state)
end

---@return string[]
function M.case_conversion_items()
  return {
    'lower',
    'upper',
    'title',
    'capitalize',
    'camel',
    'pascal',
    'snake',
    'snake_upper',
    'dash',
    'dot',
    'space',
  }
end

---@param choice string|nil
---@return boolean
function M.case_conversion_menu(choice)
  local items = {
    {
      id = 'lower',
      label = 'lower_case',
      aliases = { 'l', 'lower' },
      run = function()
        M.case_convert('lower')
      end,
    },
    {
      id = 'upper',
      label = 'UPPER_CASE',
      aliases = { 'u', 'upper' },
      run = function()
        M.case_convert('upper')
      end,
    },
    {
      id = 'title',
      label = 'Title Case',
      aliases = { 't', 'title' },
      run = function()
        M.case_convert('title')
      end,
    },
    {
      id = 'capitalize',
      label = 'Capitalize',
      aliases = { 'cap', 'capitalize' },
      run = function()
        M.case_convert('capitalize')
      end,
    },
    {
      id = 'camel',
      label = 'camelCase',
      aliases = { 'cc', 'camel' },
      run = function()
        M.case_convert('camel')
      end,
    },
    {
      id = 'pascal',
      label = 'PascalCase',
      aliases = { 'pc', 'pascal' },
      run = function()
        M.case_convert('pascal')
      end,
    },
    {
      id = 'snake',
      label = 'snake_case',
      aliases = { 'sc', 'snake' },
      run = function()
        M.case_convert('snake')
      end,
    },
    {
      id = 'snake_upper',
      label = 'SNAKE_UPPER',
      aliases = { 'su', 'snake_upper', 'constant' },
      run = function()
        M.case_convert('snake_upper')
      end,
    },
    {
      id = 'dash',
      label = 'dash-case',
      aliases = { 'kebab', 'dash' },
      run = function()
        M.case_convert('dash')
      end,
    },
    {
      id = 'dot',
      label = 'dot.case',
      aliases = { 'dot' },
      run = function()
        M.case_convert('dot')
      end,
    },
    {
      id = 'space',
      label = 'space case',
      aliases = { 'space', 'words' },
      run = function()
        M.case_convert('space')
      end,
    },
  }
  return run_menu('case conversion', items, choice)
end

---@return boolean
function M.toggle_mappings()
  local state = state_mod.current()
  if state.maps_enabled == nil then
    state.maps_enabled = true
  end
  state.maps_enabled = not state.maps_enabled
  return state.maps_enabled
end

---@param cmd string|nil
---@return nil
function M.run_ex(cmd)
  local state = state_mod.current()
  ensure_started(state)
  if cmd == nil or cmd == '' then
    cmd = vim.fn.input('Ex command: ')
  end
  if cmd == nil or cmd == '' then
    return
  end
  state.last_ex = cmd
  local save = vim.api.nvim_win_get_cursor(0)
  vim.g.multi_cursor_bypass_maps = 1
  for _, i in ipairs(sorted_indices(state, false)) do
    local p = state_mod.cursor_pos(state, i)
    if p then
      vim.api.nvim_win_set_cursor(0, { p.row + 1, p.col })
      vim.cmd(cmd)
      local cur = vim.api.nvim_win_get_cursor(0)
      state_mod.set_pos(state, i, cur[1] - 1, cur[2])
      state_mod.set_anchor(state, i, cur[1] - 1, cur[2])
    end
  end
  vim.api.nvim_win_set_cursor(0, save)
  vim.g.multi_cursor_bypass_maps = 0
  finalize(state)
end

---@return boolean
function M.run_last_normal()
  local state = state_mod.current()
  if not state.last_normal or state.last_normal == '' then
    return false
  end
  M.apply_normal(state.last_normal, false)
  return true
end

---@return boolean
function M.run_last_visual()
  local state = state_mod.current()
  if not state.last_visual or state.last_visual == '' then
    return false
  end
  return M.run_visual(state.last_visual)
end

---@return boolean
function M.run_last_ex()
  local state = state_mod.current()
  if not state.last_ex or state.last_ex == '' then
    return false
  end
  M.run_ex(state.last_ex)
  return true
end

---@return boolean
function M.run_dot()
  local state = state_mod.current()
  local dot = state.last_dot
  if type(dot) == 'table' then
    if dot.kind == 'operator' and type(dot.op) == 'string' and type(dot.motion) == 'string' then
      return M.operator_with_motion(dot.op, dot.motion)
    end
    if dot.kind == 'paste' and type(dot.after) == 'boolean' then
      if dot.multi then
        M.paste_multicursor(dot.after)
      else
        M.paste_single_cursor(dot.after)
      end
      return true
    end
    if dot.kind == 'extend_delete' then
      M.yank_exact_selection(true)
      M.delete_regions()
      return true
    end
  end
  if state.last_normal and state.last_normal ~= '' then
    M.apply_normal(state.last_normal, false)
  else
    M.apply_normal('.', false)
  end
  return true
end

---@return 'smart'|'sensitive'|'ignore'
function M.case_setting_cycle()
  local mode
  if vim.o.smartcase then
    vim.o.smartcase = false
    vim.o.ignorecase = false
    mode = 'sensitive'
  elseif not vim.o.ignorecase then
    vim.o.ignorecase = true
    mode = 'ignore'
  else
    vim.o.smartcase = true
    vim.o.ignorecase = true
    mode = 'smart'
  end
  pcall(vim.notify, string.format('MultiCursor case setting: %s', mode), vim.log.levels.INFO)
  return mode
end

---@return boolean
function M.show_registers()
  local reg = state_mod.registers['"'] or { items = {}, kind = 'line' }
  local count = type(reg.items) == 'table' and #reg.items or 0
  print(string.format('MultiCursor registers: default kind=%s items=%d', reg.kind or 'line', count))
  return true
end

---@param menu string
---@param items MultiCursorMenuItem[]
---@param choice string|nil
---@return boolean
run_menu = function(menu, items, choice)
  ---@type MultiCursorMenuItem|nil
  local selected = nil
  local pick = choice
  if type(pick) == 'string' then
    pick = vim.trim(pick)
    if pick == '' then
      pick = nil
    end
  end

  if pick ~= nil then
    local as_idx = tonumber(pick)
    if as_idx ~= nil and as_idx >= 1 and as_idx <= #items then
      selected = items[as_idx]
    else
      local want = string.lower(pick)
      for _, item in ipairs(items) do
        if item.id == want then
          selected = item
          break
        end
        ---@type string[]
        local aliases = item.aliases or {}
        for _, alias in ipairs(aliases) do
          if alias == want then
            selected = item
            break
          end
        end
        if selected then
          break
        end
      end
    end
  else
    local ok = picker.select(
      items,
      { prompt_title = string.format('MultiCursor %s', menu) },
      function(item)
        if item then
          pcall(item.run)
        end
      end
    )
    return ok
  end

  if not selected then
    return false
  end
  local ok = pcall(selected.run)
  return ok
end

---@return string[]
function M.search_menu_items()
  return {
    'seed_word',
    'find_next',
    'find_prev',
    'select_all',
    'regex_all',
    'rewrite_last_search',
  }
end

---@param choice string|nil
---@return boolean
function M.search_menu(choice)
  ---@type MultiCursorMenuItem[]
  local items = {
    {
      id = 'seed_word',
      label = 'Seed current word',
      aliases = { 'seed', '*' },
      run = function()
        M.seed_word_search()
      end,
    },
    {
      id = 'find_next',
      label = 'Find next',
      aliases = { 'next', 'n' },
      run = function()
        M.find_next(false)
      end,
    },
    {
      id = 'find_prev',
      label = 'Find previous',
      aliases = { 'prev', 'N' },
      run = function()
        M.find_next(true)
      end,
    },
    {
      id = 'select_all',
      label = 'Select all matches',
      aliases = { 'all', 'A' },
      run = function()
        M.select_all()
      end,
    },
    {
      id = 'regex_all',
      label = 'Regex select all',
      aliases = { 'regex', '/' },
      run = function()
        local pat = vim.fn.input('Pattern: ')
        if type(pat) ~= 'string' or pat == '' then
          return
        end
        M.find_by_regex(pat, { select_all = true })
      end,
    },
    {
      id = 'rewrite_last_search',
      label = 'Rewrite last search',
      aliases = { 'rewrite', 'r' },
      run = function()
        M.rewrite_last_search()
      end,
    },
  }
  return run_menu('search', items, choice)
end

---@return boolean
function M.rewrite_last_search()
  local state = state_mod.current()
  local old = state.search[1]
  if not old or old == '' then
    return false
  end

  local text = ''
  local p = state_mod.cursor_pos(state, state.current)
  if p and state.mode == 'extend' and is_extended(p) then
    local sr, sc, er, ec = selection_range(p)
    text = table.concat(vim.api.nvim_buf_get_text(state.bufnr, sr, sc, er, ec, {}), '\n')
  else
    local save = vim.api.nvim_win_get_cursor(0)
    if p then
      vim.api.nvim_win_set_cursor(0, { p.row + 1, p.col })
    end
    text = vim.fn.expand('<cword>') or ''
    vim.api.nvim_win_set_cursor(0, save)
  end

  if text == '' then
    return false
  end

  local escaped = search.escape_literal(text)
  local keep_word_bounds = old:find('\\<', 1, true) ~= nil
    and old:find('\\>', 1, true) ~= nil
    and not text:find('\n', 1, true)
  local pat = keep_word_bounds and ([[\V\<]] .. escaped .. [[\>]]) or ([[\V]] .. escaped)
  state.search = { pat }
  clear_native_search_highlight()
  return true
end

---@return string[]
function M.tools_menu_items()
  return {
    'toggle_mode',
    'toggle_single_region',
    'toggle_multiline',
    'case_conversion',
    'toggle_mappings',
    'show_registers',
    'case_setting',
    'clear',
  }
end

---@param choice string|nil
---@return boolean
function M.tools_menu(choice)
  ---@type MultiCursorMenuItem[]
  local items = {
    {
      id = 'toggle_mode',
      label = 'Toggle cursor/extend mode',
      aliases = { 'mode', 'tab' },
      run = function()
        M.toggle_mode()
      end,
    },
    {
      id = 'toggle_single_region',
      label = 'Toggle single-region mode',
      aliases = { 'single', 'enter' },
      run = function()
        M.toggle_single_region()
      end,
    },
    {
      id = 'toggle_multiline',
      label = 'Toggle multiline mode',
      aliases = { 'multiline', 'm' },
      run = function()
        M.toggle_multiline()
      end,
    },
    {
      id = 'case_conversion',
      label = 'Case conversion menu',
      aliases = { 'caseconv', 'cC', 'C' },
      run = function()
        M.case_conversion_menu(nil)
      end,
    },
    {
      id = 'toggle_mappings',
      label = 'Toggle multicursor mappings',
      aliases = { 'maps', 'space' },
      run = function()
        M.toggle_mappings()
      end,
    },
    {
      id = 'show_registers',
      label = 'Show multicursor registers',
      aliases = { 'registers', '"' },
      run = function()
        M.show_registers()
      end,
    },
    {
      id = 'case_setting',
      label = 'Cycle case setting',
      aliases = { 'case', 'c' },
      run = function()
        M.case_setting_cycle()
      end,
    },
    {
      id = 'clear',
      label = 'Clear all cursors',
      aliases = { 'exit', 'esc' },
      run = function()
        M.clear()
      end,
    },
  }
  return run_menu('tools', items, choice)
end

---@param pattern string|nil
---@param next_only boolean|nil
---@param line1 integer|nil
---@param line2 integer|nil
---@return boolean
function M.vm_search(pattern, next_only, line1, line2)
  local state = state_mod.current()
  local pat = pattern
  if pat == nil or pat == '' then
    local slash = vim.fn.getreg('/')
    pat = type(slash) == 'string' and slash or ''
  end
  if pat == nil or pat == '' then
    return false
  end

  if next_only then
    state.search = { pat }
    clear_native_search_highlight()
    local cur = vim.api.nvim_win_get_cursor(0)
    local found = search.find_from(cur[1] - 1, cur[2], pat, false)
    if not found then
      return false
    end
    local idx = state_mod.exists_at(state, found[1], found[2])
    if idx then
      state.current = idx
    else
      state_mod.add_cursor(state, found[1], found[2], {})
    end
    finalize(state)
    return true
  end

  local sr, er
  if type(line1) == 'number' and type(line2) == 'number' then
    sr = math.max(0, line1 - 1)
    er = math.max(0, line2 - 1)
  else
    local cur = vim.api.nvim_win_get_cursor(0)
    sr = cur[1] - 1
    er = sr
  end
  if sr > er then
    sr, er = er, sr
  end

  if #state.cursors > 0 then
    state_mod.clear(state)
  end
  state.search = { pat }
  clear_native_search_highlight()
  local ec = line_len(state.bufnr, er)
  local matches = search.buffer_matches_in_range(state.bufnr, pat, sr, 0, er, ec)
  for _, m in ipairs(matches) do
    state_mod.add_cursor(state, m.row, m.col, {})
  end
  if #state.cursors == 0 then
    render.sync(state)
    return false
  end
  state.current = 1
  finalize(state)
  return true
end

---@param arg string|nil
---@return boolean
function M.vm_sort(arg)
  local state = state_mod.current()
  if #state.cursors == 0 then
    return false
  end
  local entries = entries_for_state(state, true)
  local values = {}
  for i = 1, #entries do
    values[i] = entries[i].text
  end
  if arg ~= nil and arg ~= '' then
    values = vim.fn.sort(values, arg)
  else
    values = vim.fn.sort(values)
  end
  for i = #entries, 1, -1 do
    local e = entries[i]
    local t = values[i] or e.text
    vim.api.nvim_buf_set_text(state.bufnr, e.sr, e.sc, e.er, e.ec, split_lines(t))
    state_mod.set_anchor(state, e.idx, e.sr, e.sc)
    local nr, nc = end_pos_from_text(e.sr, e.sc, t)
    state_mod.set_pos(state, e.idx, nr, nc)
  end
  finalize(state)
  return true
end

---@param use_positions boolean|nil
---@return boolean
function M.vm_qfix(use_positions)
  local state = state_mod.current()
  if #state.cursors == 0 then
    return false
  end
  local items = {}
  for _, i in ipairs(state_mod.sort_indices_asc(state)) do
    local p = state_mod.cursor_pos(state, i)
    if p then
      local text = line_text(state.bufnr, p.row)
      local item = {
        bufnr = state.bufnr,
        lnum = p.row + 1,
      }
      if use_positions then
        item.col = p.col + 1
        item.text = text
      else
        item.text = text
      end
      table.insert(items, item)
    end
  end
  vim.fn.setqflist({}, 'r', { title = 'MultiCursor', items = items })
  return true
end

---@param pattern string|nil
---@param invert boolean|nil
---@return boolean
function M.vm_filter_regions(pattern, invert)
  M.filter_regions(pattern, invert)
  return true
end

local function open_sync_buffer(lines, on_write)
  local buf = vim.api.nvim_create_buf(true, true)
  vim.api.nvim_buf_set_name(buf, string.format('MultiCursorSync://%d', buf))
  vim.bo[buf].buftype = 'acwrite'
  vim.bo[buf].bufhidden = 'wipe'
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = 'text'
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_create_autocmd('BufWriteCmd', {
    buffer = buf,
    callback = function()
      on_write(buf)
      vim.bo[buf].modified = false
    end,
  })
  vim.api.nvim_set_current_buf(buf)
  return buf
end

---@return boolean
function M.vm_filter_lines()
  local state = state_mod.current()
  if #state.cursors == 0 then
    return false
  end
  local rows = {}
  local seen = {}
  for _, i in ipairs(state_mod.sort_indices_asc(state)) do
    local p = state_mod.cursor_pos(state, i)
    if p and not seen[p.row] then
      seen[p.row] = true
      table.insert(rows, p.row)
    end
  end
  table.sort(rows)
  local lines = {}
  for _, row in ipairs(rows) do
    table.insert(lines, line_text(state.bufnr, row))
  end
  local source_buf = state.bufnr
  open_sync_buffer(lines, function(buf)
    local edited = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    if #edited ~= #rows then
      error('VMFilterLines: line count mismatch')
    end
    for idx = #rows, 1, -1 do
      local row = rows[idx]
      vim.api.nvim_buf_set_lines(source_buf, row, row + 1, false, { edited[idx] })
    end
  end)
  return true
end

---@return boolean
function M.vm_regions_to_buffer()
  local state = state_mod.current()
  if #state.cursors == 0 then
    return false
  end
  local entries = entries_for_state(state, true)
  local lines = {}
  for _, e in ipairs(entries) do
    table.insert(lines, e.text)
  end
  local source_buf = state.bufnr
  open_sync_buffer(lines, function(buf)
    local edited = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    if #edited ~= #entries then
      error('VMRegionsToBuffer: line count mismatch')
    end
    for i = #entries, 1, -1 do
      local e = entries[i]
      vim.api.nvim_buf_set_text(source_buf, e.sr, e.sc, e.er, e.ec, split_lines(edited[i]))
    end
  end)
  return true
end

local function escape_lua_pattern(s)
  return (s:gsub('([%(%)%.%%%+%-%*%?%[%]%^%$])', '%%%1'))
end

---@return boolean
function M.vm_mass_transpose()
  local state = state_mod.current()
  if #state.cursors < 2 then
    return false
  end
  local entries = entries_for_state(state, true)
  if #entries < 2 then
    return false
  end
  local a = entries[1].text
  local b = entries[2].text
  if a == '' or b == '' or a == b then
    return false
  end
  local pa = escape_lua_pattern(a)
  local pb = escape_lua_pattern(b)
  local placeholder = '__MULTICURSOR_TRANSPOSE_TOKEN__'
  local lines = vim.api.nvim_buf_get_lines(state.bufnr, 0, -1, false)
  for _, line in ipairs(lines) do
    while line:find(placeholder, 1, true) do
      placeholder = placeholder .. '_'
    end
  end
  local pp = escape_lua_pattern(placeholder)
  for i, line in ipairs(lines) do
    line = line:gsub(pa, placeholder)
    line = line:gsub(pb, a)
    line = line:gsub(pp, b)
    lines[i] = line
  end
  vim.api.nvim_buf_set_lines(state.bufnr, 0, -1, false, lines)
  finalize(state)
  return true
end

---@param register string|nil
---@return nil
function M.run_macro(register)
  register = register or getchar_char()
  if register == nil or register == '' then
    return
  end
  M.apply_normal('@' .. register, false)
end

---@return nil
function M.undo()
  vim.cmd.undo()
end

---@return nil
function M.redo()
  vim.cmd.redo()
end

---@param kind 'insert'|'append'|'insert_sol'|'append_eol'
---@return nil
function M.begin_insert(kind)
  local state = state_mod.current()
  ensure_started(state)

  local idxs = sorted_indices(state, false)
  for _, i in ipairs(idxs) do
    local p = state_mod.cursor_pos(state, i)
    if p then
      local row, col = p.row, p.col
      if kind == 'append' then
        col = math.min(col + 1, line_len(state.bufnr, row))
      elseif kind == 'insert_sol' then
        col = 0
      elseif kind == 'append_eol' then
        col = line_len(state.bufnr, row)
      end
      state_mod.set_pos(state, i, row, col)
      state_mod.set_anchor(state, i, row, col)
    end
  end

  state.insert_active = true
  state.insert_single_entry = state.single_region
  if config.values.use_first_cursor_in_line then
    local cp = state_mod.cursor_pos(state, state.current)
    if cp then
      local best = state.current
      local best_col = cp.col
      for i = 1, #state.cursors do
        local p = state_mod.cursor_pos(state, i)
        if p and p.row == cp.row and p.col < best_col then
          best = i
          best_col = p.col
        end
      end
      state.current = best
    end
  end
  state.replace_mode = false
  if config.values.disable_syntax_in_imode then
    if state.insert_prev_synmaxcol == nil then
      state.insert_prev_synmaxcol = vim.bo[state.bufnr].synmaxcol
    end
    vim.bo[state.bufnr].synmaxcol = 1
  end
  state.mode = 'cursor'
  state.extend_manual = false
  finalize(state)
  vim.cmd.startinsert()
end

---@param ch string
---@return boolean
function M.insert_char_pre(ch)
  local state = state_mod.current()
  if not state.insert_active or #state.cursors <= 1 then
    return false
  end
  if type(ch) ~= 'string' or ch == '' then
    return false
  end

  local cur = vim.api.nvim_win_get_cursor(0)
  local entry = {
    ch = ch,
    row = cur[1] - 1,
    col = cur[2],
  }
  local pending = state.insert_pending
  if pending == nil then
    state.insert_pending = { entry }
  elseif pending.ch ~= nil then
    state.insert_pending = { pending, entry }
  else
    table.insert(pending, entry)
  end
  return true
end

local function pop_pending(state)
  local pending = state.insert_pending
  if pending == nil then
    return nil
  end
  if pending.ch ~= nil then
    state.insert_pending = nil
    return pending
  end
  if #pending == 0 then
    state.insert_pending = nil
    return nil
  end
  local item = table.remove(pending, 1)
  if #pending == 0 then
    state.insert_pending = nil
  end
  return item
end

---@param opts table|nil
---@return boolean
function M.apply_pending_insert(opts)
  opts = opts or {}
  local state = state_mod.current()
  local pending = pop_pending(state)
  if not state.insert_active or not pending or #state.cursors <= 1 then
    return false
  end

  local ch = pending.ch
  local row = pending.row
  local col = pending.col
  local dcol = vim.fn.strchars(ch)
  local main = state_mod.exists_at(state, row, col) or state.current
  state.current = main

  for _, i in ipairs(sorted_indices(state, false)) do
    if i ~= main then
      local p = state_mod.cursor_pos(state, i)
      if p then
        local erow, ecol = p.row, p.col
        if state.replace_mode and p.col < line_len(state.bufnr, p.row) then
          ecol = p.col + 1
        end
        vim.api.nvim_buf_set_text(state.bufnr, p.row, p.col, erow, ecol, { ch })
        state_mod.set_pos(state, i, p.row, p.col + dcol)
        state_mod.set_anchor(state, i, p.row, p.col + dcol)
      end
    end
  end

  local mp = state_mod.cursor_pos(state, main)
  if mp then
    state_mod.set_pos(state, main, mp.row, mp.col + dcol)
    state_mod.set_anchor(state, main, mp.row, mp.col + dcol)
  end
  if not opts.skip_render then
    render.sync(state)
  end
  return true
end

---@return nil
function M.end_insert()
  local state = state_mod.current()
  if should_reindent(state) then
    local save = vim.api.nvim_win_get_cursor(0)
    for _, i in ipairs(state_mod.sort_indices_desc(state)) do
      local p = state_mod.cursor_pos(state, i)
      if p then
        local row = math.max(1, math.min(p.row + 1, vim.api.nvim_buf_line_count(state.bufnr)))
        vim.api.nvim_win_set_cursor(0, { row, 0 })
        vim.cmd.normal({ args = { '==' }, bang = true })
      end
    end
    local max_row = vim.api.nvim_buf_line_count(state.bufnr)
    vim.api.nvim_win_set_cursor(0, { math.max(1, math.min(save[1], max_row)), save[2] })
  end
  if state.insert_single_entry and config.values.single_mode_auto_reset then
    state.single_region = false
  end
  if config.values.reselect_first and #state.cursors > 0 then
    state.current = 1
  end
  state.insert_active = false
  state.insert_pending = nil
  state.insert_single_entry = false
  state.replace_mode = false
  if state.insert_prev_synmaxcol ~= nil then
    vim.bo[state.bufnr].synmaxcol = state.insert_prev_synmaxcol
    state.insert_prev_synmaxcol = nil
  end
  ensure_anchor_for_cursor_mode(state)
  render.sync(state)
  if config.values.quit_after_leaving_insert_mode then
    M.clear()
  end
end

---@param delta integer
---@param fallback string|nil
---@return string
function M.handle_single_mode_cycle(delta, fallback)
  local state = state_mod.current()
  if not state.insert_active or not state.single_region or #state.cursors == 0 then
    return fallback or ''
  end
  if state.insert_pending then
    while M.apply_pending_insert({ skip_render = true }) do
    end
    render.sync(state)
  end
  M.goto_region(delta)
  return ''
end

local function find_word_left_col(line, col)
  local i = math.max(0, math.min(col, #line))
  while i > 0 and line:sub(i, i):match('%s') do
    i = i - 1
  end
  while i > 0 and line:sub(i, i):match('[%w_]') do
    i = i - 1
  end
  return i
end

local function find_word_right_col(line, col)
  local i = math.max(1, math.min(col + 1, #line + 1))
  while i <= #line and line:sub(i, i):match('%s') do
    i = i + 1
  end
  while i <= #line and line:sub(i, i):match('[%w_]') do
    i = i + 1
  end
  return math.max(0, math.min(i - 1, #line))
end

---@param kind string
---@return boolean
function M.apply_insert_special_now(kind)
  local state = state_mod.current()
  if not state.insert_active or #state.cursors == 0 then
    return false
  end
  if state.insert_pending then
    while M.apply_pending_insert({ skip_render = true }) do
    end
    render.sync(state)
  end

  local cur = vim.api.nvim_win_get_cursor(0)
  local main = state_mod.exists_at(state, cur[1] - 1, cur[2]) or state.current
  state.current = main

  local function set_cursor_to_main()
    local mp = state_mod.cursor_pos(state, main)
    if mp then
      vim.api.nvim_win_set_cursor(0, { mp.row + 1, mp.col })
    end
  end

  if
    kind == 'left'
    or kind == 'right'
    or kind == 'home'
    or kind == 'end'
    or kind == 'up'
    or kind == 'down'
    or kind == 'word_left'
    or kind == 'word_right'
  then
    for _, i in ipairs(sorted_indices(state, true)) do
      local p = state_mod.cursor_pos(state, i)
      if p then
        local row, col = p.row, p.col
        local line = line_text(state.bufnr, row)
        if kind == 'left' then
          col = math.max(0, col - 1)
        elseif kind == 'right' then
          col = math.min(line_len(state.bufnr, row), col + 1)
        elseif kind == 'home' then
          col = 0
        elseif kind == 'end' then
          col = line_len(state.bufnr, row)
        elseif kind == 'up' then
          row = math.max(0, row - 1)
          col = math.min(line_len(state.bufnr, row), col)
        elseif kind == 'down' then
          row = math.min(vim.api.nvim_buf_line_count(state.bufnr) - 1, row + 1)
          col = math.min(line_len(state.bufnr, row), col)
        elseif kind == 'word_left' then
          col = find_word_left_col(line, col)
        elseif kind == 'word_right' then
          col = find_word_right_col(line, col)
        end
        state_mod.set_pos(state, i, row, col)
        state_mod.set_anchor(state, i, row, col)
      end
    end
    render.sync(state)
    set_cursor_to_main()
    return true
  end

  if
    kind == 'bs'
    or kind == 'del'
    or kind == 'ctrl_d'
    or kind == 'cr'
    or kind == 'ctrl_w'
    or kind == 'ctrl_u'
  then
    for _, i in ipairs(sorted_indices(state, false)) do
      local p = state_mod.cursor_pos(state, i)
      if p then
        local line = line_text(state.bufnr, p.row)
        if kind == 'bs' then
          if p.col > 0 then
            vim.api.nvim_buf_set_text(state.bufnr, p.row, p.col - 1, p.row, p.col, { '' })
            state_mod.set_pos(state, i, p.row, p.col - 1)
            state_mod.set_anchor(state, i, p.row, p.col - 1)
          end
        elseif kind == 'del' or kind == 'ctrl_d' then
          if p.col < line_len(state.bufnr, p.row) then
            vim.api.nvim_buf_set_text(state.bufnr, p.row, p.col, p.row, p.col + 1, { '' })
          end
          local np = state_mod.cursor_pos(state, i)
          if np then
            state_mod.set_anchor(state, i, np.row, np.col)
          end
        elseif kind == 'cr' then
          vim.api.nvim_buf_set_text(state.bufnr, p.row, p.col, p.row, p.col, { '', '' })
          state_mod.set_pos(state, i, p.row + 1, 0)
          state_mod.set_anchor(state, i, p.row + 1, 0)
        elseif kind == 'ctrl_w' then
          if p.col > 0 then
            local sc = find_word_left_col(line, p.col)
            local ec = p.col
            if p.col < #line then
              local curc = line:sub(p.col + 1, p.col + 1)
              if curc:match('[%w_]') then
                ec = p.col + 1
              end
            end
            vim.api.nvim_buf_set_text(state.bufnr, p.row, sc, p.row, ec, { '' })
            state_mod.set_pos(state, i, p.row, sc)
            state_mod.set_anchor(state, i, p.row, sc)
          end
        elseif kind == 'ctrl_u' then
          if p.col > 0 then
            vim.api.nvim_buf_set_text(state.bufnr, p.row, 0, p.row, p.col, { '' })
            state_mod.set_pos(state, i, p.row, 0)
            state_mod.set_anchor(state, i, p.row, 0)
          end
        end
      end
    end
    render.sync(state)
    set_cursor_to_main()
    return true
  end

  return false
end

---@param kind string
---@param fallback string
---@return string
function M.handle_insert_special(kind, fallback)
  local state = state_mod.current()
  if not state.insert_active or #state.cursors == 0 then
    return fallback or ''
  end
  if kind == 'replace_toggle' then
    state.replace_mode = not state.replace_mode
    return fallback or ''
  end
  if kind == 'ctrl_o' or kind == 'ctrl_caret' then
    if state.insert_pending then
      vim.schedule(function()
        pcall(function()
          while M.apply_pending_insert({ skip_render = true }) do
          end
          render.sync(state_mod.current())
        end)
      end)
    end
    return fallback or ''
  end
  if kind == 'esc' then
    return fallback or '<Esc>'
  end
  if kind == 'ctrl_c' then
    vim.schedule(function()
      local st = state_mod.current()
      if st.insert_active then
        pcall(M.end_insert)
      end
    end)
    return '<C-c>'
  end
  local handled = {
    left = true,
    right = true,
    home = true,
    ['end'] = true,
    up = true,
    down = true,
    word_left = true,
    word_right = true,
    bs = true,
    del = true,
    ctrl_d = true,
    cr = true,
    ctrl_w = true,
    ctrl_u = true,
  }
  if not handled[kind] then
    return fallback or ''
  end
  vim.schedule(function()
    pcall(M.apply_insert_special_now, kind)
  end)
  return ''
end

---@param kind string|nil
---@return nil
function M.insert_prompt(kind)
  local state = state_mod.current()
  ensure_started(state)

  local verbose = config.values.verbose_commands
  local label = (kind == 'append' or kind == 'append_eol') and 'Append text: ' or 'Insert text: '
  if verbose then
    label = 'MultiCursor ' .. label
  end
  local text = vim.fn.input(label)
  if text == nil then
    return
  end

  local idxs = state_mod.sort_indices_desc(state)
  for _, i in ipairs(idxs) do
    local p = state_mod.cursor_pos(state, i)
    if p then
      local row, col = p.row, p.col
      if state.mode == 'extend' and not (p.row == p.arow and p.col == p.acol) then
        local sr, sc, er, ec = selection_range(p)
        vim.api.nvim_buf_set_text(state.bufnr, sr, sc, er, ec, { text })
        state_mod.set_pos(state, i, sr, sc + vim.fn.strchars(text))
        state_mod.set_anchor(state, i, sr, sc + vim.fn.strchars(text))
      else
        if kind == 'append' then
          col = math.min(col + 1, line_len(state.bufnr, row))
        elseif kind == 'insert_sol' then
          col = 0
        elseif kind == 'append_eol' then
          col = line_len(state.bufnr, row)
        end
        vim.api.nvim_buf_set_text(state.bufnr, row, col, row, col, { text })
        state_mod.set_pos(state, i, row, col + vim.fn.strchars(text))
        state_mod.set_anchor(state, i, row, col + vim.fn.strchars(text))
      end
    end
  end

  state.mode = 'cursor'
  state.extend_manual = false
  finalize(state)
end

---@return nil
function M.yank()
  local state = state_mod.current()
  ensure_started(state)
  local reg = register_name(true)

  local idxs = sorted_indices(state, true)
  local items = {}
  local has_selection = false

  for _, i in ipairs(idxs) do
    local p = state_mod.cursor_pos(state, i)
    if p then
      if state.mode == 'extend' and is_extended(p) then
        has_selection = true
        local sr, sc, er, ec = action_selection_range(state, p)
        local lines = vim.api.nvim_buf_get_text(state.bufnr, sr, sc, er, ec, {})
        table.insert(items, table.concat(lines, '\n'))
      else
        table.insert(items, line_text(state.bufnr, p.row))
      end
    end
  end

  local kind = has_selection and 'char' or 'line'
  store_yank(items, kind, reg)
end

---@param as_delete boolean|nil
---@return nil
function M.yank_exact_selection(as_delete)
  local state = state_mod.current()
  ensure_started(state)
  if state.mode ~= 'extend' then
    M.yank()
    return
  end
  store_selection_yank_exact(state, as_delete and { as_delete = true } or nil)
end

local function paste_single_block(data, after)
  if not data or type(data.items) ~= 'table' or #data.items == 0 then
    return false
  end
  if #data.items == 1 then
    return false
  end

  local cur = vim.api.nvim_win_get_cursor(0)
  local row, col = cur[1] - 1, cur[2]

  if data.kind == 'line' then
    local at = after and (row + 1) or row
    vim.api.nvim_buf_set_lines(0, at, at, false, data.items)
    vim.api.nvim_win_set_cursor(0, { at + 1, 0 })
  else
    local text = table.concat(data.items, '\n')
    local lines = split_lines(text)
    local insert_col = col
    if after then
      insert_col = math.min(col + 1, line_len(0, row))
    end
    vim.api.nvim_buf_set_text(0, row, insert_col, row, insert_col, lines)
    local erow, ecol = end_pos_from_text(row, insert_col, text)
    vim.api.nvim_win_set_cursor(0, { erow + 1, ecol })
  end
  return true
end

---@param after boolean
---@return boolean
function M.paste_single_cursor(after)
  local state = state_mod.current()
  local reg = register_name(true)
  local ok = paste_single_block(get_yank(reg), after)
  if ok then
    remember_dot(state, { kind = 'paste', after = after, multi = false })
  end
  return ok
end

---@param bufnr integer
---@param row integer
---@param col integer
---@return integer, integer
local function to_inclusive_pos(bufnr, row, col)
  if col > 0 then
    return row, col - 1
  end
  if row > 0 then
    local prev_len = line_len(bufnr, row - 1)
    if prev_len > 0 then
      return row - 1, prev_len - 1
    end
    return row - 1, 0
  end
  return 0, 0
end

---@param after boolean
---@return nil
function M.paste_multicursor(after)
  local state = state_mod.current()
  ensure_started(state)
  local reg = register_name(true)
  local data = get_yank(reg)
  if not data or type(data.items) ~= 'table' or #data.items == 0 then
    return
  end

  local asc = sorted_indices(state, true)
  local text_for_idx = {}
  for order, idx in ipairs(asc) do
    local pick = math.min(order, #data.items)
    text_for_idx[idx] = data.items[pick]
  end

  local desc = sorted_indices(state, false)
  local changed = false
  for _, idx in ipairs(desc) do
    local p = state_mod.cursor_pos(state, idx)
    local text = text_for_idx[idx]
    if p and text then
      if data.kind == 'line' then
        -- Legacy VM treats multicursor linewise p/P with after-line insertion.
        local at = p.row + 1
        changed = undojoin_next(changed)
        vim.api.nvim_buf_set_lines(state.bufnr, at, at, false, { text })
        state_mod.set_pos(state, idx, at, 0)
        state_mod.set_anchor(state, idx, at, 0)
      else
        local insert_col = p.col
        if after then
          insert_col = math.min(p.col + 1, line_len(state.bufnr, p.row))
        end
        local lines = split_lines(text)
        changed = undojoin_next(changed)
        vim.api.nvim_buf_set_text(state.bufnr, p.row, insert_col, p.row, insert_col, lines)
        local erow, ecol = end_pos_from_text(p.row, insert_col, text)
        local crow, ccol = to_inclusive_pos(state.bufnr, erow, ecol)
        state_mod.set_pos(state, idx, crow, ccol)
        state_mod.set_anchor(state, idx, crow, ccol)
      end
    end
  end

  state.mode = 'cursor'
  state.extend_manual = false
  remember_dot(state, { kind = 'paste', after = after, multi = true })
  finalize(state)
end

---@param keys string
---@param remap boolean|nil
function M.apply_normal(keys, remap)
  local state = state_mod.current()
  ensure_started(state)
  local save = vim.api.nvim_win_get_cursor(0)
  local tc_keys = vim.api.nvim_replace_termcodes(keys, true, false, true)
  if remap == nil then
    remap = config.values.recursive_operations_at_cursors
  end

  vim.g.multi_cursor_bypass_maps = 1
  local idxs = sorted_indices(state, false)
  local changed = false
  for _, i in ipairs(idxs) do
    local p = state_mod.cursor_pos(state, i)
    if p then
      local row = math.max(1, math.min(p.row + 1, vim.api.nvim_buf_line_count(state.bufnr)))
      local col = clamp(state.bufnr, row - 1, p.col)
      vim.api.nvim_win_set_cursor(0, { row, col })
      changed = undojoin_next(changed)
      vim.cmd.normal({ args = { tc_keys }, bang = not remap })
      local cur = vim.api.nvim_win_get_cursor(0)
      state_mod.set_pos(state, i, cur[1] - 1, cur[2])
      state_mod.set_anchor(state, i, cur[1] - 1, cur[2])
    end
  end

  local max_row = vim.api.nvim_buf_line_count(state.bufnr)
  local row = math.max(1, math.min(save[1], max_row))
  local col = clamp(state.bufnr, row - 1, save[2])
  vim.api.nvim_win_set_cursor(0, { row, col })
  vim.g.multi_cursor_bypass_maps = 0
  state.mode = 'cursor'
  state.extend_manual = false
  finalize(state)
end

---@param lhs string
---@param rhs string|nil
function M.apply_mapped_motion(lhs, rhs)
  rhs = rhs or lhs
  if rhs == '' then
    rhs = lhs
  end

  -- Character-find motions require a target character. Read it once and
  -- replay the same motion at each cursor location.
  if rhs:match('^%d*[fFtT]$') then
    local target = getchar_char()
    if target == nil or target == '' then
      return false
    end
    rhs = rhs .. target
  end

  -- Keep this path for simple RHS mappings (example: lhs->motion).
  if rhs:find('<[Cc][Mm][Dd]>') or rhs:find('<[Pp][Ll][Uu][Gg]>') then
    return M.apply_normal(lhs, true)
  end

  local state = state_mod.current()
  ensure_started(state)
  local save = vim.api.nvim_win_get_cursor(0)
  local tc_keys = vim.api.nvim_replace_termcodes(rhs, true, false, true)

  vim.g.multi_cursor_bypass_maps = 1
  local idxs = sorted_indices(state, false)
  for _, i in ipairs(idxs) do
    local p = state_mod.cursor_pos(state, i)
    if p then
      local row = math.max(1, math.min(p.row + 1, vim.api.nvim_buf_line_count(state.bufnr)))
      local col = clamp(state.bufnr, row - 1, p.col)
      vim.api.nvim_win_set_cursor(0, { row, col })
      vim.cmd.normal({ args = { tc_keys }, bang = true })
      local cur = vim.api.nvim_win_get_cursor(0)
      state_mod.set_pos(state, i, cur[1] - 1, cur[2])
      if state.mode == 'extend' then
        state_mod.set_anchor(state, i, p.arow, p.acol)
      else
        state_mod.set_anchor(state, i, cur[1] - 1, cur[2])
      end
    end
  end

  local max_row = vim.api.nvim_buf_line_count(state.bufnr)
  local row = math.max(1, math.min(save[1], max_row))
  local col = clamp(state.bufnr, row - 1, save[2])
  vim.api.nvim_win_set_cursor(0, { row, col })
  vim.g.multi_cursor_bypass_maps = 0
  finalize(state)
  return true
end

---@return table
function M.info()
  local state = state_mod.current()
  return {
    enabled = state.enabled,
    mode = state.mode,
    current = state.current,
    total = #state.cursors,
    single_region = state.single_region,
    multiline = state.multiline,
    maps_enabled = state.maps_enabled ~= false,
    direction = state.direction,
    pattern = state.search[1] or '',
  }
end

local function normalize_mouse_target(row, col)
  if type(row) == 'number' and type(col) == 'number' then
    return math.max(0, row), math.max(0, col)
  end
  local mp = vim.fn.getmousepos()
  if type(mp) == 'table' and tonumber(mp.winid) == vim.api.nvim_get_current_win() then
    local mr = tonumber(mp.line) or 0
    local mc = tonumber(mp.column) or 1
    if mr > 0 then
      return mr - 1, math.max(0, mc - 1)
    end
  end
  local cur = vim.api.nvim_win_get_cursor(0)
  return cur[1] - 1, cur[2]
end

---@param row integer|nil
---@param col integer|nil
function M.mouse_cursor(row, col)
  local tr, target_col = normalize_mouse_target(row, col)
  local line_count = vim.api.nvim_buf_line_count(0)
  tr = math.max(0, math.min(tr, line_count - 1))
  target_col = clamp(0, tr, target_col)
  vim.api.nvim_win_set_cursor(0, { tr + 1, target_col })
  M.add_cursor_at_pos()
end

---@param row integer|nil
---@param col integer|nil
function M.mouse_word(row, col)
  local tr, target_col = normalize_mouse_target(row, col)
  local line_count = vim.api.nvim_buf_line_count(0)
  tr = math.max(0, math.min(tr, line_count - 1))
  target_col = clamp(0, tr, target_col)
  vim.api.nvim_win_set_cursor(0, { tr + 1, target_col })
  M.find_under()
end

---@param row integer|nil
---@param col integer|nil
function M.mouse_column(row, col)
  local start = vim.api.nvim_win_get_cursor(0)
  local tr, target_col = normalize_mouse_target(row, col)
  local line_count = vim.api.nvim_buf_line_count(0)
  tr = math.max(0, math.min(tr, line_count - 1))
  target_col = clamp(0, tr, target_col)

  local state = state_mod.current()
  ensure_started(state)
  state.mode = 'cursor'
  state.extend_manual = false
  state.current = state_mod.exists_at(state, start[1] - 1, start[2]) or state.current
  vim.api.nvim_win_set_cursor(0, { start[1], start[2] })
  if tr > (start[1] - 1) then
    M.add_cursor_vertical(1, tr - (start[1] - 1))
  elseif tr < (start[1] - 1) then
    M.add_cursor_vertical(-1, (start[1] - 1) - tr)
  end
  vim.api.nvim_win_set_cursor(0, { tr + 1, target_col })
end

return M
