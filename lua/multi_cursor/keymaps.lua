local config = require('multi_cursor.config')
local state_mod = require('multi_cursor.state')
local actions = require('multi_cursor.actions')

---@class MultiCursorKeymapsModule
---@field setup fun()
---@field conflicts fun(): string[]
local M = {}
local mapped = false
local map_conflicts = {}
local map_descriptions = {}
local claimed = { n = {}, x = {}, i = {} }

---@param lhs string|string[]|nil
---@return string[]
local function lhs_list(lhs)
  if type(lhs) == 'string' then
    if lhs == '' then
      return {}
    end
    return { lhs }
  end
  if type(lhs) == 'table' then
    local out = {}
    for _, v in ipairs(lhs) do
      if type(v) == 'string' and v ~= '' then
        table.insert(out, v)
      end
    end
    return out
  end
  return {}
end

local function refresh_map_descriptions()
  map_descriptions = {}
  local mappings = config.values.mappings or {}
  for name, lhs in pairs(mappings) do
    for _, key in ipairs(lhs_list(lhs)) do
      if map_descriptions[key] == nil then
        map_descriptions[key] = string.format('MultiCursor: %s', name:gsub('_', ' '))
      end
    end
  end
end

---@param lhs string|nil
---@param fallback string|nil
---@return string
local function map_desc(lhs, fallback)
  if type(lhs) == 'string' and lhs ~= '' and map_descriptions[lhs] then
    return map_descriptions[lhs]
  end
  if type(fallback) == 'string' and fallback ~= '' and map_descriptions[fallback] then
    return map_descriptions[fallback]
  end
  return 'MultiCursor'
end

---@return boolean
local function active()
  local state = state_mod.current()
  return state.enabled and #state.cursors > 0
end

---@return boolean
local function mappings_enabled()
  local state = state_mod.current()
  if state.maps_enabled == nil then
    return true
  end
  return state.maps_enabled
end

---@param lhs string|string[]|nil
---@return string
local function fallback_for(lhs)
  local key = lhs
  if type(lhs) == 'table' then
    key = lhs[1]
  end
  if type(key) ~= 'string' or key == '' then
    return ''
  end
  local map = vim.fn.maparg(key, 'n', false, true)
  if type(map) == 'table' and map.rhs and map.rhs ~= '' then
    return map.rhs
  end
  return key
end

---@param keys string
local function feed(keys)
  local tc = vim.api.nvim_replace_termcodes(keys, true, false, true)
  vim.api.nvim_feedkeys(tc, 'n', false)
end

---@param keys string
local function feed_remap(keys)
  local tc = vim.api.nvim_replace_termcodes(keys, true, false, true)
  vim.api.nvim_feedkeys(tc, 'm', false)
end

---@param keys string
local function normal_bang(keys)
  local tc = vim.api.nvim_replace_termcodes(keys, true, false, true)
  vim.cmd.normal({ args = { tc }, bang = true })
end

---@param lhs string
---@return boolean
local function is_forced(lhs)
  local forced = vim.b.VM_force_maps
  if type(forced) ~= 'table' then
    forced = config.values.force_maps or {}
  end
  for _, key in ipairs(forced) do
    if key == lhs then
      return true
    end
  end
  return false
end

---@param mode string
---@param lhs string
---@return boolean
local function can_assign(mode, lhs)
  if claimed[mode] and claimed[mode][lhs] then
    map_conflicts[lhs] = true
    return false
  end
  local check = vim.b.VM_check_mappings
  if check == nil then
    check = config.values.check_mappings
  else
    check = check ~= 0
  end
  if not check or is_forced(lhs) then
    return true
  end
  local map = vim.fn.maparg(lhs, mode, false, true)
  if type(map) == 'table' and map.buffer == 1 then
    map_conflicts[lhs] = true
    return false
  end
  return true
end

---@param lhs string|string[]|nil
---@param fn fun()
---@param fallback string
local function map_action(lhs, fn, fallback)
  for _, key in ipairs(lhs_list(lhs)) do
    if can_assign('n', key) then
      local desc_fallback = (type(fallback) == 'string' and fallback ~= '') and fallback or key
      vim.keymap.set('n', key, function()
        local fb = (type(fallback) == 'string' and fallback ~= '') and fallback or key
        if vim.g.multi_cursor_bypass_maps == 1 then
          normal_bang(fb)
          return
        end
        if active() and mappings_enabled() then
          fn()
        else
          feed(fb)
        end
      end, { silent = true, desc = map_desc(key, desc_fallback) })
      claimed.n[key] = true
    end
  end
