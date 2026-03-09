---@class MultiCursorConfigModule
---@field defaults MultiCursorConfigValues
---@field values MultiCursorConfigValues
---@field setup fun(opts: MultiCursorOpts|nil)
local M = {}

local VM_MAP_ALIASES = {
  ['Find Under'] = 'find_under',
  ['Seed Word Search'] = 'seed_word_search',
  ['Find Subword Under'] = 'find_subword_under',
  ['Find Next'] = 'find_next',
  ['Find Prev'] = 'find_prev',
  ['Goto Next'] = 'goto_next',
  ['Goto Prev'] = 'goto_prev',
  ['Seek Up'] = 'seek_up',
  ['Seek Down'] = 'seek_down',
  ['Invert Direction'] = 'invert_direction',
  ['Toggle Multiline'] = 'toggle_multiline',
  ['Toggle Mappings'] = 'toggle_mappings',
  ['Toggle Whole Word'] = 'toggle_whole_word',
  ['Skip Region'] = 'skip',
  ['Remove Region'] = 'remove',
  ['Remove Last Region'] = 'remove_last_region',
  ['Remove Empty Lines'] = 'remove_empty_lines',
  ['Select Cursor Down'] = 'add_cursor_down',
  ['Select Cursor Up'] = 'add_cursor_up',
  ['Add Cursor Down'] = 'add_cursor_down',
  ['Add Cursor Up'] = 'add_cursor_up',
  ['Add Cursor At Pos'] = 'add_cursor_at_pos',
  ['Add Cursor At Word'] = 'add_cursor_at_word',
  ['Select All'] = 'select_all',
  ['Start Regex Search'] = 'regex_search',
  ['Slash Search'] = 'slash_search',
  ['Align'] = 'align',
  ['Align Char'] = 'align_char',
  ['Align Regex'] = 'align_regex',
  ['Goto Regex'] = 'goto_regex',
  ['Goto Regex!'] = 'goto_regex_remove',
  ['Transpose'] = 'transpose',
  ['Duplicate'] = 'duplicate',
  ['Rotate'] = 'rotate',
  ['Filter Regions'] = 'filter_regions',
  ['Transform Regions'] = 'transform_regions',
  ['Surround'] = 'surround',
  ['Numbers'] = 'numbers_prepend',
  ['Numbers Append'] = 'numbers_append',
  ['Zero Numbers'] = 'numbers_zero_prepend',
  ['Zero Numbers Append'] = 'numbers_zero_append',
  ['Case Conversion Menu'] = 'case_conversion',
  ['Case Setting'] = 'case_setting',
  ['Search Menu'] = 'search_menu',
  ['Tools Menu'] = 'tools_menu',
  ['Show Registers'] = 'show_registers',
  ['Rewrite Last Search'] = 'rewrite_last_search',
  ['Run Ex'] = 'run_ex',
  ['Run Macro'] = 'run_macro',
  ['Run Normal'] = 'run_normal',
  ['Run Last Normal'] = 'run_last_normal',
  ['Run Visual'] = 'run_visual',
  ['Run Last Visual'] = 'run_last_visual',
  ['Run Last Ex'] = 'run_last_ex',
  ['Run Dot'] = 'run_dot',
  ['Shrink'] = 'shrink',
  ['Enlarge'] = 'enlarge',
  ['Replace Pattern'] = 'replace_pattern',
  ['Subtract Pattern'] = 'subtract_pattern',
  ['Split Regions'] = 'split_regions',
  ['Visual Regex'] = 'visual_regex',
  ['Visual All'] = 'visual_all',
  ['Visual Find'] = 'visual_find',
  ['Visual Cursors'] = 'visual_cursors',
  ['Visual Add'] = 'visual_add',
  ['Visual Subtract'] = 'visual_subtract',
  ['Visual Reduce'] = 'visual_reduce',
  ['Mouse Cursor'] = 'mouse_cursor',
  ['Mouse Word'] = 'mouse_word',
  ['Mouse Column'] = 'mouse_column',
  ['Reselect Last'] = 'reselect_last',
  ['Show Infoline'] = 'show_infoline',
  ['One Per Line'] = 'one_per_line',
  ['Merge Regions'] = 'merge_regions',
  ['Switch Mode'] = 'toggle_mode',
  ['Toggle Single Region'] = 'toggle_single_region',
  ['Remove Every n Regions'] = 'remove_every_n_regions',
  ['Undo'] = 'undo',
  ['Redo'] = 'redo',
  ['Delete Operator'] = 'delete_operator',
  ['Delete'] = 'delete_operator',
  ['Change Operator'] = 'change_operator',
  ['Yank Operator'] = 'yank_operator',
  ['Yank'] = 'yank_operator',
  ['D'] = 'line_delete',
  ['Y'] = 'line_yank',
  ['x'] = 'delete_char',
  ['X'] = 'delete_char_before',
  ['J'] = 'join_lines',
  ['~'] = 'swap_case',
  ['&'] = 'repeat_substitute',
  ['Del'] = 'delete_key',
  ['Dot'] = 'dot',
  ['Increase'] = 'increase',
  ['Decrease'] = 'decrease',
  ['gIncrease'] = 'gincrease',
  ['gDecrease'] = 'gdecrease',
  ['Alpha Increase'] = 'alpha_increase',
  ['Alpha Decrease'] = 'alpha_decrease',
  ['a'] = 'insert_append',
  ['A'] = 'insert_append_eol',
  ['i'] = 'insert_insert',
  ['I'] = 'insert_insert_sol',
  ['o'] = 'open_below',
  ['O'] = 'open_above',
  ['c'] = 'change_operator',
  ['gc'] = 'comment_operator',
  ['gu'] = 'lower_operator',
  ['gU'] = 'upper_operator',
  ['C'] = 'change_to_eol',
  ['Replace Characters'] = 'replace_chars',
  ['Replace'] = 'replace_mode',
  ['Select Operator'] = 'select_operator',
  ['Find Operator'] = 'find_operator',
  ['Move Right'] = 'shift_right',
  ['Move Left'] = 'shift_left',
  ['p Paste'] = 'paste_after',
  ['P Paste'] = 'paste_before',
  ['Select l'] = 'shift_right',
  ['Select h'] = 'shift_left',
  ['Select j'] = 'select_j',
  ['Select k'] = 'select_k',
  ['Select w'] = 'select_w',
  ['Select b'] = 'select_b',
  ['Select e'] = 'select_e',
  ['Select ge'] = 'select_ge',
  ['Select E'] = 'select_E',
  ['Select BBW'] = 'select_BBW',
  ['Single Select h'] = 'single_select_h',
  ['Single Select l'] = 'single_select_l',
  ['I Arrow w'] = 'i_arrow_w',
  ['I Arrow b'] = 'i_arrow_b',
  ['I Arrow W'] = 'i_arrow_W',
  ['I Arrow B'] = 'i_arrow_B',
  ['I Arrow ge'] = 'i_arrow_ge',
  ['I Arrow e'] = 'i_arrow_e',
  ['I Arrow gE'] = 'i_arrow_gE',
  ['I Arrow E'] = 'i_arrow_E',
  ['I Left Arrow'] = 'i_left_arrow',
  ['I Right Arrow'] = 'i_right_arrow',
  ['I Up Arrow'] = 'i_up_arrow',
  ['I Down Arrow'] = 'i_down_arrow',
  ['I Return'] = 'i_return',
  ['I BS'] = 'i_bs',
  ['I CtrlW'] = 'i_ctrl_w',
  ['I CtrlU'] = 'i_ctrl_u',
  ['I CtrlD'] = 'i_ctrl_d',
  ['I CtrlA'] = 'i_ctrl_a',
  ['I CtrlE'] = 'i_ctrl_e',
  ['I Paste'] = 'i_paste',
  ['I Ctrl^'] = 'i_ctrl_caret',
  ['I Del'] = 'i_del',
  ['I Home'] = 'i_home',
  ['I End'] = 'i_end',
  ['I CtrlB'] = 'i_ctrl_b',
  ['I CtrlF'] = 'i_ctrl_f',
  ['I CtrlC'] = 'i_ctrl_c',
  ['I CtrlO'] = 'i_ctrl_o',
  ['I Replace'] = 'i_replace',
  ['I Next'] = 'i_next',
  ['I Prev'] = 'i_prev',
  ['Exit'] = 'clear',
}

