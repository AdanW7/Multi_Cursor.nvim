local config = require('multi_cursor.config')

---@class MultiCursorPickerModule
---@field select fun(items: {id:string,label:string,aliases:string[]|nil}[], opts: table|nil, on_choice: fun(item:table|nil)|nil): boolean
---@field select_matches fun(bufnr:integer, pat:string, matches:table[], on_choice:fun(match:table|nil, filtered:table[]|nil)|nil): boolean
---@field backend fun(): string
local M = {}

---@return boolean, table|nil
local function get_telescope()
  local ok, t = pcall(require, 'telescope')
  if not ok or type(t) ~= 'table' then
    return false, nil
  end
  return true, t
end

---@return boolean, table|nil
local function get_snacks_picker()
  local ok_s, s = pcall(require, 'snacks')
  if ok_s and type(s) == 'table' and type(s.picker) == 'table' then
    return true, s.picker
  end
  local ok_p, p = pcall(require, 'snacks.picker')
  if ok_p and type(p) == 'table' then
    return true, p
  end
  return false, nil
end

---@return string
function M.backend()
  local preferred = tostring(config.values.picker or 'auto')
  if preferred == 'telescope' then
    local ok = get_telescope()
    return ok and 'telescope' or 'builtin'
  end
  if preferred == 'snacks' then
    local ok = get_snacks_picker()
    return ok and 'snacks' or 'builtin'
  end
  if preferred == 'builtin' then
    return 'builtin'
  end
  local ok_t = get_telescope()
  if ok_t then
    return 'telescope'
  end
  local ok_s = get_snacks_picker()
  if ok_s then
    return 'snacks'
  end
  return 'builtin'
end

