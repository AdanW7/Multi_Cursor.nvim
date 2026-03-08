local config = require('multi_cursor.config')
local actions = require('multi_cursor.actions')
local keymaps = require('multi_cursor.keymaps')
local render = require('multi_cursor.render')
local state_mod = require('multi_cursor.state')

---@class MultiCursorModule
---@field setup fun(opts: MultiCursorOpts|nil)
---@field actions table
local M = {}
local started = false

---@type table<string, {mono:vim.api.keyset.highlight,cursor:vim.api.keyset.highlight,extend:vim.api.keyset.highlight,insert:vim.api.keyset.highlight|nil}>
local THEMES = {
  default = {
    mono = { link = 'ErrorMsg' },
    cursor = { link = 'Visual' },
    extend = { link = 'PmenuSel' },
  },
  iceblue = {
    extend = { bg = '#005f87' },
    cursor = { bg = '#0087af', fg = '#87dfff' },
    mono = { bg = '#dfaf87', fg = '#262626' },
  },
  ocean = {
    extend = { bg = '#005faf' },
    cursor = { bg = '#87afff', fg = '#4e4e4e' },
    mono = { bg = '#dfdf87', fg = '#4e4e4e' },
  },
  neon = {
    extend = { bg = '#005fdf', fg = '#89afaf' },
    cursor = { bg = '#00afff', fg = '#4e4e4e' },
    mono = { bg = '#ffdf5f', fg = '#4e4e4e' },
  },
  lightblue1 = {
    extend = { bg = '#afdfff' },
    cursor = { bg = '#87afff', fg = '#4e4e4e' },
    mono = { bg = '#df5f5f', fg = '#dadada', bold = true },
  },
  lightblue2 = {
    extend = { bg = '#87dfff' },
    cursor = { bg = '#87afff', fg = '#4e4e4e' },
    mono = { bg = '#df5f5f', fg = '#dadada', bold = true },
  },
  purplegray = {
    extend = { bg = '#544a65' },
    cursor = { bg = '#8787af', fg = '#5f0087' },
    mono = { bg = '#af87ff', fg = '#262626' },
  },
  nord = {
    extend = { bg = '#434C5E' },
    cursor = { bg = '#8a8a8a', fg = '#005f87' },
    mono = { bg = '#AF5F5F', fg = '#262626' },
  },
  codedark = {
    extend = { bg = '#264F78' },
    cursor = { bg = '#6A7D89', fg = '#C5D4DD' },
    mono = { bg = '#AF5F5F', fg = '#262626' },
  },
  spacegray = {
    extend = { bg = '#404040' },
    cursor = { bg = '#808080', fg = '#4e4e4e' },
    mono = { bg = '#AF5F5F', fg = '#262626' },
  },
  sand = {
    extend = { bg = '#bfbf87', fg = '#000000' },
    cursor = { bg = '#5f8700', fg = '#dfdf87' },
    mono = { bg = '#AF5F5F', fg = '#262626' },
  },
  paper = {
    extend = { bg = '#bfbcaf', fg = '#000000' },
    cursor = { bg = '#4c4e50', fg = '#d8d5c7' },
    mono = { bg = '#000000', fg = '#d8d5c7' },
  },
  olive = {
    extend = { bg = '#808000', fg = '#000000' },
    cursor = { bg = '#5f8700', fg = '#dfdf87' },
    mono = { bg = '#AF5F5F', fg = '#262626' },
  },
  lightpurple1 = {
    extend = { bg = '#ffdfff' },
    cursor = { bg = '#dfafff', fg = '#5f0087', bold = true },
    mono = { bg = '#af5fff', fg = '#ffdfff', bold = true },
  },
  lightpurple2 = {
    extend = { bg = '#dfdfff' },
    cursor = { bg = '#dfafff', fg = '#5f0087', bold = true },
    mono = { bg = '#af5fff', fg = '#ffdfff', bold = true },
  },
  -- Derived from your Helix palette (`~/Git/helix.nvim/lua/helix/colors.lua`).
  helix = {
    extend = { bg = '#e5c76b', fg = '#141b1e' },
    cursor = { bg = '#67b0e8', fg = '#141b1e' },
    mono = { bg = '#e5c76b', fg = '#141b1e' },
  },
}

