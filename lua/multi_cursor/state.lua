---@class MultiCursorStateModule
---@field ns integer
---@field buffers table<integer, MultiCursorState>
---@field registers table<string, MultiCursorRegister>
local M = {}
local config = require('multi_cursor.config')

M.ns = vim.api.nvim_create_namespace('multi_cursor.nvim')
M.buffers = {}
M.registers = {
  ['"'] = { items = {}, kind = 'line' },
}

---@param bufnr integer
---@return integer
local function buffer_size(bufnr)
  local line_count = vim.api.nvim_buf_line_count(bufnr)
  if vim.api.nvim_buf_get_offset ~= nil then
    local ok, off = pcall(vim.api.nvim_buf_get_offset, bufnr, line_count)
    if ok and type(off) == 'number' then
      return off
    end
  end
  local total = 0
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  for _, line in ipairs(lines) do
    total = total + #line + 1
  end
  return total
end

---@param bufnr integer
---@return MultiCursorState
local function by_buf(bufnr)
  local state = M.buffers[bufnr]
  if state then
    return state
  end
  state = {
    bufnr = bufnr,
    mode = 'cursor',
    single_region = false,
    multiline = false,
    direction = 1,
    nav_direction = 1,
    current = 1,
    search = {},
    cursors = {},
    enabled = false,
    maps_enabled = true,
    next_id = 1,
    last_cursors = {},
    last_normal = nil,
    last_dot = nil,
    last_visual = nil,
    last_ex = nil,
    insert_active = false,
    insert_pending = nil,
    pending_register = nil,
    insert_single_entry = false,
    insert_prev_synmaxcol = nil,
    replace_mode = false,
    extend_manual = false,
    statusline_prev = nil,
    statusline_initialized = false,
    old_smartcase = nil,
    old_ignorecase = nil,
    disabled_plugins = {},
  }
  M.buffers[bufnr] = state
  return state
end

---@param state MultiCursorState
local function apply_case_setting(state)
  local mode = config.values.case_setting
  if type(mode) ~= 'string' or mode == '' then
    return
  end
  if state.old_smartcase == nil then
    state.old_smartcase = vim.o.smartcase
    state.old_ignorecase = vim.o.ignorecase
  end
  if mode == 'smart' then
    vim.o.smartcase = true
    vim.o.ignorecase = true
  elseif mode == 'sensitive' then
    vim.o.smartcase = false
    vim.o.ignorecase = false
  elseif mode == 'ignore' then
    vim.o.smartcase = false
    vim.o.ignorecase = true
  end
end

---@param state MultiCursorState
local function restore_case_setting(state)
  if state.old_smartcase == nil then
    return
  end
  vim.o.smartcase = state.old_smartcase
  vim.o.ignorecase = state.old_ignorecase
  state.old_smartcase = nil
  state.old_ignorecase = nil
end

---@param rule MultiCursorCompatRule|nil
---@return boolean
local function test_plugin_rule(rule)
  if type(rule) ~= 'table' then
    return false
  end
  local t = rule.test
  if type(t) == 'function' then
    local ok, ret = pcall(t)
    return ok and ret == true
  end
  if type(t) == 'string' and t ~= '' then
    local ok, ret = pcall(vim.api.nvim_eval, t)
    return ok and (ret == 1 or ret == true)
  end
  return false
end

---@param cmd string|nil
---@return boolean
local function exec_plugin_cmd(cmd)
  if type(cmd) ~= 'string' or cmd == '' then
    return false
  end
  local ok = pcall(function()
    vim.cmd(cmd)
  end)
  return ok
end

---@param state MultiCursorState
local function apply_plugin_compat(state)
  state.disabled_plugins = {}
  local rules = config.values.plugins_compatibility
  if type(rules) ~= 'table' then
    return
  end
  for name, rule in pairs(rules) do
    if test_plugin_rule(rule) then
      if exec_plugin_cmd(rule.disable) then
        table.insert(state.disabled_plugins, name)
      end
    end
  end
end