local VM_LEADER_MAPPINGS = {
  reselect_last = { scope = 'default', suffix = 'gS' },
  seed_word_search = { scope = 'default', suffix = '*' },
  add_cursor_at_pos = { scope = 'default', suffix = '\\' },
  regex_search = { scope = 'default', suffix = '/' },
  regex_search_all = { scope = 'default', suffix = '?' },
  goto_next = { scope = 'buffer', suffix = ']' },
  goto_prev = { scope = 'buffer', suffix = '[' },
  select_all = { scope = 'default', suffix = 'A' },
  visual_regex = { scope = 'visual', suffix = '/' },
  visual_all = { scope = 'visual', suffix = 'A' },
  visual_add = { scope = 'visual', suffix = 'a' },
  visual_find = { scope = 'visual', suffix = 'f' },
  visual_cursors = { scope = 'visual', suffix = 'c' },
  toggle_mappings = { scope = 'buffer', suffix = '<Space>' },
  toggle_single_region = { scope = 'buffer', suffix = '<CR>' },
  remove_last_region = { scope = 'buffer', suffix = 'q' },
  remove_every_n_regions = { scope = 'buffer', suffix = 'R' },
  tools_menu = { scope = 'buffer', suffix = '`' },
  show_registers = { scope = 'buffer', suffix = '"' },
  case_setting = { scope = 'buffer', suffix = 'c' },
  toggle_whole_word = { scope = 'buffer', suffix = 'w' },
  case_conversion = { scope = 'buffer', suffix = 'C' },
  search_menu = { scope = 'buffer', suffix = 'S' },
  rewrite_last_search = { scope = 'buffer', suffix = 'r' },
  show_infoline = { scope = 'buffer', suffix = 'l' },
  one_per_line = { scope = 'buffer', suffix = 'L' },
  filter_regions = { scope = 'buffer', suffix = 'f' },
  merge_regions = { scope = 'buffer', suffix = 'm' },
  transpose = { scope = 'buffer', suffix = 't' },
  duplicate = { scope = 'buffer', suffix = 'd' },
  align = { scope = 'buffer', suffix = '=' },
  split_regions = { scope = 'buffer', suffix = 's' },
  run_normal = { scope = 'buffer', suffix = 'z' },
  run_last_normal = { scope = 'buffer', suffix = 'Z' },
  run_visual = { scope = 'buffer', suffix = 'v' },
  run_last_visual = { scope = 'buffer', suffix = 'V' },
  run_ex = { scope = 'buffer', suffix = 'x' },
  run_last_ex = { scope = 'buffer', suffix = 'X' },
  run_macro = { scope = 'buffer', suffix = '@' },
  run_dot = { scope = 'buffer', suffix = '.' },
  align_char = { scope = 'buffer', suffix = '<' },
  align_regex = { scope = 'buffer', suffix = '>' },
  numbers_prepend = { scope = 'buffer', suffix = 'N' },
  numbers_append = { scope = 'buffer', suffix = 'n' },
  numbers_zero_prepend = { scope = 'buffer', suffix = '0N' },
  numbers_zero_append = { scope = 'buffer', suffix = '0n' },
  shrink = { scope = 'buffer', suffix = '-' },
  enlarge = { scope = 'buffer', suffix = '+' },
  goto_regex = { scope = 'buffer', suffix = 'g' },
  goto_regex_remove = { scope = 'buffer', suffix = 'G' },
  alpha_increase = { scope = 'buffer', suffix = '<C-a>' },
  alpha_decrease = { scope = 'buffer', suffix = '<C-x>' },
  transform_regions = { scope = 'buffer', suffix = 'e' },
  visual_subtract = { scope = 'visual', suffix = 's' },
  visual_reduce = { scope = 'visual', suffix = 'r' },
}