---@return nil
local function apply_search_highlight()
  local hl = config.values.highlight_matches
  if type(hl) ~= 'string' or hl == '' then
    return
  end
  if hl == 'underline' then
    vim.api.nvim_set_hl(0, 'Search', { underline = true })
    return
  end
  if hl == 'red' then
    vim.api.nvim_set_hl(0, 'Search', { fg = '#ff0000' })
    return
  end
  if hl:match('^hi!?%s') then
    vim.cmd(hl)
  end
end

local function ensure_helptags(path)
  if vim.fn.isdirectory(path) ~= 1 then
    return
  end
  local tags = path .. '/tags'
  if vim.fn.filereadable(tags) == 1 then
    return
  end
  pcall(function()
    vim.cmd('silent! helptags ' .. vim.fn.fnameescape(path))
  end)
end

local function ensure_plugin_help()
  local this = debug.getinfo(1, 'S').source:sub(2)
  local plugin_root = vim.fn.fnamemodify(this, ':h:h:h')
  ensure_helptags(plugin_root .. '/doc')
  ensure_helptags(plugin_root .. '/legacy/vim-visual-multi/doc')
end

---@return nil
local function setup_highlights()
  vim.api.nvim_set_hl(0, 'MultiCursorMono', { link = 'IncSearch', default = true })
  vim.api.nvim_set_hl(0, 'MultiCursorCursor', { link = 'Visual', default = true })
  vim.api.nvim_set_hl(0, 'MultiCursorExtend', { link = 'PmenuSel', default = true })
  vim.api.nvim_set_hl(0, 'MultiCursorInsert', { link = 'Cursor', default = true })
  local theme = config.values.theme
  if type(theme) == 'string' and theme ~= '' and THEMES[theme] then
    local t = THEMES[theme]
    vim.api.nvim_set_hl(0, 'MultiCursorMono', t.mono or {})
    vim.api.nvim_set_hl(0, 'MultiCursorCursor', t.cursor or {})
    vim.api.nvim_set_hl(0, 'MultiCursorExtend', t.extend or {})
    vim.api.nvim_set_hl(0, 'MultiCursorInsert', t.insert or t.cursor or {})
  end
  apply_search_highlight()
end

