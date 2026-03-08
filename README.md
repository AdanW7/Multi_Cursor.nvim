# Multi_Cursor.nvim

`Multi_Cursor.nvim` gives you two ways to use multi-cursor editing in Neovim:

- `legacy` backend: embedded `vim-visual-multi` runtime (maximum historical compatibility).
- `lua` backend: native Lua implementation with active parity work and modern Neovim integration.

If you want the most predictable behavior today, use `legacy`.
If you want native Lua behavior and the current development target, use `lua`.

## Install (lazy.nvim)

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

## Recommended Human-First Config (Lua Backend)

This is a practical config with:
- a single `multicursor_leader`
- explicit WhichKey-friendly descriptions
- minimal mapping overrides
- native insert mode
- optional picker integration (`telescope`/`snacks`/builtin)

```lua
return {
  'AdanW7/Multi_Cursor.nvim',
  branch = 'main',
  opts = {
    backend = 'lua',
    insert_mode = 'native',

    -- New simplified leader option
    multicursor_leader = '<leader>m',

    -- Keep defaults ON so core behavior (extend, operators, etc.) is complete
    default_mappings = true,
    check_mappings = true,
    show_warnings = true,

    use_visual_mode = true,
    mouse_mappings = true,
    picker = 'auto', -- 'auto' | 'telescope' | 'snacks' | 'builtin'

    theme = 'helix',
    highlight_matches = 'underline',

    single_mode_maps = true,
    single_mode_auto_reset = true,

    set_statusline = 2,
    silent_exit = true,
    skip_shorter_lines = false,

    enable_normal_key_passthrough = true,
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
      'gh',
      'gs',
      'gl',
    },

    -- Start with minimal overrides only
    mappings = {
      add_cursor_down = '<leader>mj',
      add_cursor_up = '<leader>mk',
      add_cursor_at_pos = '<leader>ma',
      clear = '<leader>m<Esc>',
      -- optional explicit extend toggle (already auto-derived from multicursor_leader)
      toggle_mode = '<Tab>',
    },
  },
  keys = {
    { '<leader>mn', mode = { 'n', 'x' }, desc = 'MC: Find word' },
    { '<leader>mA', mode = { 'n', 'x' }, desc = 'MC: Select all' },
    { '<leader>m/', mode = { 'n', 'x' }, desc = 'MC: Regex search' },
    { '<leader>ma', mode = { 'n' }, desc = 'MC: Add cursor at pos' },
    { '<leader>mj', mode = { 'n' }, desc = 'MC: Add cursor down' },
    { '<leader>mk', mode = { 'n' }, desc = 'MC: Add cursor up' },
    { '<leader>m<Tab>', mode = { 'n' }, desc = 'MC: Toggle extend/cursor' },
    { '<leader>m<Esc>', mode = { 'n' }, desc = 'MC: Clear' },
  },
}
```

## Core Workflow

1. Start from a word: `find_under` (default `<C-n>`) or your custom mapping.
2. Add next/prev matches: `n` / `N`.
3. Skip current match: `q`.
4. Toggle cursor/extend mode: `<Tab>`.
5. Exit fully: clear mapping (or `:MultiCursorClear`).

## Help and Health

- Plugin help: `:help multi_cursor`
- Health check: `:checkhealth multi_cursor`
- Show mapping conflicts: `:MultiCursorMappingConflicts`

## Optional Picker Backends

Menu commands (`Search Menu`, `Tools Menu`) can use picker UIs.

- `picker = 'auto'`: prefers Telescope, then Snacks picker, else builtin.
- `picker = 'telescope'`: force Telescope, fallback to builtin if missing.
- `picker = 'snacks'`: force Snacks picker, fallback to builtin if missing.
- `picker = 'builtin'`: always use builtin list picker.

Regex search picker behavior:
- `regex_search` / `:MultiCursorRegex` now opens a match picker after entering a pattern.
- Telescope backend shows match previews; selecting an entry applies that match (or focuses it for select-all flows).

If help tags are missing, run:

```vim
:helptags ALL
```

## Legacy VM Aliases

Lua backend also exposes compatibility commands such as:
- `:VMClear`, `:VMDebug`, `:VMSearch`, `:VMFromSearch`, `:VMRegisters`, `:VMLive`
- `:VMSort`, `:VMQfix`, `:VMFilterRegions`, `:VMFilterLines`, `:VMRegionsToBuffer`, `:VMMassTranspose`

## Notes

- For full option/mapping reference, see [doc/multi_cursor.txt](doc/multi_cursor.txt).
- Embedded upstream legacy docs are under `legacy/vim-visual-multi/doc`.
