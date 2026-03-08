---@class MultiCursorLegacyModule
---@field setup fun(opts: MultiCursorOpts|nil)
local M = {}

local MAP_TO_VM = {
  find_under = 'Find Under',
  find_subword_under = 'Find Subword Under',
  find_next = 'Find Next',
  find_prev = 'Find Prev',
  goto_next = 'Goto Next',
  goto_prev = 'Goto Prev',
  seek_up = 'Seek Up',
  seek_down = 'Seek Down',
  invert_direction = 'Invert Direction',
  toggle_multiline = 'Toggle Multiline',
  toggle_mappings = 'Toggle Mappings',
  toggle_whole_word = 'Toggle Whole Word',
  skip = 'Skip Region',
  remove = 'Remove Region',
  remove_last_region = 'Remove Last Region',
  remove_empty_lines = 'Remove Empty Lines',
  add_cursor_down = 'Add Cursor Down',
  add_cursor_up = 'Add Cursor Up',
  add_cursor_at_pos = 'Add Cursor At Pos',
  add_cursor_at_word = 'Add Cursor At Word',
  select_all = 'Select All',
  regex_search = 'Start Regex Search',
  slash_search = 'Slash Search',
  align = 'Align',
  align_char = 'Align Char',
  align_regex = 'Align Regex',
  goto_regex = 'Goto Regex',
  goto_regex_remove = 'Goto Regex!',
  transpose = 'Transpose',
  duplicate = 'Duplicate',
  rotate = 'Rotate',
  filter_regions = 'Filter Regions',
  transform_regions = 'Transform Regions',
  surround = 'Surround',
  numbers_prepend = 'Numbers',
  numbers_append = 'Numbers Append',
  numbers_zero_prepend = 'Zero Numbers',
  numbers_zero_append = 'Zero Numbers Append',
  case_conversion = 'Case Conversion Menu',
  case_setting = 'Case Setting',
  search_menu = 'Search Menu',
  tools_menu = 'Tools Menu',
  show_registers = 'Show Registers',
  rewrite_last_search = 'Rewrite Last Search',
  run_ex = 'Run Ex',
  run_macro = 'Run Macro',
  run_normal = 'Run Normal',
  run_last_normal = 'Run Last Normal',
  run_visual = 'Run Visual',
  run_last_visual = 'Run Last Visual',
  run_last_ex = 'Run Last Ex',
  run_dot = 'Run Dot',
  shrink = 'Shrink',
  enlarge = 'Enlarge',
  replace_pattern = 'Replace Pattern',
  subtract_pattern = 'Subtract Pattern',
  split_regions = 'Split Regions',
  visual_regex = 'Visual Regex',
  visual_all = 'Visual All',
  visual_find = 'Visual Find',
  visual_cursors = 'Visual Cursors',
  visual_add = 'Visual Add',
  visual_subtract = 'Visual Subtract',
  visual_reduce = 'Visual Reduce',
  mouse_cursor = 'Mouse Cursor',
  mouse_word = 'Mouse Word',
  mouse_column = 'Mouse Column',
  reselect_last = 'Reselect Last',
  show_infoline = 'Show Infoline',
  one_per_line = 'One Per Line',
  merge_regions = 'Merge Regions',
  toggle_mode = 'Switch Mode',
  toggle_single_region = 'Toggle Single Region',
  remove_every_n_regions = 'Remove Every n Regions',
  undo = 'Undo',
  redo = 'Redo',
  delete_operator = 'Delete Operator',
  change_operator = 'Change Operator',
  yank_operator = 'Yank Operator',
  line_delete = 'D',
  line_yank = 'Y',
  delete_char = 'x',
  delete_char_before = 'X',
  join_lines = 'J',
  swap_case = '~',
  repeat_substitute = '&',
  delete_key = 'Del',
  dot = 'Dot',
  increase = 'Increase',
  decrease = 'Decrease',
  gincrease = 'gIncrease',
  gdecrease = 'gDecrease',
  alpha_increase = 'Alpha Increase',
  alpha_decrease = 'Alpha Decrease',
  insert_append = 'a',
  insert_append_eol = 'A',
  insert_insert = 'i',
  insert_insert_sol = 'I',
  open_below = 'o',
  open_above = 'O',
  comment_operator = 'gc',
  lower_operator = 'gu',
  upper_operator = 'gU',
  change_to_eol = 'C',
  replace_chars = 'Replace Characters',
  replace_mode = 'Replace',
  select_operator = 'Select Operator',
  find_operator = 'Find Operator',
  shift_right = 'Move Right',
  shift_left = 'Move Left',
  select_j = 'Select j',
  select_k = 'Select k',
  select_w = 'Select w',
  select_b = 'Select b',
  select_e = 'Select e',
  select_ge = 'Select ge',
  select_E = 'Select E',
  select_BBW = 'Select BBW',
  single_select_h = 'Single Select h',
  single_select_l = 'Single Select l',
  i_arrow_w = 'I Arrow w',
  i_arrow_b = 'I Arrow b',
  i_arrow_W = 'I Arrow W',
  i_arrow_B = 'I Arrow B',
  i_arrow_ge = 'I Arrow ge',
  i_arrow_e = 'I Arrow e',
  i_arrow_gE = 'I Arrow gE',
  i_arrow_E = 'I Arrow E',
  i_left_arrow = 'I Left Arrow',
  i_right_arrow = 'I Right Arrow',
  i_up_arrow = 'I Up Arrow',
  i_down_arrow = 'I Down Arrow',
  i_return = 'I Return',
  i_bs = 'I BS',
  i_ctrl_w = 'I CtrlW',
  i_ctrl_u = 'I CtrlU',
  i_ctrl_d = 'I CtrlD',
  i_ctrl_a = 'I CtrlA',
  i_ctrl_e = 'I CtrlE',
  i_paste = 'I Paste',
  i_ctrl_caret = 'I Ctrl^',
  i_del = 'I Del',
  i_home = 'I Home',
  i_end = 'I End',
  i_ctrl_b = 'I CtrlB',
  i_ctrl_f = 'I CtrlF',
  i_ctrl_c = 'I CtrlC',
  i_ctrl_o = 'I CtrlO',
  i_replace = 'I Replace',
  i_next = 'I Next',
  i_prev = 'I Prev',
  paste_after = 'p Paste',
  paste_before = 'P Paste',
  clear = 'Exit',
}