---@param items {id:string,label:string,aliases:string[]|nil}[]
---@param opts table|nil
---@param on_choice fun(item:table|nil)|nil
---@return boolean
local function builtin_select(items, opts, on_choice)
  local prompt = (type(opts) == 'table' and opts.prompt_title) or 'Select'
  local lines = { tostring(prompt) }
  for i, item in ipairs(items) do
    lines[#lines + 1] = string.format('%d. %s (%s)', i, item.label, item.id)
  end
  lines[#lines + 1] = '0. cancel'
  local idx = tonumber(vim.fn.inputlist(lines))
  if idx == nil or idx <= 0 or idx > #items then
    if on_choice then
      on_choice(nil)
    end
    return false
  end
  if on_choice then
    on_choice(items[idx])
  end
  return true
end

---@param items {id:string,label:string,aliases:string[]|nil}[]
---@param opts table|nil
---@param on_choice fun(item:table|nil)|nil
---@return boolean
local function telescope_select(items, opts, on_choice)
  local ok_t, _ = get_telescope()
  if not ok_t then
    return false
  end
  local ok_p, pickers = pcall(require, 'telescope.pickers')
  local ok_f, finders = pcall(require, 'telescope.finders')
  local ok_c, conf = pcall(require, 'telescope.config')
  local ok_a, actions = pcall(require, 'telescope.actions')
  local ok_s, action_state = pcall(require, 'telescope.actions.state')
  if not (ok_p and ok_f and ok_c and ok_a and ok_s) then
    return false
  end
  local prompt = (type(opts) == 'table' and opts.prompt_title) or 'MultiCursor'
  local picker = pickers.new({}, {
    prompt_title = prompt,
    finder = finders.new_table({
      results = items,
      entry_maker = function(item)
        return {
          value = item,
          display = string.format('%s (%s)', item.label, item.id),
          ordinal = item.label .. ' ' .. item.id,
        }
      end,
    }),
    sorter = conf.values.generic_sorter({}),
    attach_mappings = function(prompt_bufnr)
      actions.select_default:replace(function()
        local entry = action_state.get_selected_entry()
        actions.close(prompt_bufnr)
        if on_choice then
          on_choice(entry and entry.value or nil)
        end
      end)
      return true
    end,
  })
  picker:find()
  return true
end

---@param items {id:string,label:string,aliases:string[]|nil}[]
---@param opts table|nil
---@param on_choice fun(item:table|nil)|nil
---@return boolean
local function snacks_select(items, opts, on_choice)
  local ok_s, picker = get_snacks_picker()
  if not ok_s or not picker then
    return false
  end
  if type(picker.select) == 'function' then
    local prompt = (type(opts) == 'table' and opts.prompt_title) or 'MultiCursor'
    local ok = pcall(picker.select, items, {
      prompt = prompt,
      format_item = function(item)
        return string.format('%s (%s)', item.label, item.id)
      end,
    }, on_choice)
    if ok then
      return true
    end
  end
  return false
end

---@param items {id:string,label:string,aliases:string[]|nil}[]
---@param opts table|nil
---@param on_choice fun(item:table|nil)|nil
---@return boolean
function M.select(items, opts, on_choice)
  local b = M.backend()
  if b == 'telescope' and telescope_select(items, opts, on_choice) then
    return true
  end
  if b == 'snacks' and snacks_select(items, opts, on_choice) then
    return true
  end
  return builtin_select(items, opts, on_choice)
end

---@param bufnr integer
---@param row integer
---@return string
local function line_text(bufnr, row)
  return vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1] or ''
end

---@param bufnr integer
---@param pat string
---@param matches table[]
---@param on_choice fun(match:table|nil, filtered:table[]|nil)|nil
---@return boolean
local function builtin_select_matches(bufnr, pat, matches, on_choice)
  local lines = { string.format('MultiCursor regex: %s', pat) }
  for i, m in ipairs(matches) do
    local txt = line_text(bufnr, m.row)
    lines[#lines + 1] = string.format('%d. %d:%d  %s', i, m.row + 1, m.col + 1, txt)
  end
  lines[#lines + 1] = '0. cancel'
  local idx = tonumber(vim.fn.inputlist(lines))
  if idx == nil or idx <= 0 or idx > #matches then
    if on_choice then
      on_choice(nil, nil)
    end
    return false
  end
  if on_choice then
    on_choice(matches[idx], { matches[idx] })
  end
  return true
end

---@param prompt_bufnr integer
---@return table[]
local function telescope_filtered_values(prompt_bufnr)
  local ok_s, action_state = pcall(require, 'telescope.actions.state')
  if not ok_s then
    return {}
  end
  local current = action_state.get_current_picker(prompt_bufnr)
  if not current or not current.manager or type(current.manager.iter) ~= 'function' then
    return {}
  end
  local out = {}
  for entry in current.manager:iter() do
    if entry and entry.value then
      table.insert(out, entry.value)
    end
  end
  return out
end

---@param bufnr integer
---@param pat string
---@param matches table[]
---@param on_choice fun(match:table|nil, filtered:table[]|nil)|nil
---@return boolean
local function telescope_select_matches(bufnr, pat, matches, on_choice)
  local ok_t, _ = get_telescope()
  if not ok_t then
    return false
  end
  local ok_p, pickers = pcall(require, 'telescope.pickers')
  local ok_f, finders = pcall(require, 'telescope.finders')
  local ok_c, conf = pcall(require, 'telescope.config')
  local ok_a, actions = pcall(require, 'telescope.actions')
  local ok_s, action_state = pcall(require, 'telescope.actions.state')
  local ok_v, previewers = pcall(require, 'telescope.previewers')
  if not (ok_p and ok_f and ok_c and ok_a and ok_s and ok_v) then
    return false
  end

  local items = vim.deepcopy(matches)
  local function build_finder()
    return finders.new_table({
      results = items,
      entry_maker = function(m)
        local txt = line_text(bufnr, m.row)
        return {
          value = m,
          display = string.format('%d:%d  %s', m.row + 1, m.col + 1, txt),
          ordinal = string.format('%d %d %s', m.row + 1, m.col + 1, txt),
        }
      end,
    })
  end

  local picker = pickers.new({}, {
    prompt_title = string.format('MultiCursor Regex: %s', pat),
    finder = build_finder(),
    previewer = previewers.new_buffer_previewer({
      title = 'Match Preview',
      define_preview = function(self, entry, _)
        local m = entry.value
        local line_count = vim.api.nvim_buf_line_count(bufnr)
        local start_row = math.max(0, m.row - 3)
        local end_row = math.min(line_count, m.row + 4)
        local src = vim.api.nvim_buf_get_lines(bufnr, start_row, end_row, false)
        local out = {}
        for i, l in ipairs(src) do
          local ln = start_row + i
          out[#out + 1] = string.format('%4d %s', ln, l)
        end
        vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, out)
      end,
    }),
    sorter = conf.values.generic_sorter({}),
    attach_mappings = function(prompt_bufnr, map)
      actions.select_default:replace(function()
        local entry = action_state.get_selected_entry()
        local filtered = telescope_filtered_values(prompt_bufnr)
        actions.close(prompt_bufnr)
        if on_choice then
          on_choice(entry and entry.value or nil, filtered)
        end
      end)
      local function refresh()
        local current = action_state.get_current_picker(prompt_bufnr)
        if current then
          current:refresh(build_finder(), { reset_prompt = false })
        end
      end
      local function delete_selected()
        local entry = action_state.get_selected_entry()
        if not entry or not entry.value then
          return
        end
        for i, m in ipairs(items) do
          if m.row == entry.value.row and m.col == entry.value.col then
            table.remove(items, i)
            break
          end
        end
        refresh()
      end
      map('i', '<C-d>', delete_selected)
      map('n', 'd', delete_selected)
      return true
    end,
  })
  picker:find()
  return true
end

---@param bufnr integer
---@param pat string
---@param matches table[]
---@param on_choice fun(match:table|nil, filtered:table[]|nil)|nil
---@return boolean
local function snacks_select_matches(bufnr, pat, matches, on_choice)
  local ok_s, picker = get_snacks_picker()
  if not ok_s or not picker or type(picker.select) ~= 'function' then
    return false
  end
  local ok = pcall(picker.select, matches, {
    prompt = string.format('MultiCursor Regex: %s', pat),
    format_item = function(m)
      return string.format('%d:%d  %s', m.row + 1, m.col + 1, line_text(bufnr, m.row))
    end,
  }, on_choice)
  return ok
end

---@param bufnr integer
---@param pat string
---@param matches table[]
---@param on_choice fun(match:table|nil, filtered:table[]|nil)|nil
---@return boolean
function M.select_matches(bufnr, pat, matches, on_choice)
  local b = M.backend()
  if b == 'telescope' and telescope_select_matches(bufnr, pat, matches, on_choice) then
    return true
  end
  if b == 'snacks' and snacks_select_matches(bufnr, pat, matches, on_choice) then
    return true
  end
  return builtin_select_matches(bufnr, pat, matches, on_choice)
end

return M