---@type MultiCursorConfigValues
M.defaults = {
  backend = 'legacy',
  default_mappings = true,
  use_visual_mode = true,
  mouse_mappings = false,
  single_mode_maps = true,
  single_mode_auto_reset = true,
  check_mappings = true,
  force_maps = {},
  user_operators = {},
  quit_after_leaving_insert_mode = false,
  reindent_filetypes = {},
  disable_syntax_in_imode = false,
  set_statusline = 2,
  silent_exit = false,
  show_warnings = true,
  verbose_commands = false,
  recursive_operations_at_cursors = true,
  add_cursor_at_pos_no_mappings = false,
  filesize_limit = 0,
  persistent_registers = false,
  live_editing = true,
  reselect_first = false,
  case_setting = '',
  plugins_compatibility = {},
  picker = 'auto',
  theme = 'helix',
  highlight_matches = '',
  mappings = {
    add_cursor_down = '<C-Down>',
    add_cursor_up = '<C-Up>',
    add_cursor_at_pos = '\\\\',
    add_cursor_at_word = '',
    seed_word_search = '\\*',
    find_under = '<C-n>',
    find_subword_under = '<C-n>',
    find_next = 'n',
    find_prev = 'N',
    goto_next = '',
    goto_prev = '',
    seek_up = '<C-b>',
    seek_down = '<C-f>',
    invert_direction = 'o',
    toggle_mappings = '\\<Space>',
    toggle_whole_word = '\\w',
    toggle_multiline = 'M',
    skip = 'q',
    remove = 'Q',
    remove_last_region = '\\q',
    remove_empty_lines = '',
    select_all = '\\A',
    regex_search = '\\/',
    regex_search_all = '\\?',
    slash_search = 'g/',
    align = '\\=',
    align_char = '\\<',
    align_regex = '\\>',
    goto_regex = '\\g',
    goto_regex_remove = '\\G',
    transpose = '\\t',
    duplicate = '\\d',
    rotate = '',
    filter_regions = '\\f',
    transform_regions = '\\e',
    surround = 'S',
    numbers_append = '\\n',
    numbers_prepend = '\\N',
    numbers_zero_prepend = '\\0N',
    numbers_zero_append = '\\0n',
    case_conversion = '\\C',
    case_setting = '\\c',
    search_menu = '\\S',
    tools_menu = '\\`',
    show_registers = '\\"',
    rewrite_last_search = '\\r',
    run_ex = '\\x',
    run_macro = '\\@',
    run_normal = '\\z',
    run_last_normal = '\\Z',
    run_visual = '\\v',
    run_last_visual = '\\V',
    run_last_ex = '\\X',
    run_dot = '\\.',
    shrink = '\\-',
    enlarge = '\\+',
    replace_pattern = 'R',
    subtract_pattern = '\\s',
    split_regions = '',
    visual_regex = '\\/',
    visual_all = '\\A',
    visual_find = '\\f',
    visual_cursors = '\\\\',
    visual_add = '\\a',
    visual_subtract = '\\s',
    visual_reduce = '\\r',
    mouse_cursor = '',
    mouse_word = '',
    mouse_column = '',
    reselect_last = '\\gS',
    show_infoline = '\\l',
    one_per_line = '\\L',
    merge_regions = '\\m',
    toggle_single_region = '\\<CR>',
    remove_every_n_regions = '\\R',
    undo = 'u',
    redo = '<C-r>',
    delete_operator = 'd',
    change_operator = 'c',
    yank_operator = 'y',
    line_delete = 'D',
    line_yank = 'Y',
    delete_char = 'x',
    delete_char_before = 'X',
    join_lines = 'J',
    swap_case = '~',
    repeat_substitute = '&',
    delete_key = '<Del>',
    dot = '.',
    increase = '<C-a>',
    decrease = '<C-x>',
    gincrease = 'g<C-a>',
    gdecrease = 'g<C-x>',
    alpha_increase = '\\<C-a>',
    alpha_decrease = '\\<C-x>',
    insert_insert = 'i',
    insert_append = 'a',
    insert_insert_sol = 'I',
    insert_append_eol = 'A',
    open_below = 'o',
    open_above = 'O',
    comment_operator = 'gc',
    lower_operator = 'gu',
    upper_operator = 'gU',
    change_to_eol = 'C',
    replace_chars = '',
    replace_mode = 'R',
    select_operator = 's',
    find_operator = 'm',
    toggle_mode = '<Tab>',
    shift_right = '<S-Right>',
    shift_left = '<S-Left>',
    select_j = '',
    select_k = '',
    select_w = '',
    select_b = '',
    select_e = '',
    select_ge = '',
    select_E = '',
    select_BBW = '',
    single_select_h = '',
    single_select_l = '',
    i_arrow_w = '<C-Right>',
    i_arrow_b = '<C-Left>',
    i_arrow_W = '<C-S-Right>',
    i_arrow_B = '<C-S-Left>',
    i_arrow_ge = '<C-Up>',
    i_arrow_e = '<C-Down>',
    i_arrow_gE = '<C-S-Up>',
    i_arrow_E = '<C-S-Down>',
    i_left_arrow = '<Left>',
    i_right_arrow = '<Right>',
    i_up_arrow = '<Up>',
    i_down_arrow = '<Down>',
    i_return = '<CR>',
    i_bs = '<BS>',
    i_ctrl_w = '<C-w>',
    i_ctrl_u = '<C-u>',
    i_ctrl_d = '<C-d>',
    i_ctrl_a = '',
    i_ctrl_e = '',
    i_paste = '',
    i_ctrl_caret = '<C-^>',
    i_del = '<Del>',
    i_home = '<Home>',
    i_end = '<End>',
    i_ctrl_b = '<C-b>',
    i_ctrl_f = '<C-f>',
    i_ctrl_c = '<C-c>',
    i_ctrl_o = '<C-o>',
    i_replace = '<Insert>',
    i_next = '<Tab>',
    i_prev = '<S-Tab>',
    paste_after = 'p',
    paste_before = 'P',
    invert_direction_alt = 'O',
    clear = '<Esc>',
  },
  -- Explicit allow-list of normal-mode keys that should be replayed
  -- across all cursors while multicursor mode is active.
  normal_keys = {
    'h',
    'j',
    'k',
    'l',
    'w',
    'W',
    'b',
    'B',
    'e',
    'E',
    'ge',
    'gE',
    '0',
    '^',
    '$',
    '%',
    'f',
    'F',
    't',
    'T',
    ',',
    ';',
    '|',
  },
  enable_normal_key_passthrough = true,
  custom_noremaps = {},
  custom_remaps = {},
  custom_commands = {},
  custom_motions = {},
  highlights = {
    cursor = 'MultiCursorCursor',
    extend = 'MultiCursorExtend',
    mono = 'MultiCursorMono',
    insert = 'MultiCursorInsert',
  },
  skip_shorter_lines = true,
  skip_empty_lines = false,
  use_first_cursor_in_line = false,
  smart_paste_from_multicursor = true,
  insert_mode = 'prompt',
  legacy_runtime_path = nil,
  leader = {
    default = '\\',
    visual = '\\',
    buffer = '\\',
  },
}