---@param path string
local function add_rtp(path)
  local rtp = vim.opt.rtp:get()
  for _, p in ipairs(rtp) do
    if p == path then
      return
    end
  end
  vim.opt.rtp:append(path)
end

---@param path string
local function source_plugin(path)
  local plugin = path .. '/plugin/visual-multi.vim'
  if vim.fn.filereadable(plugin) == 1 then
    vim.cmd('source ' .. vim.fn.fnameescape(plugin))
  end
end

---@param name string
---@param rhs function
local function alias_command(name, rhs)
  pcall(vim.api.nvim_del_user_command, name)
  vim.api.nvim_create_user_command(name, rhs, { nargs = '*', bang = true, count = true })
end

---@param v boolean
---@return integer
local function as_bool01(v)
  return v and 1 or 0
end

---@param opts table|nil
---@param key string
---@return boolean
local function has_opt(opts, key)
  return type(opts) == 'table' and opts[key] ~= nil
end

---@param opts MultiCursorOpts|nil
local function apply_opts_to_vm_globals(opts)
  if type(opts) ~= 'table' then
    return
  end

  if has_opt(opts, 'default_mappings') then
    vim.g.VM_default_mappings = as_bool01(opts.default_mappings ~= false)
  end
  if has_opt(opts, 'use_visual_mode') then
    vim.g.VM_use_visual_mode = as_bool01(opts.use_visual_mode ~= false)
  end
  if has_opt(opts, 'mouse_mappings') then
    vim.g.VM_mouse_mappings = as_bool01(opts.mouse_mappings == true)
  end
  if has_opt(opts, 'check_mappings') then
    vim.g.VM_check_mappings = as_bool01(opts.check_mappings ~= false)
  end
  if has_opt(opts, 'force_maps') then
    vim.g.VM_force_maps = vim.deepcopy(opts.force_maps or {})
  end
  if has_opt(opts, 'user_operators') then
    vim.g.VM_user_operators = vim.deepcopy(opts.user_operators or {})
  end
  if has_opt(opts, 'quit_after_leaving_insert_mode') then
    vim.g.VM_quit_after_leaving_insert_mode = as_bool01(opts.quit_after_leaving_insert_mode == true)
  end
  if has_opt(opts, 'reindent_filetypes') then
    vim.g.VM_reindent_filetypes = vim.deepcopy(opts.reindent_filetypes or {})
  end
  if has_opt(opts, 'disable_syntax_in_imode') then
    vim.g.VM_disable_syntax_in_imode = as_bool01(opts.disable_syntax_in_imode == true)
  end
  if has_opt(opts, 'set_statusline') then
    vim.g.VM_set_statusline = tonumber(opts.set_statusline) or 2
  end
  if has_opt(opts, 'silent_exit') then
    vim.g.VM_silent_exit = as_bool01(opts.silent_exit == true)
  end
  if has_opt(opts, 'show_warnings') then
    vim.g.VM_show_warnings = as_bool01(opts.show_warnings ~= false)
  end
  if has_opt(opts, 'verbose_commands') then
    vim.g.VM_verbose_commands = as_bool01(opts.verbose_commands == true)
  end
  if has_opt(opts, 'recursive_operations_at_cursors') then
    vim.g.VM_recursive_operations_at_cursors =
      as_bool01(opts.recursive_operations_at_cursors ~= false)
  end
  if has_opt(opts, 'add_cursor_at_pos_no_mappings') then
    vim.g.VM_add_cursor_at_pos_no_mappings = as_bool01(opts.add_cursor_at_pos_no_mappings == true)
  end
  if has_opt(opts, 'filesize_limit') then
    vim.g.VM_filesize_limit = tonumber(opts.filesize_limit) or 0
  end
  if has_opt(opts, 'persistent_registers') then
    vim.g.VM_persistent_registers = as_bool01(opts.persistent_registers == true)
  end
  if has_opt(opts, 'live_editing') then
    vim.g.VM_live_editing = as_bool01(opts.live_editing ~= false)
  end
  if has_opt(opts, 'reselect_first') then
    vim.g.VM_reselect_first = as_bool01(opts.reselect_first == true)
  end
  if has_opt(opts, 'case_setting') then
    vim.g.VM_case_setting = opts.case_setting or ''
  end
  if has_opt(opts, 'theme') then
    vim.g.VM_theme = opts.theme or ''
  end
  if has_opt(opts, 'highlight_matches') then
    vim.g.VM_highlight_matches = opts.highlight_matches or ''
  end
  if has_opt(opts, 'plugins_compatibility') then
    vim.g.VM_plugins_compatibilty = vim.deepcopy(opts.plugins_compatibility or {})
  end
  if has_opt(opts, 'skip_shorter_lines') then
    vim.g.VM_skip_shorter_lines = as_bool01(opts.skip_shorter_lines ~= false)
  end
  if has_opt(opts, 'skip_empty_lines') then
    vim.g.VM_skip_empty_lines = as_bool01(opts.skip_empty_lines == true)
  end
  if has_opt(opts, 'use_first_cursor_in_line') then
    vim.g.VM_use_first_cursor_in_line = as_bool01(opts.use_first_cursor_in_line == true)
  end
  if has_opt(opts, 'single_mode_auto_reset') then
    vim.g.VM_single_mode_auto_reset = as_bool01(opts.single_mode_auto_reset ~= false)
  end

  local leader = opts.leader
  if leader == nil then
    if opts.multicursor_leader ~= nil then
      leader = opts.multicursor_leader
    elseif opts.multicursorLeader ~= nil then
      leader = opts.multicursorLeader
    end
  end
  if has_opt(opts, 'leader') then
    if type(leader) == 'table' then
      vim.g.VM_leader = {
        default = leader.default or '\\',
        visual = leader.visual or leader.default or '\\',
        buffer = leader.buffer or leader.default or '\\',
      }
    elseif type(leader) == 'string' and leader ~= '' then
      vim.g.VM_leader = leader
    end
  elseif opts.multicursor_leader ~= nil or opts.multicursorLeader ~= nil then
    if type(leader) == 'table' then
      vim.g.VM_leader = {
        default = leader.default or '\\',
        visual = leader.visual or leader.default or '\\',
        buffer = leader.buffer or leader.default or '\\',
      }
    elseif type(leader) == 'string' and leader ~= '' then
      vim.g.VM_leader = leader
    end
  end

  if has_opt(opts, 'single_mode_maps') then
    local smm = opts.single_mode_maps
    if type(smm) == 'table' then
      vim.g.VM_single_mode_maps = vim.deepcopy(smm)
    else
      vim.g.VM_single_mode_maps = as_bool01(smm ~= false)
    end
  end

  if type(opts.vm_maps) == 'table' or type(opts.mappings) == 'table' then
    local vm_maps = vim.deepcopy(vim.g.VM_maps or {})

    for key, lhs in pairs(opts.vm_maps or {}) do
      if type(key) == 'string' and type(lhs) == 'string' then
        vm_maps[key] = lhs
      end
    end

    for key, lhs in pairs(opts.mappings or {}) do
      local vm_name = MAP_TO_VM[key]
      if vm_name and type(lhs) == 'string' then
        vm_maps[vm_name] = lhs
      end
    end
    vim.g.VM_maps = vm_maps
  end
end

---@param opts MultiCursorOpts|nil
function M.setup(opts)
  opts = opts or {}
  local this = debug.getinfo(1, 'S').source:sub(2)
  local plugin_root = vim.fn.fnamemodify(this, ':h:h:h')
  local legacy_root = opts.legacy_runtime_path or (plugin_root .. '/legacy/vim-visual-multi')

  apply_opts_to_vm_globals(opts)
  add_rtp(legacy_root)
  source_plugin(legacy_root)

  -- Optional command aliases for users preferring MultiCursor naming.
  alias_command('MultiCursorClear', function()
    vim.cmd('VMClear')
  end)
  alias_command('MultiCursorInfo', function()
    local ok, info = pcall(vim.fn['VMInfos'])
    if ok and type(info) == 'table' then
      print(vim.inspect(info))
    end
  end)
end

return M
