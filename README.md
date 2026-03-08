# Multi_Cursor.nvim

Multi-cursor editing for Neovim with two backends:

- `lua`: native Lua implementation
- `legacy`: embedded `vim-visual-multi` runtime

Use `lua` for native integration and current development.
Use `legacy` if you want behavior closest to upstream `vim-visual-multi`.

## Install

```lua
return {
  'AdanW7/Multi_Cursor.nvim',
  branch = 'main',
}
```

## Minimal Setup

```lua
require('multi_cursor').setup({
  backend = 'lua',
})
```

## Example lazy.nvim Config (Lua Backend)

```lua
return {
  'AdanW7/Multi_Cursor.nvim',
  branch = 'main',
  dependencies = {
    { 'nvim-telescope/telescope.nvim', optional = true },
    { 'folke/snacks.nvim', optional = true },
  },
  opts = {
    backend = 'lua',                  -- lua | legacy
    picker = 'auto',                  -- auto | telescope | snacks | builtin
    insert_mode = 'native',           -- native insert replay
    multicursor_leader = '<leader>m', -- leader-derived default mapping prefix

    default_mappings = true,          -- keep built-in mapping set
    check_mappings = true,            -- detect and report conflicts
    show_warnings = true,             -- print conflict/runtime warnings

    use_visual_mode = true,           -- enable visual-origin workflows
    mouse_mappings = true,            -- enable mouse cursor/word/column actions

    theme = 'helix',
    highlight_matches = 'underline',

    single_mode_maps = true,
    single_mode_auto_reset = true,

    set_statusline = 2,
    silent_exit = true,
    skip_shorter_lines = false,

    enable_normal_key_passthrough = true,
    normal_keys = {
      'h', 'j', 'k', 'l',
      'w', 'W', 'b', 'B', 'e', 'E', 'ge', 'gE',
      '0', '^', '$', '%',
      'f', 'F', 't', 'T', ',', ';', '|',
      'gh', 'gs', 'gl',
    },

    mappings = {
      find_under = '<leader>mn',
      find_subword_under = '<leader>mN',
      select_all = '<leader>mA',
      regex_search = '<leader>m/',

      add_cursor_at_pos = '<leader>ma',
      add_cursor_down = { '<leader>mj', 'C' }, -- multiple keys for one action
      add_cursor_up = '<leader>mk',

      search_menu = '<leader>mp',
      tools_menu = '<leader>mt',
      case_conversion = '<leader>mC',          -- picker-backed case conversion menu

      toggle_mode = '<Tab>',
      toggle_mappings = '<leader>m<Space>',
      clear = '<leader>m<Esc>',
    },
  },
  keys = {
    { '<leader>mn', mode = { 'n', 'x' }, desc = 'MC: Find word' },
    { '<leader>mN', mode = { 'n', 'x' }, desc = 'MC: Find subword' },
    { '<leader>mA', mode = { 'n', 'x' }, desc = 'MC: Select all' },
    { '<leader>m/', mode = { 'n', 'x' }, desc = 'MC: Regex search' },
    { '<leader>ma', mode = { 'n' }, desc = 'MC: Add cursor at pos' },
    { '<leader>mj', mode = { 'n' }, desc = 'MC: Add cursor down' },
    { 'C', mode = { 'n' }, desc = 'MC: Add cursor down' },
    { '<leader>mk', mode = { 'n' }, desc = 'MC: Add cursor up' },
    { '<leader>mp', mode = { 'n', 'x' }, desc = 'MC: Search menu' },
    { '<leader>mt', mode = { 'n', 'x' }, desc = 'MC: Tools menu' },
    { '<leader>mC', mode = { 'n', 'x' }, desc = 'MC: Case conversion menu' },
    { '<Tab>', mode = { 'n' }, desc = 'MC: Toggle extend/cursor' },
    { '<leader>m<Space>', mode = { 'n' }, desc = 'MC: Toggle mappings' },
    { '<leader>m<Esc>', mode = { 'n' }, desc = 'MC: Clear' },
  },
}
```

## Basic Workflow

1. Add first region at cursor: `find_under`
2. Add next/prev match: `find_next` / `find_prev`
3. Skip/remove current region: `skip` / `remove`
4. Switch cursor/extend mode: `toggle_mode`
5. Exit and clear all regions: `clear`

## Picker Integration

`search_menu`, `tools_menu`, and regex match selection can use picker UI:

- `auto`: Telescope -> Snacks -> builtin
- `telescope`: prefer Telescope, fallback builtin
- `snacks`: prefer Snacks, fallback builtin
- `builtin`: `inputlist` picker only

## Help, Health, and Conflicts

- Help: `:help multi_cursor`
- Health: `:checkhealth multi_cursor`
- Conflicts: `:MultiCursorMappingConflicts`

If help tags are missing:

```vim
:helptags ALL
```

## Commands

Common commands:

- `:MultiCursorClear`
- `:MultiCursorRegex`
- `:MultiCursorSearchMenu`
- `:MultiCursorToolsMenu`
- `:MultiCursorCase [mode]` (`mode` optional, opens menu when omitted)

Legacy compatibility aliases are also available (`:VM...` commands), including:
`VMClear`, `VMSearch`, `VMFromSearch`, `VMRegisters`, `VMDebug`.

## Reference

- Full docs: [doc/multi_cursor.txt](doc/multi_cursor.txt)
- Legacy docs: [legacy/vim-visual-multi/doc](legacy/vim-visual-multi/doc)