---@param state MultiCursorState
local function restore_plugin_compat(state)
  local rules = config.values.plugins_compatibility
  if type(rules) ~= 'table' then
    state.disabled_plugins = {}
    return
  end
  for _, name in ipairs(state.disabled_plugins or {}) do
    local rule = rules[name]
    if type(rule) == 'table' then
      exec_plugin_cmd(rule.enable)
    end
  end
  state.disabled_plugins = {}
end

---@return MultiCursorState
function M.current()
  return by_buf(vim.api.nvim_get_current_buf())
end

---@param bufnr integer
---@return MultiCursorState
function M.get(bufnr)
  return by_buf(bufnr)
end

---@param state MultiCursorState
---@param row integer
---@param col integer
---@return integer|nil
function M.exists_at(state, row, col)
  for i, c in ipairs(state.cursors) do
    local pos = vim.api.nvim_buf_get_extmark_by_id(state.bufnr, M.ns, c.id, {})
    if #pos > 0 and pos[1] == row and pos[2] == col then
      return i
    end
  end
  return nil
end

---@param state MultiCursorState
---@param idx integer
---@return MultiCursorCursorPos|nil
function M.cursor_pos(state, idx)
  local c = state.cursors[idx]
  if not c then
    return nil
  end
  local p = vim.api.nvim_buf_get_extmark_by_id(state.bufnr, M.ns, c.id, {})
  local a = vim.api.nvim_buf_get_extmark_by_id(state.bufnr, M.ns, c.anchor_id, {})
  if #p == 0 or #a == 0 then
    return nil
  end
  return { row = p[1], col = p[2], arow = a[1], acol = a[2] }
end

---@param state MultiCursorState
---@param row integer
---@param col integer
---@param opts table|nil
---@return boolean
function M.add_cursor(state, row, col, opts)
  opts = opts or {}
  local first = #state.cursors == 0
  if #state.cursors == 0 then
    local limit = tonumber(config.values.filesize_limit) or 0
    if limit > 0 and buffer_size(state.bufnr) > limit then
      if config.values.show_warnings then
        vim.notify('MultiCursor cannot start: buffer too big.', vim.log.levels.WARN)
      end
      return false
    end
  end
  local found = M.exists_at(state, row, col)
  if found and opts.toggle then
    M.remove_cursor(state, found)
    return false
  end
  if found then
    state.current = found
    return false
  end

  local id = vim.api.nvim_buf_set_extmark(state.bufnr, M.ns, row, col, { right_gravity = false })
  local anchor_id =
    vim.api.nvim_buf_set_extmark(state.bufnr, M.ns, row, col, { right_gravity = false })
  table.insert(state.cursors, { id = id, anchor_id = anchor_id, user_id = state.next_id })
  state.next_id = state.next_id + 1
  state.current = #state.cursors
  state.enabled = true
  if first then
    apply_case_setting(state)
    apply_plugin_compat(state)
  end
  return true
end

---@return nil
function M.load_persistent_registers()
  local raw = vim.g.multi_cursor_registers_store
  if type(raw) ~= 'table' then
    return
  end
  local out = {}
  for reg, v in pairs(raw) do
    if type(reg) == 'string' and type(v) == 'table' and type(v.items) == 'table' then
      out[reg] = { items = vim.deepcopy(v.items), kind = v.kind or 'line' }
    end
  end
  if next(out) ~= nil then
    M.registers = out
    if M.registers['"'] == nil then
      M.registers['"'] = { items = {}, kind = 'line' }
    end
  end
end

---@return nil
function M.save_persistent_registers()
  vim.g.multi_cursor_registers_store = vim.deepcopy(M.registers)
end

---@param state MultiCursorState
---@param idx integer
function M.remove_cursor(state, idx)
  local c = state.cursors[idx]
  if not c then
    return
  end
  vim.api.nvim_buf_del_extmark(state.bufnr, M.ns, c.id)
  vim.api.nvim_buf_del_extmark(state.bufnr, M.ns, c.anchor_id)
  table.remove(state.cursors, idx)

  if state.current > #state.cursors then
    state.current = #state.cursors
  end
  if state.current < 1 then
    state.current = 1
  end
  if #state.cursors == 0 then
    state.enabled = false
    state.search = {}
    state.mode = 'cursor'
    state.single_region = false
    state.multiline = false
    state.maps_enabled = true
    state.direction = 1
    state.nav_direction = 1
    state.last_normal = nil
    state.last_dot = nil
    state.last_visual = nil
    state.last_ex = nil
    state.insert_active = false
    state.insert_pending = nil
    state.pending_register = nil
    state.insert_single_entry = false
    state.insert_prev_synmaxcol = nil
    state.replace_mode = false
    state.extend_manual = false
    state.statusline_prev = nil
    state.statusline_initialized = false
    restore_case_setting(state)
    restore_plugin_compat(state)
  end