---@return nil
local function create_commands()
  vim.api.nvim_create_user_command('MultiCursorAddCursorDown', function(opts)
    actions.add_cursor_vertical(1, opts.count > 0 and opts.count or 1)
  end, { count = true })

  vim.api.nvim_create_user_command('MultiCursorAddCursorUp', function(opts)
    actions.add_cursor_vertical(-1, opts.count > 0 and opts.count or 1)
  end, { count = true })

  vim.api.nvim_create_user_command('MultiCursorAddCursorAtPos', actions.add_cursor_at_pos, {})
  vim.api.nvim_create_user_command('MultiCursorAddCursorAtWord', function()
    actions.add_cursor_at_word(true)
  end, {})
  vim.api.nvim_create_user_command('MultiCursorFindUnder', actions.find_under, {})
  vim.api.nvim_create_user_command('MultiCursorRegex', function(opts)
    actions.find_by_regex(opts.args, { select_all = false })
  end, { nargs = '?' })
  vim.api.nvim_create_user_command('MultiCursorRegexAll', function(opts)
    actions.find_by_regex(opts.args, { select_all = true })
  end, { nargs = '?' })
  vim.api.nvim_create_user_command('MultiCursorVisualRegex', function(opts)
    actions.find_visual_by_regex(opts.args, { select_all = true })
  end, { nargs = '?' })
  vim.api.nvim_create_user_command('MultiCursorVisualAll', actions.find_all_under_visual, {})
  vim.api.nvim_create_user_command('MultiCursorVisualFind', actions.find_under_visual, {})
  vim.api.nvim_create_user_command('MultiCursorVisualCursors', actions.visual_cursors, {})
  vim.api.nvim_create_user_command('MultiCursorVisualAdd', actions.visual_add, {})
  vim.api.nvim_create_user_command('MultiCursorVisualSubtract', actions.visual_subtract, {})
  vim.api.nvim_create_user_command('MultiCursorVisualReduce', actions.visual_reduce, {})
  vim.api.nvim_create_user_command('MultiCursorFindNext', function()
    actions.find_next(false)
  end, {})
  vim.api.nvim_create_user_command('MultiCursorFindPrev', function()
    actions.find_next(true)
  end, {})
  vim.api.nvim_create_user_command('MultiCursorGotoNext', function()
    actions.goto_region(1)
  end, {})
  vim.api.nvim_create_user_command('MultiCursorGotoPrev', function()
    actions.goto_region(-1)
  end, {})
  vim.api.nvim_create_user_command('MultiCursorSeekUp', function()
    actions.seek_region(-1)
  end, {})
  vim.api.nvim_create_user_command('MultiCursorSeekDown', function()
    actions.seek_region(1)
  end, {})
  vim.api.nvim_create_user_command('MultiCursorInvertDirection', actions.invert_direction, {})
  vim.api.nvim_create_user_command('MultiCursorToggleMultiline', actions.toggle_multiline, {})
  vim.api.nvim_create_user_command('MultiCursorToggleMappings', actions.toggle_mappings, {})
  vim.api.nvim_create_user_command('MultiCursorToggleWholeWord', actions.toggle_whole_word, {})
  vim.api.nvim_create_user_command('MultiCursorMoveBOL', function()
    actions.merge_to_beol('bol')
  end, {})
  vim.api.nvim_create_user_command('MultiCursorMoveFirstNonblank', function()
    actions.merge_to_beol('first_nonblank')
  end, {})
  vim.api.nvim_create_user_command('MultiCursorMoveEOL', function()
    actions.merge_to_beol('eol')
  end, {})
  vim.api.nvim_create_user_command('MultiCursorDelete', actions.delete_regions, {})
  vim.api.nvim_create_user_command('MultiCursorChange', function(opts)
    actions.change_regions(opts.args ~= '' and opts.args or nil)
  end, { nargs = '?' })
  vim.api.nvim_create_user_command('MultiCursorOperator', function(opts)
    local parts = vim.split(opts.args or '', ' ', { plain = true, trimempty = true })
    actions.operator_with_motion(parts[1], parts[2])
  end, { nargs = '*' })
  vim.api.nvim_create_user_command('MultiCursorSelectOperator', function(opts)
    if opts.args and opts.args ~= '' then
      actions.select_operator_with_motion(opts.args)
    else
      actions.select_operator_prompt()
    end
  end, { nargs = '?' })
  vim.api.nvim_create_user_command('MultiCursorFindOperator', function(opts)
    if opts.args and opts.args ~= '' then
      actions.find_operator_with_motion(opts.args)
    else
      actions.find_operator_prompt()
    end
  end, { nargs = '?' })
  vim.api.nvim_create_user_command('MultiCursorReselectLast', actions.reselect_last, {})
  vim.api.nvim_create_user_command(
    'MultiCursorToggleSingleRegion',
    actions.toggle_single_region,
    {}
  )
  vim.api.nvim_create_user_command('MultiCursorSkip', function()
    actions.skip_current(false)
  end, {})
  vim.api.nvim_create_user_command('MultiCursorRemove', actions.remove_current, {})
  vim.api.nvim_create_user_command('MultiCursorRemoveLastRegion', actions.remove_last_region, {})
  vim.api.nvim_create_user_command('MultiCursorRemoveEmptyLines', actions.remove_empty_lines, {})
  vim.api.nvim_create_user_command('MultiCursorSelectAll', actions.select_all, {})
  vim.api.nvim_create_user_command('MultiCursorAlign', actions.align, {})
  vim.api.nvim_create_user_command('MultiCursorAlignChar', function(opts)
    actions.align_char(opts.count > 0 and opts.count or 1, opts.args ~= '' and opts.args or nil)
  end, { nargs = '?', count = true })
  vim.api.nvim_create_user_command('MultiCursorAlignRegex', function(opts)
    actions.align_regex(opts.args)
  end, { nargs = '?' })
  vim.api.nvim_create_user_command('MultiCursorGotoRegex', function(opts)
    actions.goto_regex(opts.args, false, vim.v.count1)
  end, { nargs = '?' })
  vim.api.nvim_create_user_command('MultiCursorGotoRegexRemove', function(opts)
    actions.goto_regex(opts.args, true, vim.v.count1)
  end, { nargs = '?' })
  vim.api.nvim_create_user_command('MultiCursorTranspose', actions.transpose, {})
  vim.api.nvim_create_user_command('MultiCursorRotate', actions.rotate, {})
  vim.api.nvim_create_user_command('MultiCursorSurround', function(opts)
    actions.surround(opts.args ~= '' and opts.args or nil)
  end, { nargs = '?' })
  vim.api.nvim_create_user_command('MultiCursorDuplicate', actions.duplicate, {})
  vim.api.nvim_create_user_command('MultiCursorFilter', function(opts)
    actions.filter_regions(opts.args, false)
  end, { nargs = '?' })
  vim.api.nvim_create_user_command('MultiCursorFilterInverse', function(opts)
    actions.filter_regions(opts.args, true)
  end, { nargs = '?' })
  vim.api.nvim_create_user_command('MultiCursorTransform', function(opts)
    actions.transform_regions(opts.args)
  end, { nargs = '?' })
  vim.api.nvim_create_user_command('MultiCursorReplacePattern', function(opts)
    local parts = vim.split(opts.args or '', ' ', { plain = true, trimempty = true })
    actions.replace_pattern_in_regions(parts[1], parts[2])
  end, { nargs = '*' })
  vim.api.nvim_create_user_command('MultiCursorSubtractPattern', function(opts)
    actions.subtract_pattern(opts.args)
  end, { nargs = '?' })
  vim.api.nvim_create_user_command('MultiCursorSplitRegions', actions.split_lines, {})
  vim.api.nvim_create_user_command('MultiCursorNumbersAppend', function(opts)
    actions.number_regions_prompt(opts.count > 0 and opts.count or 1, true, opts.args)
  end, { count = true, nargs = '?' })
  vim.api.nvim_create_user_command('MultiCursorNumbersPrepend', function(opts)
    actions.number_regions_prompt(opts.count > 0 and opts.count or 1, false, opts.args)
  end, { count = true, nargs = '?' })
  vim.api.nvim_create_user_command('MultiCursorZeroNumbersAppend', function(opts)
    actions.number_regions_zero(opts.count, true)
  end, { count = true })
  vim.api.nvim_create_user_command('MultiCursorZeroNumbersPrepend', function(opts)
    actions.number_regions_zero(opts.count, false)
  end, { count = true })
  vim.api.nvim_create_user_command('MultiCursorCase', function(opts)
    actions.case_convert(opts.args)
  end, {
    nargs = '?',
    complete = function()
      return { 'lower', 'upper', 'title' }
    end,
  })
  vim.api.nvim_create_user_command('MultiCursorCaseSetting', actions.case_setting_cycle, {})
  vim.api.nvim_create_user_command('MultiCursorSearchMenu', function(opts)
    actions.search_menu(opts.args ~= '' and opts.args or nil)
  end, {
    nargs = '?',
    complete = function()
      return actions.search_menu_items()
    end,
  })
  vim.api.nvim_create_user_command('MultiCursorToolsMenu', function(opts)
    actions.tools_menu(opts.args ~= '' and opts.args or nil)
  end, {
    nargs = '?',
    complete = function()
      return actions.tools_menu_items()
    end,
  })
  vim.api.nvim_create_user_command('MultiCursorShowRegisters', actions.show_registers, {})
  vim.api.nvim_create_user_command('MultiCursorRewriteLastSearch', actions.rewrite_last_search, {})
  vim.api.nvim_create_user_command('MultiCursorEx', function(opts)
    actions.run_ex(opts.args)
  end, { nargs = '?' })
  vim.api.nvim_create_user_command('MultiCursorMacro', function(opts)
    actions.run_macro(opts.args ~= '' and opts.args or nil)
  end, { nargs = '?' })
  vim.api.nvim_create_user_command('MultiCursorRunNormal', function(opts)
    actions.run_normal(opts.args)
  end, { nargs = '?' })
  vim.api.nvim_create_user_command('MultiCursorRunLastNormal', actions.run_last_normal, {})
  vim.api.nvim_create_user_command('MultiCursorRunVisual', function(opts)
    actions.run_visual(opts.args)
  end, { nargs = '?' })
  vim.api.nvim_create_user_command('MultiCursorRunLastVisual', actions.run_last_visual, {})
  vim.api.nvim_create_user_command('MultiCursorRunLastEx', actions.run_last_ex, {})
  vim.api.nvim_create_user_command('MultiCursorRunDot', actions.run_dot, {})
  vim.api.nvim_create_user_command('MultiCursorUndo', actions.undo, {})
  vim.api.nvim_create_user_command('MultiCursorRedo', actions.redo, {})
  vim.api.nvim_create_user_command('MultiCursorRemoveEveryN', function(opts)
    actions.remove_every_n_regions(opts.count > 0 and opts.count or 2)
  end, { count = true })
  vim.api.nvim_create_user_command('MultiCursorToggleMode', actions.toggle_mode, {})
  vim.api.nvim_create_user_command('MultiCursorClear', actions.clear, {})
  vim.api.nvim_create_user_command('MultiCursorYank', actions.yank, {})
  vim.api.nvim_create_user_command('MultiCursorPaste', function(opts)
    if opts.bang then
      actions.paste_multicursor(false)
    else
      actions.paste_multicursor(true)
    end
  end, { bang = true })

  vim.api.nvim_create_user_command('MultiCursorInsert', function(opts)
    actions.insert_prompt(opts.args == 'append' and 'append' or 'insert')
  end, {
    nargs = '?',
    complete = function()
      return { 'append' }
    end,
  })

  vim.api.nvim_create_user_command('MultiCursorNormal', function(opts)
    actions.apply_normal(opts.args)
  end, { nargs = '+' })

  vim.api.nvim_create_user_command('MultiCursorInfo', function()
    local i = actions.info()
    print(
      string.format(
        'Multi_Cursor: %s | mode=%s | %d/%d | pat=%s',
        i.enabled and 'on' or 'off',
        i.mode,
        i.current,
        i.total,
        i.pattern
      )
    )
  end, {})
  vim.api.nvim_create_user_command('MultiCursorShowInfoline', function()
    local i = actions.info()
    print(string.format('MultiCursor [%s] %d/%d', i.mode, i.current, i.total))
  end, {})
  vim.api.nvim_create_user_command('MultiCursorMappingConflicts', function()
    local conflicts = keymaps.conflicts()
    if #conflicts == 0 then
      print('MultiCursor: no recorded mapping conflicts')
      return
    end
    print('MultiCursor mapping conflicts:')
    for _, lhs in ipairs(conflicts) do
      print('  ' .. lhs)
    end
  end, {})
  vim.api.nvim_create_user_command('MultiCursorOnePerLine', actions.one_region_per_line, {})
  vim.api.nvim_create_user_command('MultiCursorMergeRegions', actions.merge_regions, {})