---@type MultiCursorConfigValues
M.values = vim.deepcopy(M.defaults)

---@param values MultiCursorConfigValues
---@param vm_maps table<string, string>|nil
local function apply_vm_compat_maps(values, vm_maps)
  if type(vm_maps) ~= 'table' then
    return
  end
  for vm_name, key in pairs(vm_maps) do
    local alias = VM_MAP_ALIASES[vm_name]
    if alias and type(key) == 'string' then
      values.mappings[alias] = key
    end
  end
end

---@param value string|MultiCursorLeaderConfig|nil
---@return MultiCursorLeaderConfig
local function normalize_vm_leader(value)
  local fallback = { default = '\\', visual = '\\', buffer = '\\' }
  if type(value) == 'string' then
    return { default = value, visual = value, buffer = value }
  end
  if type(value) ~= 'table' then
    return fallback
  end
  return {
    default = type(value.default) == 'string' and value.default or fallback.default,
    visual = type(value.visual) == 'string' and value.visual or fallback.visual,
    buffer = type(value.buffer) == 'string' and value.buffer or fallback.buffer,
  }
end

---@param values MultiCursorConfigValues
---@param user_mapping_overrides table<string, boolean>|nil
local function apply_vm_leader(values, user_mapping_overrides)
  values.leader = normalize_vm_leader(values.leader)
  local overrides = user_mapping_overrides or {}
  for name, spec in pairs(VM_LEADER_MAPPINGS) do
    if not overrides[name] then
      local leader = values.leader[spec.scope]
      if type(leader) == 'string' then
        values.mappings[name] = leader .. spec.suffix
      end
    end
  end