end

---@param lhs string|string[]|nil
---@param fn fun()
---@param fallback string
local function map_action_active(lhs, fn, fallback)
  for _, key in ipairs(lhs_list(lhs)) do
    if can_assign('n', key) then
      local desc_fallback = (type(fallback) == 'string' and fallback ~= '') and fallback or key
      vim.keymap.set('n', key, function()
        local fb = (type(fallback) == 'string' and fallback ~= '') and fallback or key
        if vim.g.multi_cursor_bypass_maps == 1 then
          normal_bang(fb)
          return
        end
        if active() then
          fn()
        else
          feed(fb)
        end
      end, { silent = true, desc = map_desc(key, desc_fallback) })
      claimed.n[key] = true
    end
  end
end

---@param lhs string|string[]|nil
---@param fn fun()
---@param fallback string
local function map_action_any(lhs, fn, fallback)
  for _, key in ipairs(lhs_list(lhs)) do
    if can_assign('n', key) then
      local desc_fallback = (type(fallback) == 'string' and fallback ~= '') and fallback or key
      vim.keymap.set('n', key, function()
        local fb = (type(fallback) == 'string' and fallback ~= '') and fallback or key
        if vim.g.multi_cursor_bypass_maps == 1 then
          normal_bang(fb)
          return
        end
        fn()
      end, { silent = true, desc = map_desc(key, desc_fallback) })
      claimed.n[key] = true
    end
  end
end

---@param lhs string|string[]|nil
---@param when_active fun()
---@param when_inactive fun():boolean|nil
---@param fallback string
local function map_action_decide(lhs, when_active, when_inactive, fallback)
  for _, key in ipairs(lhs_list(lhs)) do
    if can_assign('n', key) then
      local desc_fallback = (type(fallback) == 'string' and fallback ~= '') and fallback or key
      vim.keymap.set('n', key, function()
        local fb = (type(fallback) == 'string' and fallback ~= '') and fallback or key
        if vim.g.multi_cursor_bypass_maps == 1 then
          normal_bang(fb)
          return
        end
        if active() and mappings_enabled() then
          when_active()
          return
        end
        if when_inactive and when_inactive() then
          return
        end
        feed(fb)
      end, { silent = true, desc = map_desc(key, desc_fallback) })
      claimed.n[key] = true
    end
  end
end

---@param lhs string|string[]|nil
---@param fallback string
local function map_motion(lhs, fallback)
  for _, key in ipairs(lhs_list(lhs)) do
    if can_assign('n', key) then
      local desc_fallback = (type(fallback) == 'string' and fallback ~= '') and fallback or key
      vim.keymap.set('n', key, function()
        local fb = (type(fallback) == 'string' and fallback ~= '') and fallback or key
        if active() and mappings_enabled() then
          actions.apply_mapped_motion(key, fb)
        elseif vim.g.multi_cursor_bypass_maps == 1 then
          normal_bang(fb)
        else
          feed(fb)
        end
      end, { silent = true, desc = map_desc(key, desc_fallback) })
      claimed.n[key] = true
    end
  end
end

---@param lhs string|string[]|nil
---@param keys string
---@param remap boolean
local function map_apply_normal(lhs, keys, remap)
  map_action(lhs, function()
    actions.apply_normal(keys, remap)
  end, type(lhs) == 'string' and fallback_for(lhs) or keys)
end

---@param lhs string|string[]|nil
---@param kind string
---@param fallback string|nil
local function map_insert_special(lhs, kind, fallback)
  for _, key in ipairs(lhs_list(lhs)) do
    if can_assign('i', key) then
      vim.keymap.set('i', key, function()
        return actions.handle_insert_special(kind, fallback or key)
      end, { expr = true, silent = true, desc = map_desc(key, fallback) })
      claimed.i[key] = true
    end
  end
end

---@param lhs string|string[]|nil
---@param delta integer
---@param fallback string|nil
local function map_insert_single_cycle(lhs, delta, fallback)
  for _, key in ipairs(lhs_list(lhs)) do
    if can_assign('i', key) then
      vim.keymap.set('i', key, function()
        return actions.handle_single_mode_cycle(delta, fallback or key)
      end, { expr = true, silent = true, desc = map_desc(key, fallback) })
      claimed.i[key] = true
    end
  end
end