end

---@param state MultiCursorState
function M.clear(state)
  state.last_cursors = {}
  for i = 1, #state.cursors do
    local p = M.cursor_pos(state, i)
    if p then
      table.insert(state.last_cursors, { row = p.row, col = p.col, arow = p.arow, acol = p.acol })
    end
  end
  for i = #state.cursors, 1, -1 do
    M.remove_cursor(state, i)
  end
  vim.api.nvim_buf_clear_namespace(state.bufnr, M.ns, 0, -1)
  state.cursors = {}
  state.current = 1
  state.enabled = false
  state.mode = 'cursor'
  state.single_region = false
  state.multiline = false
  state.maps_enabled = true
  state.direction = 1
  state.nav_direction = 1
  state.last_normal = nil
  state.last_dot = nil
  state.last_visual = nil
  state.last_ex = nil
  state.insert_active = false
  state.insert_pending = nil
  state.pending_register = nil
  state.insert_single_entry = false
  state.insert_prev_synmaxcol = nil
  state.replace_mode = false
  state.extend_manual = false
  state.statusline_prev = nil
  state.statusline_initialized = false
  restore_case_setting(state)
  restore_plugin_compat(state)
  state.search = {}
end

---@param state MultiCursorState
---@return boolean
function M.restore_last(state)
  if type(state.last_cursors) ~= 'table' or #state.last_cursors == 0 then
    return false
  end
  for _, p in ipairs(state.last_cursors) do
    M.add_cursor(state, p.row, p.col, {})
    local idx = #state.cursors
    M.set_anchor(state, idx, p.arow or p.row, p.acol or p.col)
  end
  return #state.cursors > 0
end

---@param state MultiCursorState
---@param idx integer
---@param row integer
---@param col integer
function M.set_pos(state, idx, row, col)
  local c = state.cursors[idx]
  if not c then
    return
  end
  vim.api.nvim_buf_set_extmark(state.bufnr, M.ns, row, col, { id = c.id, right_gravity = false })
end

---@param state MultiCursorState
---@param idx integer
---@param row integer
---@param col integer
function M.set_anchor(state, idx, row, col)
  local c = state.cursors[idx]
  if not c then
    return
  end
  vim.api.nvim_buf_set_extmark(
    state.bufnr,
    M.ns,
    row,
    col,
    { id = c.anchor_id, right_gravity = false }
  )
end

---@param state MultiCursorState
---@return integer[]
function M.sort_indices_desc(state)
  local idxs = {}
  for i = 1, #state.cursors do
    idxs[i] = i
  end
  table.sort(idxs, function(a, b)
    local pa = M.cursor_pos(state, a)
    local pb = M.cursor_pos(state, b)
    if not pa and not pb then
      return a > b
    end
    if not pa then
      return false
    end
    if not pb then
      return true
    end
    if pa.row == pb.row then
      return pa.col > pb.col
    end
    return pa.row > pb.row
  end)
  return idxs
end

---@param state MultiCursorState
---@return integer[]
function M.sort_indices_asc(state)
  local idxs = {}
  for i = 1, #state.cursors do
    idxs[i] = i
  end
  table.sort(idxs, function(a, b)
    local pa = M.cursor_pos(state, a)
    local pb = M.cursor_pos(state, b)
    if not pa and not pb then
      return a < b
    end
    if not pa then
      return false
    end
    if not pb then
      return true
    end
    if pa.row == pb.row then
      return pa.col < pb.col
    end
    return pa.row < pb.row
  end)
  return idxs
end

return M