end

---@param values MultiCursorConfigValues
---@param explicit table<string, string|string[]>|nil
local function apply_default_mapping_policy(values, explicit)
  if values.default_mappings then
    return
  end
  for name, _ in pairs(values.mappings) do
    values.mappings[name] = ''
  end
  if type(explicit) == 'table' then
    for name, lhs in pairs(explicit) do
      if type(name) == 'string' and (type(lhs) == 'string' or type(lhs) == 'table') then
        values.mappings[name] = lhs
      end
    end
  end
end

---@param values MultiCursorConfigValues
local function apply_mouse_mapping_policy(values)
  local m = values.mappings
  if values.mouse_mappings then
    if m.mouse_cursor == '' then
      m.mouse_cursor = '<C-LeftMouse>'
    end
    if m.mouse_word == '' then
      m.mouse_word = '<C-RightMouse>'
    end
    if m.mouse_column == '' then
      m.mouse_column = '<M-C-RightMouse>'
    end
    return
  end
  m.mouse_cursor = ''
  m.mouse_word = ''
  m.mouse_column = ''
end

---@param values MultiCursorConfigValues
local function apply_vm_compat_globals(values)
  if vim.g.VM_default_mappings ~= nil then
    values.default_mappings = vim.g.VM_default_mappings ~= 0
  end
  if vim.g.VM_use_visual_mode ~= nil then
    values.use_visual_mode = vim.g.VM_use_visual_mode ~= 0
  end
  if vim.g.VM_mouse_mappings ~= nil then
    values.mouse_mappings = vim.g.VM_mouse_mappings ~= 0
  end
  if vim.g.VM_check_mappings ~= nil then
    values.check_mappings = vim.g.VM_check_mappings ~= 0
  end
  if type(vim.g.VM_force_maps) == 'table' then
    values.force_maps = vim.deepcopy(vim.g.VM_force_maps)
  end
  if type(vim.g.VM_single_mode_maps) == 'table' then
    values.single_mode_maps = true
    for lhs, delta in pairs(vim.g.VM_single_mode_maps) do
      if type(lhs) == 'string' and lhs ~= '' then
        local step = tonumber(delta)
        if step == 1 then
          values.mappings.i_next = lhs
        elseif step == -1 then
          values.mappings.i_prev = lhs
        end
      end
    end
  elseif vim.g.VM_single_mode_maps ~= nil then
    values.single_mode_maps = vim.g.VM_single_mode_maps ~= 0
  end
  if vim.g.VM_single_mode_auto_reset ~= nil then
    values.single_mode_auto_reset = vim.g.VM_single_mode_auto_reset ~= 0
  end
  if vim.g.VM_quit_after_leaving_insert_mode ~= nil then
    values.quit_after_leaving_insert_mode = vim.g.VM_quit_after_leaving_insert_mode ~= 0
  end
  if type(vim.g.VM_reindent_filetypes) == 'table' then
    values.reindent_filetypes = vim.deepcopy(vim.g.VM_reindent_filetypes)
  end
  if vim.g.VM_disable_syntax_in_imode ~= nil then
    values.disable_syntax_in_imode = vim.g.VM_disable_syntax_in_imode ~= 0
  end
  if vim.g.VM_set_statusline ~= nil then
    values.set_statusline = tonumber(vim.g.VM_set_statusline) or values.set_statusline
  end
  if vim.g.VM_silent_exit ~= nil then
    values.silent_exit = vim.g.VM_silent_exit ~= 0
  end
  if vim.g.VM_show_warnings ~= nil then
    values.show_warnings = vim.g.VM_show_warnings ~= 0
  end
  if vim.g.VM_verbose_commands ~= nil then
    values.verbose_commands = vim.g.VM_verbose_commands ~= 0
  end
  if vim.g.VM_recursive_operations_at_cursors ~= nil then
    values.recursive_operations_at_cursors = vim.g.VM_recursive_operations_at_cursors ~= 0
  end
  if vim.g.VM_add_cursor_at_pos_no_mappings ~= nil then
    values.add_cursor_at_pos_no_mappings = vim.g.VM_add_cursor_at_pos_no_mappings ~= 0
  end
  if vim.g.VM_filesize_limit ~= nil then
    values.filesize_limit = tonumber(vim.g.VM_filesize_limit) or 0
  end
  if vim.g.VM_persistent_registers ~= nil then
    values.persistent_registers = vim.g.VM_persistent_registers ~= 0
  end
  if vim.g.VM_live_editing ~= nil then
    values.live_editing = vim.g.VM_live_editing ~= 0
  end
  if vim.g.VM_reselect_first ~= nil then
    values.reselect_first = vim.g.VM_reselect_first ~= 0
  end
  if type(vim.g.VM_case_setting) == 'string' then
    values.case_setting = vim.g.VM_case_setting
  end
  if type(vim.g.VM_theme) == 'string' then
    values.theme = vim.g.VM_theme
  end
  if type(vim.g.VM_highlight_matches) == 'string' then
    values.highlight_matches = vim.g.VM_highlight_matches
  end
  if type(vim.g.VM_plugins_compatibilty) == 'table' then
    values.plugins_compatibility = vim.deepcopy(vim.g.VM_plugins_compatibilty)
  elseif type(vim.g.VM_plugins_compatibility) == 'table' then
    values.plugins_compatibility = vim.deepcopy(vim.g.VM_plugins_compatibility)
  end
  if vim.g.VM_leader ~= nil then
    values.leader = normalize_vm_leader(vim.g.VM_leader)
  end

  if type(vim.g.VM_custom_noremaps) == 'table' then
    values.custom_noremaps = vim.deepcopy(vim.g.VM_custom_noremaps)
  end
  if type(vim.g.VM_custom_remaps) == 'table' then
    values.custom_remaps = vim.deepcopy(vim.g.VM_custom_remaps)
  end
  if type(vim.g.VM_custom_commands) == 'table' then
    values.custom_commands = vim.deepcopy(vim.g.VM_custom_commands)
  end
  if type(vim.g.VM_custom_motions) == 'table' then
    values.custom_motions = vim.deepcopy(vim.g.VM_custom_motions)
  end
  if type(vim.g.VM_user_operators) == 'table' then
    local ops = {}
    for _, entry in ipairs(vim.g.VM_user_operators) do
      if type(entry) == 'string' and entry ~= '' then
        table.insert(ops, entry)
      elseif type(entry) == 'table' then
        for key, _ in pairs(entry) do
          if type(key) == 'string' and key ~= '' then
            table.insert(ops, key)
          end
        end
      end
    end
    values.user_operators = ops
  end

  if vim.g.VM_skip_shorter_lines ~= nil then
    values.skip_shorter_lines = vim.g.VM_skip_shorter_lines ~= 0
  end
  if vim.g.VM_skip_empty_lines ~= nil then
    values.skip_empty_lines = vim.g.VM_skip_empty_lines ~= 0
  end
  if vim.g.VM_use_first_cursor_in_line ~= nil then
    values.use_first_cursor_in_line = vim.g.VM_use_first_cursor_in_line ~= 0
  end
  if type(vim.g.VM_insert_special_keys) == 'table' then
    local has = {}
    for _, k in ipairs(vim.g.VM_insert_special_keys) do
      has[k] = true
    end
    if has['c-a'] then
      values.mappings.i_ctrl_a = '<C-a>'
    end
    if has['c-e'] then
      values.mappings.i_ctrl_e = '<C-e>'
    end
    if has['c-v'] then
      values.mappings.i_paste = '<C-v>'
    end
  end
