---@class MultiCursorHealthModule
---@field check fun()
local M = {}

---@param msg string
local function start(msg)
  if vim.health and vim.health.start then
    vim.health.start(msg)
  end
end

---@param msg string
local function ok(msg)
  if vim.health and vim.health.ok then
    vim.health.ok(msg)
  end
end

---@param msg string
---@param advice string[]|nil
local function warn(msg, advice)
  if vim.health and vim.health.warn then
    vim.health.warn(msg, advice)
  end
end

---@param msg string
local function info(msg)
  if vim.health and vim.health.info then
    vim.health.info(msg)
  end
end

---@param msg string
---@param advice string[]|nil
local function err(msg, advice)
  if vim.health and vim.health.error then
    vim.health.error(msg, advice)
  end
end

---@param name string
---@return boolean
local function has_cmd(name)
  return vim.fn.exists(':' .. name) == 2
end

local function ensure_helptags(path)
  if vim.fn.isdirectory(path) ~= 1 then
    return
  end
  if vim.fn.filereadable(path .. '/tags') == 1 then
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

---@return string[]
local function current_conflicts()
  local config = require('multi_cursor.config')
  local seen = {}
  local conflicts = {}
  for _, raw in pairs(config.values.mappings or {}) do
    local keys = {}
    if type(raw) == 'string' then
      keys = { raw }
    elseif type(raw) == 'table' then
      keys = raw
    end
    for _, lhs in ipairs(keys) do
      if type(lhs) == 'string' and lhs ~= '' and not seen[lhs] then
        seen[lhs] = true
        local nmap = vim.fn.maparg(lhs, 'n', false, true)
        if type(nmap) == 'table' and nmap.buffer == 1 then
          table.insert(conflicts, string.format('n %s', lhs))
        end
        local xmap = vim.fn.maparg(lhs, 'x', false, true)
        if type(xmap) == 'table' and xmap.buffer == 1 then
          table.insert(conflicts, string.format('x %s', lhs))
        end
        local imap = vim.fn.maparg(lhs, 'i', false, true)
        if type(imap) == 'table' and imap.buffer == 1 then
          table.insert(conflicts, string.format('i %s', lhs))
        end
      end
    end
  end
  table.sort(conflicts)
  return conflicts
end

---@return nil
function M.check()
  start('Multi_Cursor.nvim')
  ensure_plugin_help()
  local ok_setup, mc = pcall(require, 'multi_cursor')
  if not ok_setup then
    err('Failed to require multi_cursor', { tostring(mc) })
    return
  end
  ok('Lua modules load')

  local config = require('multi_cursor.config')
  info(string.format('Configured backend: %s', tostring(config.values.backend)))

  local help_tags = vim.fn.taglist('multi_cursor')
  if type(help_tags) == 'table' and #help_tags > 0 then
    ok('Help tags available (`:h multi_cursor`)')
  else
    warn('Help tags for `multi_cursor` not found', {
      'Run `:helptags ALL` then open `:h multi_cursor`.',
    })
  end

  local has_vmclear = has_cmd('VMClear')
  local has_mcclear = has_cmd('MultiCursorClear')
  if has_vmclear and has_mcclear then
    ok('Core commands exist (`:VMClear`, `:MultiCursorClear`)')
  else
    warn('Core clear commands are missing', {
      'Call `require("multi_cursor").setup()` in your config before using mappings.',
    })
  end

  local keymaps = require('multi_cursor.keymaps')
  local runtime_conflicts = {}
  if type(keymaps.conflicts) == 'function' then
    runtime_conflicts = keymaps.conflicts()
  end
  local buf_conflicts = current_conflicts()
  if #runtime_conflicts == 0 and #buf_conflicts == 0 then
    ok('No mapping conflicts detected in current buffer')
  else
    local lines = {}
    if #runtime_conflicts > 0 then
      table.insert(lines, 'Conflicts skipped during MultiCursor keymap setup:')
      for _, lhs in ipairs(runtime_conflicts) do
        table.insert(lines, '  - ' .. lhs)
      end
    end
    if #buf_conflicts > 0 then
      table.insert(lines, 'Current buffer-local conflicts:')
      for _, lhs in ipairs(buf_conflicts) do
        table.insert(lines, '  - ' .. lhs)
      end
    end
    warn('Mapping conflicts detected', lines)
  end

  if config.values.backend == 'lua' then
    local picker = require('multi_cursor.picker')
    local configured_picker = tostring(config.values.picker or 'auto')
    local active_picker = picker.backend()
    info(string.format('Picker backend: %s (configured: %s)', active_picker, configured_picker))
    if configured_picker ~= 'auto' and configured_picker ~= active_picker then
      warn('Configured picker backend unavailable; using builtin fallback', {
        string.format(
          'Configured `%s` but active picker is `%s`.',
          configured_picker,
          active_picker
        ),
      })
    end

    local m = config.values.mappings or {}
    local has_extend_entry = type(m.toggle_mode) == 'string' and m.toggle_mode ~= ''
    if not has_extend_entry then
      warn('No mapping configured to toggle cursor/extend mode in Lua backend', {
        "Set `mappings.toggle_mode` (example: '<leader>m<Tab>' or '<Tab>'), or use :MultiCursorToggleMode.",
      })
    end
    warn('Lua backend has intentional Vim-divergence edge cases', {
      'Some text-object edge cases still differ from legacy VM in Lua backend.',
    })
    info('Lua backend help: `:h multi_cursor`')
  else
    info('Legacy backend help: `:h visual-multi`')
  end
end

return M