end

---@return nil
local function create_vm_alias_commands()
  local function create(name, rhs, opts)
    local ok, cmds = pcall(vim.api.nvim_get_commands, { builtin = false })
    if ok and type(cmds) == 'table' and cmds[name] ~= nil then
      return
    end
    vim.api.nvim_create_user_command(name, rhs, opts or {})
  end

  create('VMClear', actions.clear, {})
  create('VMDebug', function()
    local i = actions.info()
    print(
      string.format(
        'VM debug (lua): mode=%s enabled=%s total=%d current=%d pattern=%s',
        i.mode,
        i.enabled and '1' or '0',
        i.total,
        i.current,
        i.pattern
      )
    )
  end, {})
  create('VMLive', function()
    config.values.live_editing = not config.values.live_editing
    print(string.format('VM live editing: %s', config.values.live_editing and 'on' or 'off'))
  end, {})
  create('VMSearch', function(opts)
    local pat = opts.args ~= '' and opts.args or nil
    local line1, line2
    if opts.range and opts.range > 0 then
      line1, line2 = opts.line1, opts.line2
    end
    actions.vm_search(pat, opts.bang, line1, line2)
  end, { nargs = '?', bang = true, range = true })
  create('VMFromSearch', function(opts)
    local pat = opts.args ~= '' and opts.args or nil
    local line1, line2
    if opts.range and opts.range > 0 then
      line1, line2 = opts.line1, opts.line2
    elseif not opts.bang then
      line1 = 1
      line2 = vim.api.nvim_buf_line_count(0)
    end
    actions.vm_search(pat, opts.bang, line1, line2)
  end, { nargs = '?', bang = true, range = true })
  create('VMRegisters', function(opts)
    local state = require('multi_cursor.state')
    local reg = opts.args ~= '' and opts.args or nil
    if opts.bang then
      if reg then
        state.registers[reg] = nil
      else
        state.registers = {}
      end
      return
    end
    if reg and state.registers[reg] then
      local r = state.registers[reg]
      print(string.format('VM reg %s: %d item(s)', reg, #(r.items or {})))
      return
    end
    actions.show_registers()
  end, { nargs = '?', bang = true })
  create('VMTheme', function(opts)
    if opts.args ~= nil and opts.args ~= '' then
      config.values.theme = opts.args
    end
    setup_highlights()
    if config.values.theme ~= '' then
      print(string.format('VM theme: %s', config.values.theme))
    else
      print('VM theme: default')
    end
  end, { nargs = '?' })
  create('VMSort', function(opts)
    actions.vm_sort(opts.args ~= '' and opts.args or nil)
  end, { nargs = '?' })
  create('VMQfix', function(opts)
    actions.vm_qfix(opts.bang)
  end, { bang = true })
  create('VMFilterRegions', function(opts)
    local pat = opts.args ~= '' and opts.args or nil
    actions.vm_filter_regions(pat, opts.bang)
  end, { nargs = '?', bang = true })
  create('VMFilterLines', actions.vm_filter_lines, {})
  create('VMRegionsToBuffer', actions.vm_regions_to_buffer, {})
  create('VMMassTranspose', actions.vm_mass_transpose, {})
end

---@return nil
local function create_autocmds()
  local group = vim.api.nvim_create_augroup('MultiCursorNvim', { clear = true })
  vim.api.nvim_create_autocmd(
    { 'CursorMoved', 'CursorHold', 'TextChanged', 'TextChangedI', 'BufEnter' },
    {
      group = group,
      callback = function(args)
        local state = state_mod.get(args.buf)
        if state and state.enabled then
          if state.insert_active and state.insert_pending and config.values.live_editing then
            while actions.apply_pending_insert({ skip_render = true }) do
            end
          end
          render.sync(state, args.event)
        end
      end,
    }
  )

  vim.api.nvim_create_autocmd('InsertCharPre', {
    group = group,
    callback = function(args)
      local state = state_mod.get(args.buf)
      if state and state.enabled and state.insert_active then
        actions.insert_char_pre(vim.v.char)
      end
    end,
  })

  vim.api.nvim_create_autocmd('InsertLeave', {
    group = group,
    callback = function(args)
      local state = state_mod.get(args.buf)
      if state and state.enabled and state.insert_active then
        if state.insert_pending then
          while actions.apply_pending_insert({ skip_render = true }) do
          end
        end
        actions.end_insert()
      end
    end,
  })

  vim.api.nvim_create_autocmd('BufLeave', {
    group = group,
    callback = function(args)
      local state = state_mod.get(args.buf)
      if state and state.enabled then
        state_mod.clear(state)
        render.sync(state)
      end
    end,
  })
end

---@param opts MultiCursorOpts|nil
function M.setup(opts)
  if started then
    return
  end
  started = true

  opts = opts or {}
  ensure_plugin_help()
  config.setup(opts)
  if config.values.persistent_registers then
    state_mod.load_persistent_registers()
  end
  if config.values.backend == 'legacy' then
    require('multi_cursor.legacy').setup(opts)
    return
  end
  setup_highlights()
  create_commands()
  create_vm_alias_commands()
  keymaps.setup()
  create_autocmds()
end

M.actions = actions

return M