end

---@param values MultiCursorConfigValues
---@param opts table|nil
local function apply_backward_compat_opts(values, opts)
  if type(opts) ~= 'table' then
    return
  end

  if opts.inherit_normal_motions ~= nil then
    values.enable_normal_key_passthrough = opts.inherit_normal_motions
  end

  if type(opts.normal_mode_motions) == 'table' then
    values.normal_keys = opts.normal_mode_motions
  end

  if type(opts.custom_noremaps) == 'table' then
    values.custom_noremaps = vim.deepcopy(opts.custom_noremaps)
  end
  if type(opts.custom_remaps) == 'table' then
    values.custom_remaps = vim.deepcopy(opts.custom_remaps)
  end
  if type(opts.custom_commands) == 'table' then
    values.custom_commands = vim.deepcopy(opts.custom_commands)
  end
  if type(opts.custom_motions) == 'table' then
    values.custom_motions = vim.deepcopy(opts.custom_motions)
  end

  if opts.default_mappings ~= nil then
    values.default_mappings = opts.default_mappings
  end
  if opts.use_visual_mode ~= nil then
    values.use_visual_mode = opts.use_visual_mode
  end
  if opts.mouse_mappings ~= nil then
    values.mouse_mappings = opts.mouse_mappings
  end
  if opts.skip_empty_lines ~= nil then
    values.skip_empty_lines = opts.skip_empty_lines
  end
  if opts.use_first_cursor_in_line ~= nil then
    values.use_first_cursor_in_line = opts.use_first_cursor_in_line
  end
  if opts.single_mode_maps ~= nil then
    values.single_mode_maps = opts.single_mode_maps
  end
  if opts.single_mode_auto_reset ~= nil then
    values.single_mode_auto_reset = opts.single_mode_auto_reset
  end
  if opts.check_mappings ~= nil then
    values.check_mappings = opts.check_mappings
  end
  if type(opts.force_maps) == 'table' then
    values.force_maps = vim.deepcopy(opts.force_maps)
  end
  if type(opts.user_operators) == 'table' then
    values.user_operators = vim.deepcopy(opts.user_operators)
  end
  if opts.quit_after_leaving_insert_mode ~= nil then
    values.quit_after_leaving_insert_mode = opts.quit_after_leaving_insert_mode
  end
  if type(opts.reindent_filetypes) == 'table' then
    values.reindent_filetypes = vim.deepcopy(opts.reindent_filetypes)
  end
  if opts.disable_syntax_in_imode ~= nil then
    values.disable_syntax_in_imode = opts.disable_syntax_in_imode
  end
  if opts.set_statusline ~= nil then
    values.set_statusline = opts.set_statusline
  end
  if opts.silent_exit ~= nil then
    values.silent_exit = opts.silent_exit
  end
  if opts.show_warnings ~= nil then
    values.show_warnings = opts.show_warnings
  end
  if opts.verbose_commands ~= nil then
    values.verbose_commands = opts.verbose_commands
  end
  if opts.recursive_operations_at_cursors ~= nil then
    values.recursive_operations_at_cursors = opts.recursive_operations_at_cursors
  end
  if opts.add_cursor_at_pos_no_mappings ~= nil then
    values.add_cursor_at_pos_no_mappings = opts.add_cursor_at_pos_no_mappings
  end
  if opts.filesize_limit ~= nil then
    values.filesize_limit = opts.filesize_limit
  end
  if opts.persistent_registers ~= nil then
    values.persistent_registers = opts.persistent_registers
  end
  if opts.live_editing ~= nil then
    values.live_editing = opts.live_editing
  end
  if opts.reselect_first ~= nil then
    values.reselect_first = opts.reselect_first
  end
  if opts.case_setting ~= nil then
    values.case_setting = opts.case_setting
  end
  if opts.theme ~= nil then
    values.theme = opts.theme
  end
  if opts.picker ~= nil then
    values.picker = opts.picker
  end
  if opts.highlight_matches ~= nil then
    values.highlight_matches = opts.highlight_matches
  end
  if type(opts.plugins_compatibility) == 'table' then
    values.plugins_compatibility = vim.deepcopy(opts.plugins_compatibility)
  end
  if opts.vm_leader ~= nil then
    values.leader = normalize_vm_leader(opts.vm_leader)
  elseif opts.multicursor_leader ~= nil then
    values.leader = normalize_vm_leader(opts.multicursor_leader)
  elseif opts.multicursorLeader ~= nil then
    values.leader = normalize_vm_leader(opts.multicursorLeader)
  elseif opts.leader ~= nil then
    values.leader = normalize_vm_leader(opts.leader)
  end
  if
    (opts.multicursor_leader ~= nil or opts.multicursorLeader ~= nil)
    and type(values.leader) == 'table'
  then
    local has_explicit_toggle_mode = type(opts.mappings) == 'table'
      and opts.mappings.toggle_mode ~= nil
    if not has_explicit_toggle_mode then
      values.mappings.toggle_mode = values.leader.buffer .. '<Tab>'
    end
  end
end

---@param opts MultiCursorOpts|nil
function M.setup(opts)
  local merged = vim.tbl_deep_extend('force', vim.deepcopy(M.defaults), opts or {})
  local explicit_mappings = {}
  local user_mapping_overrides = {}
  if type(opts) == 'table' and type(opts.mappings) == 'table' then
    for name, value in pairs(opts.mappings) do
      if type(value) == 'string' or type(value) == 'table' then
        user_mapping_overrides[name] = true
        if type(value) == 'table' then
          explicit_mappings[name] = vim.deepcopy(value)
        else
          explicit_mappings[name] = value
        end
      end
    end
  end
  apply_vm_compat_globals(merged)
  apply_backward_compat_opts(merged, opts)
  apply_vm_leader(merged, user_mapping_overrides)
  apply_default_mapping_policy(merged, explicit_mappings)
  apply_mouse_mapping_policy(merged)
  apply_vm_compat_maps(merged, vim.g.VM_maps)
  if type(opts) == 'table' then
    apply_vm_compat_maps(merged, opts.vm_maps)
  end
  M.values = merged
end

return M