---@param mode 'n'|'x'|'i'
---@param lhs string|string[]|nil
---@param rhs string|function
local function map_plain(mode, lhs, rhs)
  for _, key in ipairs(lhs_list(lhs)) do
    if can_assign(mode, key) then
      vim.keymap.set(mode, key, rhs, { silent = true, desc = map_desc(key, key) })
      claimed[mode][key] = true
    end
  end
end

---@return nil
function M.setup()
  if mapped then
    return
  end
  mapped = true
  map_conflicts = {}
  claimed = { n = {}, x = {}, i = {} }
  refresh_map_descriptions()

  local m = config.values.mappings

  -- Cursor placement mappings should claim first so explicit user overrides
  -- can win over leader-derived defaults like align/change-to-eol.
  map_plain('n', m.add_cursor_at_pos, actions.add_cursor_at_pos)
  if type(m.add_cursor_at_word) == 'string' and m.add_cursor_at_word ~= '' then
    map_plain('n', m.add_cursor_at_word, function()
      actions.add_cursor_at_word(true)
    end)
  end
  map_plain('n', m.add_cursor_down, function()
    actions.add_cursor_vertical(1, vim.v.count1)
  end)
  map_plain('n', m.add_cursor_up, function()
    actions.add_cursor_vertical(-1, vim.v.count1)
  end)
  map_plain('n', m.select_all, actions.select_all)

  map_action_any(m.find_under, function()
    actions.find_under()
  end, fallback_for(m.find_under))
  map_action_any(m.find_subword_under, function()
    actions.find_subword_under()
  end, fallback_for(m.find_subword_under))
  map_action_any(m.seed_word_search, function()
    actions.seed_word_search()
  end, fallback_for(m.seed_word_search))
  map_action_any(m.regex_search, function()
    actions.find_by_regex(nil, { select_all = false })
  end, fallback_for(m.regex_search))
  map_action_any(m.regex_search_all, function()
    actions.find_by_regex(nil, { select_all = true })
  end, fallback_for(m.regex_search_all))
  map_action(m.slash_search, function()
    actions.find_by_regex(nil, { select_all = false })
  end, fallback_for(m.slash_search))
  map_action(m.align, function()
    actions.align()
  end, fallback_for(m.align))
  map_action(m.align_char, function()
    actions.align_char(vim.v.count1, nil)
  end, fallback_for(m.align_char))
  map_action(m.align_regex, function()
    actions.align_regex(nil)
  end, fallback_for(m.align_regex))
  map_action(m.transpose, function()
    actions.transpose()
  end, fallback_for(m.transpose))
  if type(m.rotate) == 'string' and m.rotate ~= '' then
    map_action(m.rotate, function()
      actions.rotate()
    end, fallback_for(m.rotate))
  end
  map_action(m.duplicate, function()
    actions.duplicate()
  end, fallback_for(m.duplicate))
  map_action(m.filter_regions, function()
    actions.filter_regions(nil, false)
  end, fallback_for(m.filter_regions))
  map_action(m.transform_regions, function()
    actions.transform_regions(nil)
  end, fallback_for(m.transform_regions))
  map_action(m.surround, function()
    actions.surround(nil)
  end, fallback_for(m.surround))
  map_action(m.numbers_append, function()
    actions.number_regions_prompt(vim.v.count1, true, nil)
  end, fallback_for(m.numbers_append))
  map_action(m.numbers_prepend, function()
    actions.number_regions_prompt(vim.v.count1, false, nil)
  end, fallback_for(m.numbers_prepend))
  map_action(m.numbers_zero_append, function()
    actions.number_regions_zero(vim.v.count, true)
  end, fallback_for(m.numbers_zero_append))
  map_action(m.numbers_zero_prepend, function()
    actions.number_regions_zero(vim.v.count, false)
  end, fallback_for(m.numbers_zero_prepend))
  map_action(m.shrink, function()
    actions.shrink_or_enlarge(true)
  end, fallback_for(m.shrink))
  map_action(m.enlarge, function()
    actions.shrink_or_enlarge(false)
  end, fallback_for(m.enlarge))
  map_action(m.case_conversion, function()
    actions.case_conversion_menu(nil)
  end, fallback_for(m.case_conversion))
  map_action(m.case_setting, function()
    actions.case_setting_cycle()
  end, fallback_for(m.case_setting))
  map_action_any(m.search_menu, function()
    actions.search_menu()
  end, fallback_for(m.search_menu))
  map_action_any(m.tools_menu, function()
    actions.tools_menu()
  end, fallback_for(m.tools_menu))
  map_action(m.show_registers, function()
    actions.show_registers()
  end, fallback_for(m.show_registers))
  map_action(m.rewrite_last_search, function()
    actions.rewrite_last_search()
  end, fallback_for(m.rewrite_last_search))
  map_action(m.run_ex, function()
    actions.run_ex(nil)
  end, fallback_for(m.run_ex))
  map_action(m.run_macro, function()
    actions.run_macro(nil)
  end, fallback_for(m.run_macro))
  map_action(m.run_normal, function()
    actions.run_normal(nil)
  end, fallback_for(m.run_normal))
  map_action(m.run_last_normal, function()
    actions.run_last_normal()
  end, fallback_for(m.run_last_normal))
  map_action(m.run_visual, function()
    actions.run_visual(nil)
  end, fallback_for(m.run_visual))
  map_action(m.run_last_visual, function()
    actions.run_last_visual()
  end, fallback_for(m.run_last_visual))
  map_action(m.run_last_ex, function()
    actions.run_last_ex()
  end, fallback_for(m.run_last_ex))
  map_action(m.run_dot, function()
    actions.run_dot()
  end, fallback_for(m.run_dot))
  map_action(m.replace_pattern, function()
    actions.replace_pattern_in_regions(nil, nil)
  end, fallback_for(m.replace_pattern))
  map_action(m.subtract_pattern, function()
    actions.subtract_pattern(nil)
  end, fallback_for(m.subtract_pattern))
  if type(m.split_regions) == 'string' and m.split_regions ~= '' then
    map_action(m.split_regions, function()
      actions.split_lines()
    end, fallback_for(m.split_regions))
  end
  if type(m.remove_empty_lines) == 'string' and m.remove_empty_lines ~= '' then
    map_action(m.remove_empty_lines, function()
      actions.remove_empty_lines()
    end, fallback_for(m.remove_empty_lines))
  end
  map_action(m.reselect_last, function()
    actions.reselect_last()
  end, fallback_for(m.reselect_last))
  map_action(m.toggle_single_region, function()
    actions.toggle_single_region()
  end, fallback_for(m.toggle_single_region))
  map_action(m.remove_every_n_regions, function()
    actions.remove_every_n_regions(vim.v.count)
  end, fallback_for(m.remove_every_n_regions))
  map_action(m.undo, function()
    actions.undo()
  end, fallback_for(m.undo))
  map_action(m.redo, function()
    actions.redo()
  end, fallback_for(m.redo))
  map_action(m.goto_next, function()
    actions.goto_region(1)
  end, fallback_for(m.goto_next))
  map_action(m.goto_prev, function()
    actions.goto_region(-1)
  end, fallback_for(m.goto_prev))
  map_action(m.seek_up, function()
    actions.seek_region(-1)
  end, fallback_for(m.seek_up))
  map_action(m.seek_down, function()
    actions.seek_region(1)
  end, fallback_for(m.seek_down))
  map_action(m.invert_direction, function()
    actions.invert_direction()
  end, fallback_for(m.invert_direction))
  map_action(m.invert_direction_alt, function()
    actions.invert_direction()
  end, fallback_for(m.invert_direction_alt))
  map_action(m.toggle_multiline, function()
    actions.toggle_multiline()
  end, fallback_for(m.toggle_multiline))
  map_action_active(m.toggle_mappings, function()
    actions.toggle_mappings()
  end, fallback_for(m.toggle_mappings))
  map_action(m.toggle_whole_word, function()
    actions.toggle_whole_word()
  end, fallback_for(m.toggle_whole_word))
  map_action(m.find_next, function()
    actions.find_next(false)
  end, fallback_for(m.find_next))
  map_action(m.find_prev, function()
    actions.find_next(true)
  end, fallback_for(m.find_prev))
  map_action(m.skip, function()
    actions.skip_current(nil)
  end, fallback_for(m.skip))
  map_action(m.remove, function()
    actions.remove_current()
  end, fallback_for(m.remove))
  map_action(m.remove_last_region, function()
    actions.remove_last_region()
  end, fallback_for(m.remove_last_region))
  map_action_active(m.toggle_mode, function()
    actions.toggle_mode()
  end, fallback_for(m.toggle_mode))
  if type(m.toggle_mode) ~= 'string' or m.toggle_mode == '' then
    map_action_active('<Tab>', function()
      actions.toggle_mode()
    end, '<Tab>')
  end
  map_action(m.shift_right, function()
    actions.shift_selection(1)
  end, fallback_for(m.shift_right))
  map_action(m.shift_left, function()
    actions.shift_selection(-1)
  end, fallback_for(m.shift_left))
  local function map_select_motion(lhs, motion)
    if type(lhs) ~= 'string' or lhs == '' then
      return
    end
    map_action(lhs, function()
      actions.select_operator_with_motion(motion)
    end, fallback_for(lhs))
  end
  map_select_motion(m.select_j, 'j')
  map_select_motion(m.select_k, 'k')
  map_select_motion(m.select_w, 'w')
  map_select_motion(m.select_b, 'b')
  map_select_motion(m.select_e, 'e')
  map_select_motion(m.select_ge, 'ge')
  map_select_motion(m.select_E, 'E')
  map_select_motion(m.select_BBW, 'B')
  if type(m.single_select_h) == 'string' and m.single_select_h ~= '' then
    map_action(m.single_select_h, function()
      actions.toggle_single_region()
      actions.shift_selection(-1)
    end, fallback_for(m.single_select_h))
  end
  if type(m.single_select_l) == 'string' and m.single_select_l ~= '' then
    map_action(m.single_select_l, function()
      actions.toggle_single_region()
      actions.shift_selection(1)
    end, fallback_for(m.single_select_l))
  end
  map_action_active(m.clear, function()
    actions.clear()
  end, fallback_for(m.clear))
  map_action_active('<Esc>', function()
    actions.clear()
  end, '<Esc>')
  map_action(m.goto_regex, function()
    actions.goto_regex(nil, false, vim.v.count1)
  end, fallback_for(m.goto_regex))
  map_action(m.goto_regex_remove, function()
    actions.goto_regex(nil, true, vim.v.count1)
  end, fallback_for(m.goto_regex_remove))
  map_action(m.show_infoline, function()
    local i = actions.info()
    print(string.format('MultiCursor [%s] %d/%d', i.mode, i.current, i.total))
  end, fallback_for(m.show_infoline))
  map_action(m.one_per_line, function()
    actions.one_region_per_line()
  end, fallback_for(m.one_per_line))
  map_action(m.merge_regions, function()
    actions.merge_regions()
  end, fallback_for(m.merge_regions))
  map_action(m.delete_operator, function()
    local st = state_mod.current()
    if st.mode == 'extend' then
      actions.set_last_dot({ kind = 'extend_delete' })
      actions.yank_exact_selection(true)
      actions.delete_regions()
    else
      actions.operator_prompt('d')
    end
  end, fallback_for(m.delete_operator))
  if type(m.delete_operator) ~= 'string' or m.delete_operator == '' then
    map_action('d', function()
      local st = state_mod.current()
      if st.mode == 'extend' then
        actions.set_last_dot({ kind = 'extend_delete' })
        actions.yank_exact_selection(true)
        actions.delete_regions()
      else
        actions.operator_prompt('d')
      end
    end, 'd')
  end
  map_action(m.change_operator, function()
    local st = state_mod.current()
    if st.mode == 'extend' then
      actions.change_regions(nil)
    else
      actions.operator_prompt('c')
    end
  end, fallback_for(m.change_operator))
  if type(m.change_operator) ~= 'string' or m.change_operator == '' then
    map_action('c', function()
      local st = state_mod.current()
      if st.mode == 'extend' then
        actions.change_regions(nil)
      else
        actions.operator_prompt('c')
      end
    end, 'c')
  end
  map_action(m.yank_operator, function()
    local st = state_mod.current()
    if st.mode == 'extend' then
      actions.yank()
    else
      actions.operator_prompt('y')
    end
  end, fallback_for(m.yank_operator))
  if type(m.yank_operator) ~= 'string' or m.yank_operator == '' then
    map_action('y', function()
      local st = state_mod.current()
      if st.mode == 'extend' then
        actions.yank()
      else
        actions.operator_prompt('y')
      end
    end, 'y')
  end
  map_action(m.select_operator, function()
    actions.select_operator_prompt()
  end, fallback_for(m.select_operator))
  map_action(m.find_operator, function()
    actions.find_operator_prompt()
  end, fallback_for(m.find_operator))
  for _, op in ipairs(config.values.user_operators or {}) do
    if type(op) == 'string' and op ~= '' then
      map_action(op, function()
        actions.operator_prompt(op)
      end, fallback_for(op))
    end
  end
  map_apply_normal(m.line_delete, 'D', false)
  map_apply_normal(m.line_yank, 'Y', false)
  map_apply_normal(m.delete_char, 'x', false)
  map_apply_normal(m.delete_char_before, 'X', false)
  map_apply_normal(m.join_lines, 'J', false)
  map_apply_normal(m.repeat_substitute, '&', false)
  map_apply_normal(m.delete_key, '<Del>', false)
  map_apply_normal(m.dot, '.', false)
  map_action(m.increase, function()
    actions.increase_or_decrease(true, false, vim.v.count1, false)
  end, fallback_for(m.increase))
  map_action(m.decrease, function()
    actions.increase_or_decrease(false, false, vim.v.count1, false)
  end, fallback_for(m.decrease))
  map_action(m.gincrease, function()
    actions.increase_or_decrease(true, false, vim.v.count1, true)
  end, fallback_for(m.gincrease))
  map_action(m.gdecrease, function()
    actions.increase_or_decrease(false, false, vim.v.count1, true)
  end, fallback_for(m.gdecrease))
  map_action(m.alpha_increase, function()
    actions.increase_or_decrease(true, true, vim.v.count1, false)
  end, fallback_for(m.alpha_increase))
  map_action(m.alpha_decrease, function()
    actions.increase_or_decrease(false, true, vim.v.count1, false)
  end, fallback_for(m.alpha_decrease))
  map_apply_normal(m.comment_operator, 'gc', true)
  map_action(m.lower_operator, function()
    local st = state_mod.current()
    if st.mode == 'extend' then
      actions.run_visual('gu')
    else
      actions.apply_normal('gu', false)
    end
  end, fallback_for(m.lower_operator))
  map_action(m.upper_operator, function()
    local st = state_mod.current()
    if st.mode == 'extend' then
      actions.run_visual('gU')
    else
      actions.apply_normal('gU', false)
    end
  end, fallback_for(m.upper_operator))
  map_apply_normal(m.change_to_eol, 'C', false)
  map_action(m.replace_chars, function()
    actions.replace_chars(nil)
  end, fallback_for(m.replace_chars))
  map_apply_normal(m.replace_mode, 'R', false)
  map_apply_normal(m.open_below, 'o', false)
  map_apply_normal(m.open_above, 'O', false)
  map_action(m.swap_case, function()
    local st = state_mod.current()
    if st.mode == 'extend' then
      actions.run_visual('~')
    else
      actions.apply_normal('~', false)
    end
  end, fallback_for(m.swap_case))

  if config.values.use_visual_mode then
    map_plain('x', m.visual_regex, function()
      actions.find_visual_by_regex(nil, { select_all = true })
    end)
    map_plain('x', m.visual_all, function()
      actions.find_all_under_visual()
    end)
    map_plain('x', m.visual_find, function()
      actions.find_under_visual()
    end)
    map_plain('x', m.visual_add, function()
      actions.visual_add()
    end)
    map_plain('x', m.visual_subtract, function()
      actions.visual_subtract()
    end)
    map_plain('x', m.visual_reduce, function()
      actions.visual_reduce()
    end)
    map_plain('x', m.find_subword_under, function()
      actions.find_under_visual()
    end)
    map_plain('x', m.visual_cursors, function()
      actions.visual_cursors()
    end)
  end

  map_action_any(m.mouse_cursor, function()
    actions.mouse_cursor()
  end, fallback_for(m.mouse_cursor))
  map_action_any(m.mouse_word, function()
    actions.mouse_word()
  end, fallback_for(m.mouse_word))
  map_action_any(m.mouse_column, function()
    actions.mouse_column()
  end, fallback_for(m.mouse_column))

  if config.values.insert_mode == 'native' then
    map_action(m.insert_insert, function()
      actions.begin_insert('insert')
    end, fallback_for(m.insert_insert))
    map_action(m.insert_append, function()
      actions.begin_insert('append')
    end, fallback_for(m.insert_append))
    map_action(m.insert_insert_sol, function()
      actions.begin_insert('insert_sol')
    end, fallback_for(m.insert_insert_sol))
    map_action(m.insert_append_eol, function()
      actions.begin_insert('append_eol')
    end, fallback_for(m.insert_append_eol))
    if m.insert_insert == '' then
      map_action('i', function()
        actions.begin_insert('insert')
      end, 'i')
    end
    if m.insert_append == '' then
      map_action('a', function()
        actions.begin_insert('append')
      end, 'a')
    end
    if m.insert_insert_sol == '' then
      map_action('I', function()
        actions.begin_insert('insert_sol')
      end, 'I')
    end
    if m.insert_append_eol == '' then
      map_action('A', function()
        actions.begin_insert('append_eol')
      end, 'A')
    end
  else
    map_action(m.insert_insert, function()
      actions.insert_prompt('insert')
    end, fallback_for(m.insert_insert))
    map_action(m.insert_append, function()
      actions.insert_prompt('append')
    end, fallback_for(m.insert_append))
    map_action(m.insert_insert_sol, function()
      actions.insert_prompt('insert_sol')
    end, fallback_for(m.insert_insert_sol))
    map_action(m.insert_append_eol, function()
      actions.insert_prompt('append_eol')
    end, fallback_for(m.insert_append_eol))
    if m.insert_insert == '' then
      map_action('i', function()
        actions.insert_prompt('insert')
      end, 'i')
    end
    if m.insert_append == '' then
      map_action('a', function()
        actions.insert_prompt('append')
      end, 'a')
    end
    if m.insert_insert_sol == '' then
      map_action('I', function()
        actions.insert_prompt('insert_sol')
      end, 'I')
    end
    if m.insert_append_eol == '' then
      map_action('A', function()
        actions.insert_prompt('append_eol')
      end, 'A')
    end
  end

  if config.values.insert_mode == 'native' then
    local function map_insert_special_default(lhs, kind, fallback)
      if type(lhs) == 'string' and lhs ~= '' then
        return
      end
      map_insert_special(fallback, kind, fallback)
    end
    map_insert_special('<Esc>', 'esc', '<Esc>')
    map_insert_special(m.i_left_arrow, 'left', '<Left>')
    map_insert_special(m.i_right_arrow, 'right', '<Right>')
    map_insert_special(m.i_up_arrow, 'up', '<Up>')
    map_insert_special(m.i_down_arrow, 'down', '<Down>')
    map_insert_special(m.i_arrow_w, 'word_right', '<C-Right>')
    map_insert_special(m.i_arrow_b, 'word_left', '<C-Left>')
    map_insert_special(m.i_arrow_W, 'word_right', '<C-S-Right>')
    map_insert_special(m.i_arrow_B, 'word_left', '<C-S-Left>')
    map_insert_special(m.i_arrow_ge, 'up', '<C-Up>')
    map_insert_special(m.i_arrow_e, 'down', '<C-Down>')
    map_insert_special(m.i_arrow_gE, 'up', '<C-S-Up>')
    map_insert_special(m.i_arrow_E, 'down', '<C-S-Down>')
    map_insert_special(m.i_home, 'home', '<Home>')
    map_insert_special(m.i_end, 'end', '<End>')
    map_insert_special(m.i_bs, 'bs', '<BS>')
    map_insert_special(m.i_del, 'del', '<Del>')
    map_insert_special(m.i_return, 'cr', '<CR>')
    map_insert_special(m.i_ctrl_b, 'left', '<C-b>')
    map_insert_special(m.i_ctrl_f, 'right', '<C-f>')
    map_insert_special(m.i_ctrl_d, 'ctrl_d', '<C-d>')
    map_insert_special(m.i_ctrl_a, 'ctrl_a_passthrough', '<C-a>')
    map_insert_special(m.i_ctrl_e, 'ctrl_e_passthrough', '<C-e>')
    map_insert_special(m.i_paste, 'paste_passthrough', '<C-v>')
    map_insert_special(m.i_ctrl_c, 'ctrl_c', '<C-c>')
    map_insert_special(m.i_ctrl_o, 'ctrl_o', '<C-o>')
    map_insert_special(m.i_ctrl_caret, 'ctrl_caret', '<C-^>')
    map_insert_special(m.i_replace, 'replace_toggle', '<Insert>')
    map_insert_special(m.i_ctrl_w, 'ctrl_w', '<C-w>')
    map_insert_special(m.i_ctrl_u, 'ctrl_u', '<C-u>')
    map_insert_special_default(m.i_left_arrow, 'left', '<Left>')
    map_insert_special_default(m.i_right_arrow, 'right', '<Right>')
    map_insert_special_default(m.i_up_arrow, 'up', '<Up>')
    map_insert_special_default(m.i_down_arrow, 'down', '<Down>')
    map_insert_special_default(m.i_home, 'home', '<Home>')
    map_insert_special_default(m.i_end, 'end', '<End>')
    map_insert_special_default(m.i_bs, 'bs', '<BS>')
    map_insert_special_default(m.i_del, 'del', '<Del>')
    map_insert_special_default(m.i_return, 'cr', '<CR>')
    map_insert_special_default(m.i_ctrl_w, 'ctrl_w', '<C-w>')
    map_insert_special_default(m.i_ctrl_u, 'ctrl_u', '<C-u>')
    if config.values.single_mode_maps then
      map_insert_single_cycle(m.i_next, 1, '<Tab>')
      map_insert_single_cycle(m.i_prev, -1, '<S-Tab>')
    end
  end

  map_action_decide(m.paste_after, function()
    for _ = 1, vim.v.count1 do
      actions.paste_multicursor(true)
    end
  end, function()
    if not config.values.smart_paste_from_multicursor then
      return false
    end
    local ok = false
    for _ = 1, vim.v.count1 do
      ok = actions.paste_single_cursor(true) or ok
    end
    return ok
  end, fallback_for(m.paste_after))
  if type(m.paste_after) ~= 'string' or m.paste_after == '' then
    map_action_decide('p', function()
      for _ = 1, vim.v.count1 do
        actions.paste_multicursor(true)
      end
    end, function()
      if not config.values.smart_paste_from_multicursor then
        return false
      end
      local ok = false
      for _ = 1, vim.v.count1 do
        ok = actions.paste_single_cursor(true) or ok
      end
      return ok
    end, 'p')
  end

  map_action_decide(m.paste_before, function()
    for _ = 1, vim.v.count1 do
      actions.paste_multicursor(false)
    end
  end, function()
    if not config.values.smart_paste_from_multicursor then
      return false
    end
    local ok = false
    for _ = 1, vim.v.count1 do
      ok = actions.paste_single_cursor(false) or ok
    end
    return ok
  end, fallback_for(m.paste_before))
  if type(m.paste_before) ~= 'string' or m.paste_before == '' then
    map_action_decide('P', function()
      for _ = 1, vim.v.count1 do
        actions.paste_multicursor(false)
      end
    end, function()
      if not config.values.smart_paste_from_multicursor then
        return false
      end
      local ok = false
      for _ = 1, vim.v.count1 do
        ok = actions.paste_single_cursor(false) or ok
      end
      return ok
    end, 'P')
  end

  for lhs, rhs in pairs(config.values.custom_noremaps or {}) do
    if type(lhs) == 'string' and lhs ~= '' and type(rhs) == 'string' and rhs ~= '' then
      map_action(lhs, function()
        actions.apply_normal(rhs, false)
      end, fallback_for(lhs))
    end
  end

  for lhs, rhs in pairs(config.values.custom_remaps or {}) do
    if type(lhs) == 'string' and lhs ~= '' and type(rhs) == 'string' and rhs ~= '' then
      map_action(lhs, function()
        actions.apply_normal(rhs, true)
      end, fallback_for(lhs))
    end
  end

  for lhs, rhs in pairs(config.values.custom_commands or {}) do
    if type(lhs) == 'string' and lhs ~= '' and type(rhs) == 'string' and rhs ~= '' then
      map_action(lhs, function()
        feed_remap(rhs)
      end, fallback_for(lhs))
    end
  end

  if config.values.enable_normal_key_passthrough then
    local occupied = {}
    for _, k in pairs(m) do
      for _, key in ipairs(lhs_list(k)) do
        occupied[key] = true
      end
    end
    for k in pairs(config.values.custom_noremaps or {}) do
      occupied[k] = true
    end
    for k in pairs(config.values.custom_remaps or {}) do
      occupied[k] = true
    end
    for k in pairs(config.values.custom_commands or {}) do
      occupied[k] = true
    end
    for _, lhs in ipairs(config.values.normal_keys or {}) do
      if not occupied[lhs] then
        map_motion(lhs, fallback_for(lhs))
      end
    end
    for lhs in pairs(config.values.custom_motions or {}) do
      if type(lhs) == 'string' and lhs ~= '' and not occupied[lhs] then
        map_motion(lhs, fallback_for(lhs))
      end
    end
  end

  if config.values.show_warnings and next(map_conflicts) ~= nil then
    local count = 0
    for _ in pairs(map_conflicts) do
      count = count + 1
    end
    vim.notify(
      string.format('MultiCursor: %d mapping conflicts detected', count),
      vim.log.levels.WARN
    )
  end
end

---@return string[]
function M.conflicts()
  local out = {}
  for lhs in pairs(map_conflicts) do
    table.insert(out, lhs)
  end
  table.sort(out)
  return out
end

return M
