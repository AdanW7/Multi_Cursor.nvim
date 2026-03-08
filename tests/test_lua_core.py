from tests.nvim_case import NvimCase


class TestLuaCore(NvimCase):
    def test_commands_are_registered(self):
        result = self.run_case(
            """
            local cmds = {
              'MultiCursorAddCursorDown',
              'MultiCursorAddCursorUp',
              'MultiCursorAddCursorAtPos',
              'MultiCursorFindUnder',
              'MultiCursorRegex',
              'MultiCursorRegexAll',
              'MultiCursorVisualRegex',
              'MultiCursorVisualAll',
              'MultiCursorVisualFind',
              'MultiCursorVisualCursors',
              'MultiCursorVisualAdd',
              'MultiCursorVisualSubtract',
              'MultiCursorVisualReduce',
              'MultiCursorFindNext',
              'MultiCursorFindPrev',
              'MultiCursorReselectLast',
              'MultiCursorGotoNext',
              'MultiCursorGotoPrev',
              'MultiCursorInvertDirection',
              'MultiCursorToggleMultiline',
              'MultiCursorDelete',
              'MultiCursorChange',
              'MultiCursorOperator',
              'MultiCursorSelectOperator',
              'MultiCursorFindOperator',
              'MultiCursorRunNormal',
              'MultiCursorRunLastNormal',
              'MultiCursorRunVisual',
              'MultiCursorRunLastVisual',
              'MultiCursorRunLastEx',
              'MultiCursorRunDot',
              'MultiCursorRemoveEveryN',
              'MultiCursorToggleSingleRegion',
              'MultiCursorSkip',
              'MultiCursorRemove',
              'MultiCursorRemoveLastRegion',
              'MultiCursorRemoveEmptyLines',
              'MultiCursorSelectAll',
              'MultiCursorAlign',
              'MultiCursorAlignChar',
              'MultiCursorAlignRegex',
              'MultiCursorTranspose',
              'MultiCursorRotate',
              'MultiCursorSurround',
              'MultiCursorDuplicate',
              'MultiCursorFilter',
              'MultiCursorFilterInverse',
              'MultiCursorTransform',
              'MultiCursorReplacePattern',
              'MultiCursorSubtractPattern',
              'MultiCursorNumbersAppend',
              'MultiCursorNumbersPrepend',
              'MultiCursorZeroNumbersAppend',
              'MultiCursorZeroNumbersPrepend',
              'MultiCursorCase',
              'MultiCursorCaseSetting',
              'MultiCursorSearchMenu',
              'MultiCursorToolsMenu',
              'MultiCursorShowRegisters',
              'MultiCursorRewriteLastSearch',
              'MultiCursorEx',
              'MultiCursorMacro',
              'MultiCursorUndo',
              'MultiCursorRedo',
              'MultiCursorToggleMode',
              'MultiCursorClear',
              'MultiCursorYank',
              'MultiCursorPaste',
              'MultiCursorInsert',
              'MultiCursorNormal',
              'MultiCursorInfo',
              'MultiCursorShowInfoline',
              'MultiCursorOnePerLine',
              'MultiCursorMergeRegions',
              'MultiCursorToggleMappings',
              'MultiCursorToggleWholeWord',
              'MultiCursorSeekUp',
              'MultiCursorSeekDown',
              'MultiCursorGotoRegex',
              'MultiCursorGotoRegexRemove',
              'MultiCursorAddCursorAtWord',
              'MultiCursorSplitRegions',
            }
            local missing = {}
            for _, c in ipairs(cmds) do
              if vim.fn.exists(':' .. c) ~= 2 then
                table.insert(missing, c)
              end
            end
            return { missing = missing }
            """
        )
        self.assertEqual(result["missing"], [])

    def test_vm_alias_commands_are_registered(self):
        result = self.run_case(
            """
            local cmds = {
              'VMClear',
              'VMDebug',
              'VMLive',
              'VMSearch',
              'VMFromSearch',
              'VMRegisters',
              'VMTheme',
              'VMSort',
              'VMQfix',
              'VMFilterRegions',
              'VMFilterLines',
              'VMRegionsToBuffer',
              'VMMassTranspose',
            }
            local missing = {}
            for _, c in ipairs(cmds) do
              if vim.fn.exists(':' .. c) ~= 2 then
                table.insert(missing, c)
              end
            end
            return { missing = missing }
            """,
            setup_opts="{ backend = 'lua' }",
        )
        self.assertEqual(result["missing"], [])

    def test_vmsearch_alias_selects_matches(self):
        result = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'foo', 'x foo', 'bar' })
            vim.api.nvim_win_set_cursor(0, { 1, 0 })
            vim.cmd('VMSearch foo')
            local s = require('multi_cursor.state')
            return { total = #s.current().cursors }
            """,
            setup_opts="{ backend = 'lua' }",
        )
        self.assertEqual(result["total"], 1)

    def test_vmsearch_alias_range_percent_selects_all_matches(self):
        result = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'foo', 'x foo', 'bar' })
            vim.cmd('%VMSearch foo')
            local s = require('multi_cursor.state')
            return { total = #s.current().cursors }
            """,
            setup_opts="{ backend = 'lua' }",
        )
        self.assertEqual(result["total"], 2)

    def test_vmfromsearch_alias_selects_matches(self):
        result = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'foo', 'x foo', 'bar' })
            vim.cmd('VMFromSearch foo')
            local s = require('multi_cursor.state')
            return { total = #s.current().cursors }
            """,
            setup_opts="{ backend = 'lua' }",
        )
        self.assertEqual(result["total"], 2)

    def test_vmsearch_bang_uses_search_register_for_next(self):
        result = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'foo', 'x foo', 'bar' })
            vim.fn.setreg('/', 'foo')
            vim.api.nvim_win_set_cursor(0, { 1, 0 })
            vim.cmd('VMSearch!')
            local s = require('multi_cursor.state')
            local st = s.current()
            local p = s.cursor_pos(st, st.current)
            return { total = #st.cursors, row = p and p.row or -1, col = p and p.col or -1 }
            """,
            setup_opts="{ backend = 'lua' }",
        )
        self.assertEqual(result["total"], 1)
        self.assertEqual(result["row"], 1)
        self.assertEqual(result["col"], 2)

    def test_vmtheme_alias_updates_theme(self):
        result = self.run_case(
            """
            vim.cmd('VMTheme iceblue')
            local cfg = require('multi_cursor.config').values
            local hl = vim.api.nvim_get_hl(0, { name = 'MultiCursorCursor', link = false })
            return { theme = cfg.theme, has_bg = hl.bg ~= nil }
            """,
            setup_opts="{ backend = 'lua' }",
        )
        self.assertEqual(result["theme"], "iceblue")
        self.assertTrue(result["has_bg"])

    def test_vmsort_and_vmqfix_aliases_work(self):
        result = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'bbb', 'aaa' })
            vim.api.nvim_win_set_cursor(0, { 1, 0 })
            local a = require('multi_cursor.actions')
            a.add_cursor_vertical(1, 1)
            a.select_operator_with_motion('iw')
            vim.cmd('VMSort')
            vim.cmd('VMQfix!')
            local qf = vim.fn.getqflist()
            return {
              lines = vim.api.nvim_buf_get_lines(0, 0, -1, false),
              qf = #qf,
              has_col = qf[1] and qf[1].col ~= nil,
            }
            """,
            setup_opts="{ backend = 'lua' }",
        )
        self.assertEqual(result["lines"], ["aaa", "bbb"])
        self.assertGreaterEqual(result["qf"], 2)
        self.assertTrue(result["has_col"])

    def test_vmmasstranspose_alias_works(self):
        result = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'foo x bar', 'bar y foo' })
            vim.api.nvim_win_set_cursor(0, { 1, 0 })
            local a = require('multi_cursor.actions')
            a.find_under()
            vim.api.nvim_win_set_cursor(0, { 1, 8 })
            a.add_cursor_at_word(false)
            a.select_operator_with_motion('iw')
            vim.cmd('VMMassTranspose')
            return { lines = vim.api.nvim_buf_get_lines(0, 0, -1, false) }
            """,
            setup_opts="{ backend = 'lua' }",
        )
        self.assertEqual(result["lines"], ["bar x foo", "foo y bar"])

    def test_vmfilterlines_writeback_success(self):
        result = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'alpha', 'beta', 'gamma' })
            local src = vim.api.nvim_get_current_buf()
            local a = require('multi_cursor.actions')
            vim.api.nvim_win_set_cursor(0, { 1, 0 })
            a.add_cursor_at_pos()
            vim.api.nvim_win_set_cursor(0, { 3, 0 })
            a.add_cursor_at_pos()
            vim.cmd('VMFilterLines')
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'ALPHA', 'GAMMA' })
            vim.cmd('write')
            return { lines = vim.api.nvim_buf_get_lines(src, 0, -1, false) }
            """,
            setup_opts="{ backend = 'lua' }",
        )
        self.assertEqual(result["lines"], ["ALPHA", "beta", "GAMMA"])

    def test_vmfilterlines_writeback_mismatch_fails(self):
        result = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'alpha', 'beta', 'gamma' })
            local src = vim.api.nvim_get_current_buf()
            local a = require('multi_cursor.actions')
            vim.api.nvim_win_set_cursor(0, { 1, 0 })
            a.add_cursor_at_pos()
            vim.api.nvim_win_set_cursor(0, { 3, 0 })
            a.add_cursor_at_pos()
            vim.cmd('VMFilterLines')
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'ONLY_ONE' })
            local ok, err = pcall(vim.cmd, 'write')
            return {
              ok = ok,
              err = tostring(err or ''),
              lines = vim.api.nvim_buf_get_lines(src, 0, -1, false),
            }
            """,
            setup_opts="{ backend = 'lua' }",
        )
        self.assertFalse(result["ok"])
        self.assertIn("line count mismatch", result["err"])
        self.assertEqual(result["lines"], ["alpha", "beta", "gamma"])

    def test_vmregionstobuffer_writeback_success(self):
        result = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'foo one', 'bar two' })
            local src = vim.api.nvim_get_current_buf()
            local a = require('multi_cursor.actions')
            vim.api.nvim_win_set_cursor(0, { 1, 0 })
            a.add_cursor_vertical(1, 1)
            a.select_operator_with_motion('iw')
            vim.cmd('VMRegionsToBuffer')
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'FOO', 'BAR' })
            vim.cmd('write')
            return { lines = vim.api.nvim_buf_get_lines(src, 0, -1, false) }
            """,
            setup_opts="{ backend = 'lua' }",
        )
        self.assertEqual(result["lines"], ["FOO one", "BAR two"])

    def test_vmregionstobuffer_writeback_mismatch_fails(self):
        result = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'foo one', 'bar two' })
            local src = vim.api.nvim_get_current_buf()
            local a = require('multi_cursor.actions')
            vim.api.nvim_win_set_cursor(0, { 1, 0 })
            a.add_cursor_vertical(1, 1)
            a.select_operator_with_motion('iw')
            vim.cmd('VMRegionsToBuffer')
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'ONLY_ONE' })
            local ok, err = pcall(vim.cmd, 'write')
            return {
              ok = ok,
              err = tostring(err or ''),
              lines = vim.api.nvim_buf_get_lines(src, 0, -1, false),
            }
            """,
            setup_opts="{ backend = 'lua' }",
        )
        self.assertFalse(result["ok"])
        self.assertIn("line count mismatch", result["err"])
        self.assertEqual(result["lines"], ["foo one", "bar two"])

    def test_add_cursor_vertical(self):
        result = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'a', 'b', 'c' })
            vim.api.nvim_win_set_cursor(0, { 1, 0 })
            local a = require('multi_cursor.actions')
            local s = require('multi_cursor.state')
            a.add_cursor_vertical(1, 2)
            local st = s.current()
            local rows = {}
            local idxs = s.sort_indices_asc(st)
            for _, i in ipairs(idxs) do
              local p = s.cursor_pos(st, i)
              table.insert(rows, p.row)
            end
            return { total = #st.cursors, rows = rows }
            """
        )
        self.assertEqual(result["total"], 3)
        self.assertEqual(result["rows"], [0, 1, 2])

    def test_add_cursor_vertical_skips_empty_and_keeps_target_column(self):
        result = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, {
              '123456',
              '12',
              '',
              '123456',
              '123',
            })
            vim.api.nvim_win_set_cursor(0, { 1, 4 })
            local a = require('multi_cursor.actions')
            local s = require('multi_cursor.state')
            a.add_cursor_vertical(1, 3)
            local st = s.current()
            local out = {}
            for _, i in ipairs(s.sort_indices_asc(st)) do
              local p = s.cursor_pos(st, i)
              if p then
                table.insert(out, { row = p.row, col = p.col })
              end
            end
            return { total = #st.cursors, cursors = out }
            """,
            setup_opts="{ backend = 'lua', skip_shorter_lines = false }",
        )
        self.assertEqual(result["total"], 4)
        self.assertEqual(result["cursors"], [
            {"row": 0, "col": 4},
            {"row": 1, "col": 2},
            {"row": 3, "col": 4},
            {"row": 4, "col": 3},
        ])

    def test_find_under_and_select_all(self):
        result = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'foo x foo', 'foo' })
            vim.api.nvim_win_set_cursor(0, { 1, 0 })
            local a = require('multi_cursor.actions')
            local s = require('multi_cursor.state')
            a.find_under()
            a.select_all()
            local st = s.current()
            return { total = #st.cursors }
            """
        )
        self.assertEqual(result["total"], 3)

    def test_regex_find_adds_cursor(self):
        result = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'alpha 123', 'beta 456' })
            vim.api.nvim_win_set_cursor(0, { 1, 0 })
            local a = require('multi_cursor.actions')
            local s = require('multi_cursor.state')
            local ok = a.find_by_regex([[\\d\\+]], { select_all = false })
            local st = s.current()
            local p = s.cursor_pos(st, st.current)
            return { ok = ok, total = #st.cursors, row = p and p.row or -1, col = p and p.col or -1 }
            """
        )
        self.assertTrue(result["ok"])
        self.assertEqual(result["total"], 1)
        self.assertEqual(result["row"], 0)
        self.assertEqual(result["col"], 6)

    def test_regex_find_all_selects_all_matches(self):
        result = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'x1 x2', 'x3' })
            vim.api.nvim_win_set_cursor(0, { 1, 0 })
            local a = require('multi_cursor.actions')
            local s = require('multi_cursor.state')
            local ok = a.find_by_regex([[x\\d]], { select_all = true })
            local st = s.current()
            return { ok = ok, total = #st.cursors }
            """
        )
        self.assertTrue(result["ok"])
        self.assertEqual(result["total"], 3)

    def test_visual_regex_selects_in_visual_range(self):
        result = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'aa 11', 'bb 22', 'cc 33' })
            vim.fn.setpos("'<", { 0, 1, 1, 0 })
            vim.fn.setpos("'>", { 0, 2, 6, 0 })
            local a = require('multi_cursor.actions')
            local s = require('multi_cursor.state')
            local ok = a.find_visual_by_regex([[\\d\\+]], { select_all = true })
            local st = s.current()
            return { ok = ok, total = #st.cursors }
            """
        )
        self.assertTrue(result["ok"])
        self.assertEqual(result["total"], 2)

    def test_visual_cursors(self):
        result = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'aa', 'bb', 'cc' })
            vim.fn.setpos("'<", { 0, 1, 2, 0 })
            vim.fn.setpos("'>", { 0, 3, 2, 0 })
            local a = require('multi_cursor.actions')
            local s = require('multi_cursor.state')
            local ok = a.visual_cursors()
            local st = s.current()
            return { ok = ok, total = #st.cursors }
            """
        )
        self.assertTrue(result["ok"])
        self.assertEqual(result["total"], 3)

    def test_regex_empty_pattern_aborts(self):
        result = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'abc' })
            vim.api.nvim_win_set_cursor(0, { 1, 0 })
            local a = require('multi_cursor.actions')
            local s = require('multi_cursor.state')
            local ok = a.find_by_regex('', { select_all = false })
            local st = s.current()
            return { ok = ok, total = #st.cursors }
            """
        )
        self.assertFalse(result["ok"])
        self.assertEqual(result["total"], 0)

    def test_toggle_extend_and_shift_selection(self):
        result = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'abcd' })
            vim.api.nvim_win_set_cursor(0, { 1, 1 })
            local a = require('multi_cursor.actions')
            local s = require('multi_cursor.state')
            a.add_cursor_at_pos()
            a.toggle_mode()
            a.shift_selection(1)
            local st = s.current()
            local p = s.cursor_pos(st, st.current)
            return {
              mode = st.mode,
              col = p.col,
              acol = p.acol,
            }
            """
        )
        self.assertEqual(result["mode"], "extend")
        self.assertNotEqual(result["col"], result["acol"])

    def test_apply_normal_across_cursors(self):
        result = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'abc', 'abc' })
            vim.api.nvim_win_set_cursor(0, { 1, 0 })
            local a = require('multi_cursor.actions')
            a.add_cursor_vertical(1, 1)
            a.apply_normal('rX', false)
            return { lines = vim.api.nvim_buf_get_lines(0, 0, -1, false) }
            """
        )
        self.assertEqual(result["lines"], ["Xbc", "Xbc"])

    def test_normal_key_passthrough_uses_custom_mapping(self):
        result = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { '  abc', '  def' })
            vim.api.nvim_win_set_cursor(0, { 1, 3 })
            vim.cmd('normal C')
            vim.cmd('normal gh')
            local s = require('multi_cursor.state')
            local st = s.current()
            local cols = {}
            local idxs = s.sort_indices_asc(st)
            for _, i in ipairs(idxs) do
              local p = s.cursor_pos(st, i)
              table.insert(cols, p.col)
            end
            return { cols = cols }
            """,
            setup_opts=(
                "{ backend = 'lua', mappings = { add_cursor_down = 'C' }, "
                "enable_normal_key_passthrough = true, normal_keys = { 'gh' } }"
            ),
            pre_setup_lua="vim.keymap.set('n', 'gh', '0', { noremap = true, silent = true })",
        )
        self.assertEqual(result["cols"], [0, 0])

    def test_custom_noremaps_apply_across_cursors(self):
        result = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { '  abc', '  def' })
            vim.api.nvim_win_set_cursor(0, { 1, 3 })
            vim.cmd('normal C')
            vim.cmd('normal H')
            local s = require('multi_cursor.state')
            local st = s.current()
            local cols = {}
            for _, i in ipairs(s.sort_indices_asc(st)) do
              local p = s.cursor_pos(st, i)
              table.insert(cols, p.col)
            end
            return { cols = cols }
            """,
            setup_opts=(
                "{ backend = 'lua', mappings = { add_cursor_down = 'C' }, "
                "custom_noremaps = { H = '0' }, enable_normal_key_passthrough = false }"
            ),
        )
        self.assertEqual(result["cols"], [0, 0])

    def test_custom_remaps_apply_across_cursors(self):
        result = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { '  abc', '  def' })
            vim.api.nvim_win_set_cursor(0, { 1, 3 })
            vim.cmd('normal C')
            vim.cmd('normal H')
            local s = require('multi_cursor.state')
            local st = s.current()
            local cols = {}
            for _, i in ipairs(s.sort_indices_asc(st)) do
              local p = s.cursor_pos(st, i)
              table.insert(cols, p.col)
            end
            return { cols = cols }
            """,
            setup_opts=(
                "{ backend = 'lua', mappings = { add_cursor_down = 'C' }, "
                "custom_remaps = { H = 'gH' }, enable_normal_key_passthrough = false }"
            ),
            pre_setup_lua="vim.keymap.set('n', 'gH', '0', { noremap = true, silent = true })",
        )
        self.assertEqual(result["cols"], [0, 0])

    def test_custom_commands_run_when_active(self):
        result = self.run_case(
            """
            vim.g.mc_cmd_hit = 0
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'abc', 'def' })
            vim.api.nvim_win_set_cursor(0, { 1, 0 })
            vim.cmd('normal C')
            vim.cmd('normal Z')
            return { hit = vim.g.mc_cmd_hit }
            """,
            setup_opts=(
                "{ backend = 'lua', mappings = { add_cursor_down = 'C' }, "
                "custom_commands = { Z = ':let g:mc_cmd_hit = g:mc_cmd_hit + 1<CR>' }, "
                "enable_normal_key_passthrough = false }"
            ),
        )
        self.assertEqual(result["hit"], 1)

    def test_custom_motions_extend_passthrough_keys(self):
        result = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { '  abc', '  def' })
            vim.api.nvim_win_set_cursor(0, { 1, 3 })
            vim.cmd('normal C')
            vim.cmd('normal gh')
            local s = require('multi_cursor.state')
            local st = s.current()
            local cols = {}
            for _, i in ipairs(s.sort_indices_asc(st)) do
              local p = s.cursor_pos(st, i)
              table.insert(cols, p.col)
            end
            return { cols = cols }
            """,
            setup_opts=(
                "{ backend = 'lua', mappings = { add_cursor_down = 'C' }, "
                "custom_motions = { gh = 'BOL' }, enable_normal_key_passthrough = true, "
                "normal_keys = {} }"
            ),
            pre_setup_lua="vim.keymap.set('n', 'gh', '0', { noremap = true, silent = true })",
        )
        self.assertEqual(result["cols"], [0, 0])

    def test_vm_custom_globals_import(self):
        result = self.run_case(
            """
            local cfg = require('multi_cursor.config').values
            return {
              nr = cfg.custom_noremaps.H,
              rr = cfg.custom_remaps.H,
              cc = cfg.custom_commands.Z,
              cm = cfg.custom_motions.gh,
            }
            """,
            pre_setup_lua=(
                "vim.g.VM_custom_noremaps = { H = '0' }\n"
                "vim.g.VM_custom_remaps = { H = 'gH' }\n"
                "vim.g.VM_custom_commands = { Z = ':echo \"ok\"<CR>' }\n"
                "vim.g.VM_custom_motions = { gh = 'BOL' }"
            ),
        )
        self.assertEqual(result["nr"], "0")
        self.assertEqual(result["rr"], "gH")
        self.assertEqual(result["cc"], ':echo "ok"<CR>')
        self.assertEqual(result["cm"], "BOL")

    def test_vm_map_alias_applies(self):
        result = self.run_case(
            """
            local map = vim.fn.maparg('C', 'n', false, true)
            return { has = type(map) == 'table' and map.lhs == 'C' }
            """,
            setup_opts="{ backend = 'lua', vm_maps = { ['Add Cursor Down'] = 'C' } }",
        )
        self.assertTrue(result["has"])

    def test_search_menu_mapping_works_when_not_active(self):
        result = self.run_case(
            """
            local map = vim.fn.maparg('\\\\mp', 'n', false, true)
            return { has_callback = type(map) == 'table' and type(map.callback) == 'function' }
            """,
            setup_opts="{ backend = 'lua', mappings = { search_menu = '<leader>mp' } }",
        )
        self.assertTrue(result["has_callback"])

    def test_add_cursor_at_pos_mapping_not_shadowed_by_align(self):
        result = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'abc' })
            vim.api.nvim_win_set_cursor(0, { 1, 0 })
            vim.cmd('normal \\\\ma')
            local s = require('multi_cursor.state')
            local st = s.current()
            return { total = #st.cursors, enabled = st.enabled }
            """,
            setup_opts="{ backend = 'lua', mappings = { add_cursor_at_pos = '<leader>ma' } }",
        )
        self.assertEqual(result["total"], 1)
        self.assertTrue(result["enabled"])

    def test_operator_prompt_honors_remapped_gl_motion(self):
        result = self.run_case(
            """
            vim.keymap.set({ 'n', 'v', 'o', 'x' }, 'gl', '$', { noremap = true, silent = true })
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'abcXYZ', 'defUVW' })
            vim.api.nvim_win_set_cursor(0, { 1, 0 })
            local a = require('multi_cursor.actions')
            a.add_cursor_vertical(1, 1)
            a.operator_with_motion('d', 'gl')
            return { lines = vim.api.nvim_buf_get_lines(0, 0, -1, false) }
            """,
            setup_opts="{ backend = 'lua', mappings = { add_cursor_down = 'C' } }",
        )
        self.assertEqual(result["lines"], ["", ""])

    def test_mapping_list_supports_multiple_lhs_for_same_action(self):
        result = self.run_case(
            """
            local cfg = require('multi_cursor.config').values
            local map_c = vim.fn.maparg('C', 'n', false, true)
            local map_l = vim.fn.maparg('\\\\mj', 'n', false, true)
            return {
              add_down_type = type(cfg.mappings.add_cursor_down),
              add_down_count = type(cfg.mappings.add_cursor_down) == 'table' and #cfg.mappings.add_cursor_down or 0,
              has_c = type(map_c) == 'table' and map_c.lhs == 'C',
              has_l = type(map_l) == 'table' and type(map_l.callback) == 'function',
            }
            """,
            setup_opts=(
                "{ backend = 'lua', mappings = { add_cursor_down = { '<leader>mj', 'C' } } }"
            ),
        )
        self.assertEqual(result["add_down_type"], "table")
        self.assertEqual(result["add_down_count"], 2)
        self.assertTrue(result["has_c"])
        self.assertTrue(result["has_l"])

    def test_add_cursor_down_mapping_list_overrides_change_to_eol_c(self):
        result = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'abc', 'def' })
            vim.api.nvim_win_set_cursor(0, { 1, 0 })
            vim.cmd('normal C')
            local s = require('multi_cursor.state')
            local st = s.current()
            return { total = #st.cursors, mode = st.mode }
            """,
            setup_opts=(
                "{ backend = 'lua', mappings = { add_cursor_down = { '<leader>mj', 'C' } } }"
            ),
        )
        self.assertEqual(result["total"], 2)
        self.assertEqual(result["mode"], "cursor")

    def test_vm_map_alias_allows_disabling_with_empty_string(self):
        result = self.run_case(
            """
            local cfg = require('multi_cursor.config').values
            return {
              select_op = cfg.mappings.select_operator,
              find_under = cfg.mappings.find_under,
            }
            """,
            setup_opts=("{ backend = 'lua', vm_maps = { ['Select Operator'] = '', ['Find Under'] = '' } }"),
        )
        self.assertEqual(result["select_op"], "")
        self.assertEqual(result["find_under"], "")

    def test_check_mappings_skips_conflicting_buffer_map(self):
        result = self.run_case(
            """
            local lhs = 'Zz'
            local global_has = false
            for _, m in ipairs(vim.api.nvim_get_keymap('n')) do
              if m.lhs == lhs then
                global_has = true
                break
              end
            end
            local bm = vim.fn.maparg(lhs, 'n', false, true)
            return {
              global_has = global_has,
              buffer_has = type(bm) == 'table' and bm.buffer == 1 and bm.lhs == lhs,
            }
            """,
            setup_opts=("{ backend = 'lua', check_mappings = true, mappings = { find_next = 'Zz' } }"),
            pre_setup_lua="vim.keymap.set('n', 'Zz', 'w', { buffer = 0, noremap = true })",
        )
        self.assertFalse(result["global_has"])
        self.assertTrue(result["buffer_has"])

    def test_force_maps_allows_overriding_conflicting_buffer_map(self):
        result = self.run_case(
            """
            local lhs = 'Zy'
            local global_has = false
            for _, m in ipairs(vim.api.nvim_get_keymap('n')) do
              if m.lhs == lhs then
                global_has = true
                break
              end
            end
            return { global_has = global_has }
            """,
            setup_opts=(
                "{ backend = 'lua', check_mappings = true, force_maps = { 'Zy' }, mappings = { find_next = 'Zy' } }"
            ),
            pre_setup_lua="vim.keymap.set('n', 'Zy', 'w', { buffer = 0, noremap = true })",
        )
        self.assertTrue(result["global_has"])

    def test_vm_check_and_force_maps_globals(self):
        result = self.run_case(
            """
            local cfg = require('multi_cursor.config').values
            return {
              check = cfg.check_mappings,
              forced = cfg.force_maps[1],
            }
            """,
            setup_opts="{ backend = 'lua' }",
            pre_setup_lua="vim.g.VM_check_mappings = 0; vim.g.VM_force_maps = { '<leader>zz' }",
        )
        self.assertFalse(result["check"])
        self.assertEqual(result["forced"], "<leader>zz")

    def test_empty_custom_mappings_do_not_crash_setup(self):
        result = self.run_case(
            """
            local maps = require('multi_cursor.config').values.mappings
            return {
              add_cursor_down = maps.add_cursor_down,
              visual_all = maps.visual_all,
              replace_chars = maps.replace_chars,
            }
            """,
            setup_opts=(
                "{ backend = 'lua', mappings = { add_cursor_down = '', add_cursor_at_pos = '', "
                "visual_all = '', visual_find = '', visual_regex = '', visual_cursors = '', "
                "replace_chars = '' } }"
            ),
        )
        self.assertEqual(result["add_cursor_down"], "")
        self.assertEqual(result["visual_all"], "")
        self.assertEqual(result["replace_chars"], "")

    def test_vm_map_alias_numbers_direction(self):
        result = self.run_case(
            """
            local cfg = require('multi_cursor.config').values
            return {
              numbers = cfg.mappings.numbers_prepend,
              numbers_append = cfg.mappings.numbers_append,
            }
            """,
            setup_opts=(
                "{ backend = 'lua', vm_maps = { ['Numbers'] = '<leader>mN', ['Numbers Append'] = '<leader>mn' } }"
            ),
        )
        self.assertEqual(result["numbers"], "<leader>mN")
        self.assertEqual(result["numbers_append"], "<leader>mn")

    def test_vm_map_alias_operator_keys(self):
        result = self.run_case(
            """
            local cfg = require('multi_cursor.config').values
            return {
              select = cfg.mappings.select_operator,
              find = cfg.mappings.find_operator,
            }
            """,
            setup_opts=("{ backend = 'lua', vm_maps = { ['Select Operator'] = 'S', ['Find Operator'] = 'M' } }"),
        )
        self.assertEqual(result["select"], "S")
        self.assertEqual(result["find"], "M")

    def test_vm_map_alias_zero_numbers_and_visual_keys(self):
        result = self.run_case(
            """
            local cfg = require('multi_cursor.config').values
            return {
              zn = cfg.mappings.numbers_zero_prepend,
              zna = cfg.mappings.numbers_zero_append,
              vall = cfg.mappings.visual_all,
              vfind = cfg.mappings.visual_find,
              rempty = cfg.mappings.remove_empty_lines,
            }
            """,
            setup_opts=(
                "{ backend = 'lua', vm_maps = { ['Zero Numbers'] = '<leader>m0N', "
                "['Zero Numbers Append'] = '<leader>m0n', ['Visual All'] = '<leader>mA', "
                "['Visual Find'] = '<leader>mf', ['Remove Empty Lines'] = '<leader>mrl' } }"
            ),
        )
        self.assertEqual(result["zn"], "<leader>m0N")
        self.assertEqual(result["zna"], "<leader>m0n")
        self.assertEqual(result["vall"], "<leader>mA")
        self.assertEqual(result["vfind"], "<leader>mf")
        self.assertEqual(result["rempty"], "<leader>mrl")

    def test_vm_map_alias_run_last_and_mode_keys(self):
        result = self.run_case(
            """
            local cfg = require('multi_cursor.config').values
            return {
              rln = cfg.mappings.run_last_normal,
              rlv = cfg.mappings.run_last_visual,
              rlx = cfg.mappings.run_last_ex,
              rdot = cfg.mappings.run_dot,
              sw = cfg.mappings.toggle_mode,
              cset = cfg.mappings.case_setting,
              merge = cfg.mappings.merge_regions,
              sm = cfg.mappings.search_menu,
              tm = cfg.mappings.tools_menu,
              regs = cfg.mappings.show_registers,
              rew = cfg.mappings.rewrite_last_search,
              scd = cfg.mappings.add_cursor_down,
              scu = cfg.mappings.add_cursor_up,
              delop = cfg.mappings.delete_operator,
              yankop = cfg.mappings.yank_operator,
              ml = cfg.mappings.shift_left,
              mr = cfg.mappings.shift_right,
              pa = cfg.mappings.paste_after,
              pb = cfg.mappings.paste_before,
              sj = cfg.mappings.select_j,
              sk = cfg.mappings.select_k,
              sww = cfg.mappings.select_w,
              sb = cfg.mappings.select_b,
              se = cfg.mappings.select_e,
              sge = cfg.mappings.select_ge,
              sE = cfg.mappings.select_E,
              sbbw = cfg.mappings.select_BBW,
              ssh = cfg.mappings.single_select_h,
              ssl = cfg.mappings.single_select_l,
              ld = cfg.mappings.line_delete,
              ly = cfg.mappings.line_yank,
              dx = cfg.mappings.delete_char,
              dX = cfg.mappings.delete_char_before,
              jn = cfg.mappings.join_lines,
              swp = cfg.mappings.swap_case,
              rep = cfg.mappings.repeat_substitute,
              dkey = cfg.mappings.delete_key,
              dot = cfg.mappings.dot,
              inc = cfg.mappings.increase,
              dec = cfg.mappings.decrease,
              ginc = cfg.mappings.gincrease,
              gdec = cfg.mappings.gdecrease,
              ainc = cfg.mappings.alpha_increase,
              adec = cfg.mappings.alpha_decrease,
              insi = cfg.mappings.insert_insert,
              insa = cfg.mappings.insert_append,
              insI = cfg.mappings.insert_insert_sol,
              insA = cfg.mappings.insert_append_eol,
              opn = cfg.mappings.open_below,
              opN = cfg.mappings.open_above,
              cm = cfg.mappings.comment_operator,
              low = cfg.mappings.lower_operator,
              up = cfg.mappings.upper_operator,
              cE = cfg.mappings.change_to_eol,
              rc = cfg.mappings.replace_chars,
              rm = cfg.mappings.replace_mode,
              surr = cfg.mappings.surround,
              shr = cfg.mappings.shrink,
              enl = cfg.mappings.enlarge,
              iarw = cfg.mappings.i_arrow_w,
              iret = cfg.mappings.i_return,
              ica = cfg.mappings.i_ctrl_a,
              ice = cfg.mappings.i_ctrl_e,
              ipa = cfg.mappings.i_paste,
            }
            """,
            setup_opts=(
                "{ backend = 'lua', vm_maps = { ['Run Last Normal'] = '<leader>mZ', "
                "['Run Last Visual'] = '<leader>mV', ['Run Last Ex'] = '<leader>mX', "
                "['Run Dot'] = '<leader>m.', ['Switch Mode'] = '<Tab>', "
                "['Case Setting'] = '<leader>mc', ['Merge Regions'] = '<leader>mm', "
                "['Search Menu'] = '<leader>mS', ['Tools Menu'] = '<leader>m`', "
                "['Show Registers'] = '<leader>m\"', ['Rewrite Last Search'] = '<leader>mr', "
                "['Select Cursor Down'] = 'J', ['Select Cursor Up'] = 'K', "
                "['Delete'] = 'X', ['Yank'] = 'Y', ['Move Left'] = 'H', ['Move Right'] = 'L', "
                "['p Paste'] = 'gp', ['P Paste'] = 'gP', ['Select j'] = '<leader>mj', "
                "['Select k'] = '<leader>mk', ['Select w'] = '<leader>mw', "
                "['Select b'] = '<leader>mb', ['Select e'] = '<leader>me', "
                "['Select ge'] = '<leader>mge', ['Select E'] = '<leader>mE', "
                "['Select BBW'] = '<leader>mB', ['Single Select h'] = '<leader>msh', "
                "['Single Select l'] = '<leader>msl', ['D'] = 'gD', ['Y'] = 'gY', "
                "['x'] = 'gx', ['X'] = 'gX', ['J'] = 'gJ', ['~'] = 'g~', ['&'] = 'g&', "
                "['Del'] = '<BS>', ['Dot'] = 'g.', ['Increase'] = '+', ['Decrease'] = '-', "
                "['gIncrease'] = 'g+', ['gDecrease'] = 'g-', ['Alpha Increase'] = '<leader>m+', "
                "['Alpha Decrease'] = '<leader>m-', ['i'] = 'gi', ['a'] = 'ga', ['I'] = 'gI', "
                "['A'] = 'gA', ['o'] = 'go', ['O'] = 'gO', ['gc'] = '<leader>mgc', "
                "['gu'] = '<leader>mgu', ['gU'] = '<leader>mgU', ['C'] = 'gC', "
                "['Replace Characters'] = 'gr', ['Replace'] = 'gR', ['Surround'] = 'gS', "
                "['Shrink'] = '<leader>m-', ['Enlarge'] = '<leader>m+', "
                "['I Arrow w'] = '<A-l>', ['I Return'] = '<A-CR>', ['I CtrlA'] = '<A-a>', "
                "['I CtrlE'] = '<A-e>', ['I Paste'] = '<A-v>' } }"
            ),
        )
        self.assertEqual(result["rln"], "<leader>mZ")
        self.assertEqual(result["rlv"], "<leader>mV")
        self.assertEqual(result["rlx"], "<leader>mX")
        self.assertEqual(result["rdot"], "<leader>m.")
        self.assertEqual(result["sw"], "<Tab>")
        self.assertEqual(result["cset"], "<leader>mc")
        self.assertEqual(result["merge"], "<leader>mm")
        self.assertEqual(result["sm"], "<leader>mS")
        self.assertEqual(result["tm"], "<leader>m`")
        self.assertEqual(result["regs"], '<leader>m"')
        self.assertEqual(result["rew"], "<leader>mr")
        self.assertEqual(result["scd"], "J")
        self.assertEqual(result["scu"], "K")
        self.assertEqual(result["delop"], "X")
        self.assertEqual(result["yankop"], "Y")
        self.assertEqual(result["ml"], "H")
        self.assertEqual(result["mr"], "L")
        self.assertEqual(result["pa"], "gp")
        self.assertEqual(result["pb"], "gP")
        self.assertEqual(result["sj"], "<leader>mj")
        self.assertEqual(result["sk"], "<leader>mk")
        self.assertEqual(result["sww"], "<leader>mw")
        self.assertEqual(result["sb"], "<leader>mb")
        self.assertEqual(result["se"], "<leader>me")
        self.assertEqual(result["sge"], "<leader>mge")
        self.assertEqual(result["sE"], "<leader>mE")
        self.assertEqual(result["sbbw"], "<leader>mB")
        self.assertEqual(result["ssh"], "<leader>msh")
        self.assertEqual(result["ssl"], "<leader>msl")
        self.assertEqual(result["ld"], "gD")
        self.assertEqual(result["ly"], "gY")
        self.assertEqual(result["dx"], "gx")
        self.assertEqual(result["dX"], "gX")
        self.assertEqual(result["jn"], "gJ")
        self.assertEqual(result["swp"], "g~")
        self.assertEqual(result["rep"], "g&")
        self.assertEqual(result["dkey"], "<BS>")
        self.assertEqual(result["dot"], "g.")
        self.assertEqual(result["inc"], "+")
        self.assertEqual(result["dec"], "-")
        self.assertEqual(result["ginc"], "g+")
        self.assertEqual(result["gdec"], "g-")
        self.assertEqual(result["ainc"], "<leader>m+")
        self.assertEqual(result["adec"], "<leader>m-")
        self.assertEqual(result["insi"], "gi")
        self.assertEqual(result["insa"], "ga")
        self.assertEqual(result["insI"], "gI")
        self.assertEqual(result["insA"], "gA")
        self.assertEqual(result["opn"], "go")
        self.assertEqual(result["opN"], "gO")
        self.assertEqual(result["cm"], "<leader>mgc")
        self.assertEqual(result["low"], "<leader>mgu")
        self.assertEqual(result["up"], "<leader>mgU")
        self.assertEqual(result["cE"], "gC")
        self.assertEqual(result["rc"], "gr")
        self.assertEqual(result["rm"], "gR")
        self.assertEqual(result["surr"], "gS")
        self.assertEqual(result["shr"], "<leader>m-")
        self.assertEqual(result["enl"], "<leader>m+")
        self.assertEqual(result["iarw"], "<A-l>")
        self.assertEqual(result["iret"], "<A-CR>")
        self.assertEqual(result["ica"], "<A-a>")
        self.assertEqual(result["ice"], "<A-e>")
        self.assertEqual(result["ipa"], "<A-v>")

    def test_vm_insert_special_keys_globals(self):
        result = self.run_case(
            """
            local cfg = require('multi_cursor.config').values
            return {
              a = cfg.mappings.i_ctrl_a,
              e = cfg.mappings.i_ctrl_e,
              v = cfg.mappings.i_paste,
            }
            """,
            setup_opts="{ backend = 'lua' }",
            pre_setup_lua="vim.g.VM_insert_special_keys = { 'c-a', 'c-e', 'c-v' }",
        )
        self.assertEqual(result["a"], "<C-a>")
        self.assertEqual(result["e"], "<C-e>")
        self.assertEqual(result["v"], "<C-v>")

    def test_vm_default_mappings_global(self):
        result = self.run_case(
            """
            local cfg = require('multi_cursor.config').values
            return {
              find_under = cfg.mappings.find_under,
              add_down = cfg.mappings.add_cursor_down,
              select_all = cfg.mappings.select_all,
              visual_all = cfg.mappings.visual_all,
              clear = cfg.mappings.clear,
            }
            """,
            setup_opts="{ backend = 'lua' }",
            pre_setup_lua="vim.g.VM_default_mappings = 0",
        )
        self.assertEqual(result["find_under"], "")
        self.assertEqual(result["add_down"], "")
        self.assertEqual(result["select_all"], "")
        self.assertEqual(result["visual_all"], "")
        self.assertEqual(result["clear"], "")

    def test_vm_default_mappings_allows_explicit_vm_maps_override(self):
        result = self.run_case(
            """
            local cfg = require('multi_cursor.config').values
            return {
              add_down = cfg.mappings.add_cursor_down,
              select_all = cfg.mappings.select_all,
            }
            """,
            setup_opts="{ backend = 'lua' }",
            pre_setup_lua=(
                "vim.g.VM_default_mappings = 0\n"
                "vim.g.VM_maps = { ['Add Cursor Down'] = 'C', ['Select All'] = '<leader>a' }"
            ),
        )
        self.assertEqual(result["add_down"], "C")
        self.assertEqual(result["select_all"], "<leader>a")

    def test_vm_leader_string_global_applies_to_default_and_buffer_mappings(self):
        result = self.run_case(
            """
            local cfg = require('multi_cursor.config').values
            return {
              select_all = cfg.mappings.select_all,
              toggle = cfg.mappings.toggle_mappings,
              add_pos = cfg.mappings.add_cursor_at_pos,
              visual_all = cfg.mappings.visual_all,
            }
            """,
            setup_opts="{ backend = 'lua' }",
            pre_setup_lua="vim.g.VM_leader = '<leader>m'",
        )
        self.assertEqual(result["select_all"], "<leader>mA")
        self.assertEqual(result["toggle"], "<leader>m<Space>")
        self.assertEqual(result["add_pos"], "<leader>m\\")
        self.assertEqual(result["visual_all"], "<leader>mA")

    def test_vm_leader_dict_global_applies_per_scope(self):
        result = self.run_case(
            """
            local cfg = require('multi_cursor.config').values
            return {
              select_all = cfg.mappings.select_all,
              toggle = cfg.mappings.toggle_mappings,
              visual_all = cfg.mappings.visual_all,
            }
            """,
            setup_opts="{ backend = 'lua' }",
            pre_setup_lua="vim.g.VM_leader = { default = '<leader>d', visual = '<leader>v', buffer = '<leader>b' }",
        )
        self.assertEqual(result["select_all"], "<leader>dA")
        self.assertEqual(result["toggle"], "<leader>b<Space>")
        self.assertEqual(result["visual_all"], "<leader>vA")

    def test_vm_leader_does_not_override_explicit_mappings(self):
        result = self.run_case(
            """
            local cfg = require('multi_cursor.config').values
            return {
              select_all = cfg.mappings.select_all,
              toggle = cfg.mappings.toggle_mappings,
            }
            """,
            setup_opts="{ backend = 'lua', mappings = { select_all = '\\\\A', toggle_mappings = '\\\\<Space>' } }",
            pre_setup_lua="vim.g.VM_leader = '<leader>m'",
        )
        self.assertEqual(result["select_all"], "\\A")
        self.assertEqual(result["toggle"], "\\<Space>")

    def test_multicursor_leader_alias_applies_leader_mappings(self):
        result = self.run_case(
            """
            local cfg = require('multi_cursor.config').values
            return {
              select_all = cfg.mappings.select_all,
              toggle = cfg.mappings.toggle_mappings,
              mode = cfg.mappings.toggle_mode,
            }
            """,
            setup_opts="{ backend = 'lua', multicursor_leader = '<leader>m' }",
        )
        self.assertEqual(result["select_all"], "<leader>mA")
        self.assertEqual(result["toggle"], "<leader>m<Space>")
        self.assertEqual(result["mode"], "<leader>m<Tab>")

    def test_default_mappings_false_has_tab_toggle_mode_fallback(self):
        result = self.run_case(
            """
            local map = vim.fn.maparg('<Tab>', 'n', false, true)
            local has_cb = type(map) == 'table' and type(map.callback) == 'function'
            return { has_cb = has_cb, desc = map.desc or '' }
            """,
            setup_opts="{ backend = 'lua', default_mappings = false }",
        )
        self.assertTrue(result["has_cb"])

    def test_default_mappings_false_has_core_operator_and_paste_fallbacks(self):
        result = self.run_case(
            """
            local y = vim.fn.maparg('y', 'n', false, true)
            local d = vim.fn.maparg('d', 'n', false, true)
            local c = vim.fn.maparg('c', 'n', false, true)
            local p = vim.fn.maparg('p', 'n', false, true)
            local P = vim.fn.maparg('P', 'n', false, true)
            local function has_cb(m)
              return type(m) == 'table' and type(m.callback) == 'function'
            end
            return { y = has_cb(y), d = has_cb(d), c = has_cb(c), p = has_cb(p), P = has_cb(P) }
            """,
            setup_opts="{ backend = 'lua', default_mappings = false }",
        )
        self.assertTrue(result["y"])
        self.assertTrue(result["d"])
        self.assertTrue(result["c"])
        self.assertTrue(result["p"])
        self.assertTrue(result["P"])

    def test_vm_mouse_mappings_global(self):
        result = self.run_case(
            """
            local cfg = require('multi_cursor.config').values
            local mc = vim.fn.maparg('<C-LeftMouse>', 'n', false, true)
            local mw = vim.fn.maparg('<C-RightMouse>', 'n', false, true)
            local mcol = vim.fn.maparg('<M-C-RightMouse>', 'n', false, true)
            return {
              cursor = cfg.mappings.mouse_cursor,
              word = cfg.mappings.mouse_word,
              column = cfg.mappings.mouse_column,
              has_cursor = type(mc) == 'table' and mc.lhs == '<C-LeftMouse>',
              has_word = type(mw) == 'table' and mw.lhs == '<C-RightMouse>',
              has_column = type(mcol) == 'table' and mcol.lhs == '<M-C-RightMouse>',
            }
            """,
            setup_opts="{ backend = 'lua' }",
            pre_setup_lua="vim.g.VM_mouse_mappings = 1",
        )
        self.assertEqual(result["cursor"], "<C-LeftMouse>")
        self.assertEqual(result["word"], "<C-RightMouse>")
        self.assertEqual(result["column"], "<M-C-RightMouse>")
        self.assertTrue(result["has_cursor"])
        self.assertTrue(result["has_word"])
        self.assertTrue(result["has_column"])

    def test_vm_user_operators_global_parsing(self):
        result = self.run_case(
            """
            local cfg = require('multi_cursor.config').values
            return {
              total = #cfg.user_operators,
              first = cfg.user_operators[1],
              second = cfg.user_operators[2],
            }
            """,
            setup_opts="{ backend = 'lua' }",
            pre_setup_lua="vim.g.VM_user_operators = { 'yz', { ['cx'] = 2 } }",
        )
        self.assertEqual(result["total"], 2)
        self.assertEqual(result["first"], "yz")
        self.assertEqual(result["second"], "cx")

    def test_vm_skip_empty_lines_global(self):
        result = self.run_case(
            """
            local cfg = require('multi_cursor.config').values
            return { skip_empty = cfg.skip_empty_lines }
            """,
            setup_opts="{ backend = 'lua' }",
            pre_setup_lua="vim.g.VM_skip_empty_lines = 1",
        )
        self.assertTrue(result["skip_empty"])

    def test_use_first_cursor_in_line_insert_option(self):
        result = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'abcdef' })
            vim.api.nvim_win_set_cursor(0, { 1, 5 })
            local a = require('multi_cursor.actions')
            local s = require('multi_cursor.state')
            a.add_cursor_at_pos()
            vim.api.nvim_win_set_cursor(0, { 1, 1 })
            a.add_cursor_at_pos()
            local st = s.current()
            st.current = 1
            a.begin_insert('insert')
            local cp = s.cursor_pos(st, st.current)
            a.end_insert()
            return { col = cp and cp.col or -1 }
            """,
            setup_opts="{ backend = 'lua', insert_mode = 'native', use_first_cursor_in_line = true }",
        )
        self.assertEqual(result["col"], 1)

    def test_vm_use_first_cursor_in_line_global(self):
        result = self.run_case(
            """
            local cfg = require('multi_cursor.config').values
            return { first = cfg.use_first_cursor_in_line }
            """,
            setup_opts="{ backend = 'lua' }",
            pre_setup_lua="vim.g.VM_use_first_cursor_in_line = 1",
        )
        self.assertTrue(result["first"])

    def test_vm_quit_after_leaving_insert_mode_global(self):
        result = self.run_case(
            """
            local cfg = require('multi_cursor.config').values
            return { quit = cfg.quit_after_leaving_insert_mode }
            """,
            setup_opts="{ backend = 'lua' }",
            pre_setup_lua="vim.g.VM_quit_after_leaving_insert_mode = 1",
        )
        self.assertTrue(result["quit"])

    def test_vm_reindent_filetypes_global(self):
        result = self.run_case(
            """
            local cfg = require('multi_cursor.config').values
            return { ft = cfg.reindent_filetypes[1] }
            """,
            setup_opts="{ backend = 'lua' }",
            pre_setup_lua="vim.g.VM_reindent_filetypes = { 'lua' }",
        )
        self.assertEqual(result["ft"], "lua")

    def test_vm_disable_syntax_in_imode_global(self):
        result = self.run_case(
            """
            local cfg = require('multi_cursor.config').values
            return { off = cfg.disable_syntax_in_imode }
            """,
            setup_opts="{ backend = 'lua' }",
            pre_setup_lua="vim.g.VM_disable_syntax_in_imode = 1",
        )
        self.assertTrue(result["off"])

    def test_vm_statusline_and_message_globals(self):
        result = self.run_case(
            """
            local cfg = require('multi_cursor.config').values
            return {
              st = cfg.set_statusline,
              silent = cfg.silent_exit,
              warn = cfg.show_warnings,
              verbose = cfg.verbose_commands,
              recursive = cfg.recursive_operations_at_cursors,
            }
            """,
            setup_opts="{ backend = 'lua' }",
            pre_setup_lua=(
                "vim.g.VM_set_statusline = 3\n"
                "vim.g.VM_silent_exit = 1\n"
                "vim.g.VM_show_warnings = 0\n"
                "vim.g.VM_verbose_commands = 1\n"
                "vim.g.VM_recursive_operations_at_cursors = 0"
            ),
        )
        self.assertEqual(result["st"], 3)
        self.assertTrue(result["silent"])
        self.assertFalse(result["warn"])
        self.assertTrue(result["verbose"])
        self.assertFalse(result["recursive"])

    def test_vm_add_cursor_at_pos_no_mappings_global(self):
        result = self.run_case(
            """
            local cfg = require('multi_cursor.config').values
            return { no_maps = cfg.add_cursor_at_pos_no_mappings }
            """,
            setup_opts="{ backend = 'lua' }",
            pre_setup_lua="vim.g.VM_add_cursor_at_pos_no_mappings = 1",
        )
        self.assertTrue(result["no_maps"])

    def test_vm_filesize_and_persistent_registers_globals(self):
        result = self.run_case(
            """
            local cfg = require('multi_cursor.config').values
            return { lim = cfg.filesize_limit, pr = cfg.persistent_registers }
            """,
            setup_opts="{ backend = 'lua' }",
            pre_setup_lua="vim.g.VM_filesize_limit = 10; vim.g.VM_persistent_registers = 1",
        )
        self.assertEqual(result["lim"], 10)
        self.assertTrue(result["pr"])

    def test_vm_live_editing_global(self):
        result = self.run_case(
            """
            local cfg = require('multi_cursor.config').values
            return { live = cfg.live_editing }
            """,
            setup_opts="{ backend = 'lua' }",
            pre_setup_lua="vim.g.VM_live_editing = 0",
        )
        self.assertFalse(result["live"])

    def test_vm_case_setting_and_reselect_first_globals(self):
        result = self.run_case(
            """
            local cfg = require('multi_cursor.config').values
            return { c = cfg.case_setting, r = cfg.reselect_first }
            """,
            setup_opts="{ backend = 'lua' }",
            pre_setup_lua="vim.g.VM_case_setting = 'ignore'; vim.g.VM_reselect_first = 1",
        )
        self.assertEqual(result["c"], "ignore")
        self.assertTrue(result["r"])

    def test_vm_theme_and_highlight_matches_globals(self):
        result = self.run_case(
            """
            local cfg = require('multi_cursor.config').values
            local hl = vim.api.nvim_get_hl(0, { name = 'Search', link = false })
            return { theme = cfg.theme, matches = cfg.highlight_matches, has_underline = hl.underline == true }
            """,
            setup_opts="{ backend = 'lua' }",
            pre_setup_lua="vim.g.VM_theme = 'iceblue'; vim.g.VM_highlight_matches = 'underline'",
        )
        self.assertEqual(result["theme"], "iceblue")
        self.assertEqual(result["matches"], "underline")
        self.assertTrue(result["has_underline"])

    def test_vm_plugins_compatibility_globals(self):
        result = self.run_case(
            """
            local cfg = require('multi_cursor.config').values
            local p = cfg.plugins_compatibility and cfg.plugins_compatibility.demo or {}
            return { disable = p.disable, enable = p.enable, has_test = type(p.test) == 'string' }
            """,
            setup_opts="{ backend = 'lua' }",
            pre_setup_lua=(
                "vim.g.VM_plugins_compatibilty = { demo = "
                "{ test = '1', disable = 'let g:mc_demo = 0', enable = 'let g:mc_demo = 1' } }"
            ),
        )
        self.assertEqual(result["disable"], "let g:mc_demo = 0")
        self.assertEqual(result["enable"], "let g:mc_demo = 1")
        self.assertTrue(result["has_test"])

    def test_filesize_limit_blocks_start(self):
        result = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { string.rep('x', 200) })
            vim.api.nvim_win_set_cursor(0, { 1, 0 })
            local a = require('multi_cursor.actions')
            local s = require('multi_cursor.state')
            a.add_cursor_at_pos()
            local st = s.current()
            return { enabled = st.enabled, total = #st.cursors }
            """,
            setup_opts="{ backend = 'lua', filesize_limit = 10, show_warnings = false }",
        )
        self.assertFalse(result["enabled"])
        self.assertEqual(result["total"], 0)

    def test_add_cursor_at_pos_no_mappings_behavior(self):
        result = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'abc' })
            vim.api.nvim_win_set_cursor(0, { 1, 0 })
            local a = require('multi_cursor.actions')
            local s = require('multi_cursor.state')
            a.add_cursor_at_pos()
            local st = s.current()
            return { enabled = st.enabled, maps_enabled = st.maps_enabled }
            """,
            setup_opts="{ backend = 'lua', add_cursor_at_pos_no_mappings = true }",
        )
        self.assertTrue(result["enabled"])
        self.assertFalse(result["maps_enabled"])

    def test_toggle_mappings_key_works_while_frozen(self):
        result = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'abc' })
            vim.api.nvim_win_set_cursor(0, { 1, 0 })
            local a = require('multi_cursor.actions')
            local s = require('multi_cursor.state')
            a.add_cursor_at_pos()
            local st = s.current()
            st.maps_enabled = false
            local key = require('multi_cursor.config').values.mappings.toggle_mappings
            local map = vim.fn.maparg(key, 'n', false, true)
            local ok = type(map) == 'table' and map.callback ~= vim.NIL
            if ok then
              map.callback()
            end
            return { has_callback = ok, maps_enabled = st.maps_enabled }
            """,
            setup_opts="{ backend = 'lua' }",
        )
        self.assertTrue(result["has_callback"])
        self.assertTrue(result["maps_enabled"])

    def test_escape_key_clears_while_frozen(self):
        result = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'abc' })
            vim.api.nvim_win_set_cursor(0, { 1, 0 })
            local a = require('multi_cursor.actions')
            local s = require('multi_cursor.state')
            a.add_cursor_at_pos()
            local st = s.current()
            st.maps_enabled = false
            local map = vim.fn.maparg('<Esc>', 'n', false, true)
            local ok = type(map) == 'table' and map.callback ~= vim.NIL
            if ok then
              map.callback()
            end
            return { has_callback = ok, enabled = st.enabled, total = #st.cursors }
            """,
            setup_opts="{ backend = 'lua', silent_exit = true }",
        )
        self.assertTrue(result["has_callback"])
        self.assertFalse(result["enabled"])
        self.assertEqual(result["total"], 0)

    def test_default_mappings_false_still_allows_insert_i_fallback(self):
        result = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'ab', 'cd' })
            vim.api.nvim_win_set_cursor(0, { 1, 0 })
            local a = require('multi_cursor.actions')
            a.add_cursor_vertical(1, 1)
            local map = vim.fn.maparg('i', 'n', false, true)
            local has_callback = type(map) == 'table' and map.callback ~= vim.NIL
            return { has_callback = has_callback }
            """,
            setup_opts="{ backend = 'lua', default_mappings = false }",
        )
        self.assertTrue(result["has_callback"])

    def test_default_mappings_false_still_maps_core_insert_specials(self):
        result = self.run_case(
            """
            local left = vim.fn.maparg('<Left>', 'i', false, true)
            local bs = vim.fn.maparg('<BS>', 'i', false, true)
            local cr = vim.fn.maparg('<CR>', 'i', false, true)
            local home = vim.fn.maparg('<Home>', 'i', false, true)
            local has_left = type(left) == 'table' and left.callback ~= vim.NIL
            local has_bs = type(bs) == 'table' and bs.callback ~= vim.NIL
            local has_cr = type(cr) == 'table' and cr.callback ~= vim.NIL
            local has_home = type(home) == 'table' and home.callback ~= vim.NIL
            return { has_left = has_left, has_bs = has_bs, has_cr = has_cr, has_home = has_home }
            """,
            setup_opts="{ backend = 'lua', default_mappings = false, insert_mode = 'native' }",
        )
        self.assertTrue(result["has_left"])
        self.assertTrue(result["has_bs"])
        self.assertTrue(result["has_cr"])
        self.assertTrue(result["has_home"])

    def test_custom_clear_leader_not_mapped_in_insert_mode(self):
        result = self.run_case(
            """
            local map_i = vim.fn.maparg('<leader>m<Esc>', 'i', false, true)
            local map_esc = vim.fn.maparg('<Esc>', 'i', false, true)
            local has_leader_i = type(map_i) == 'table' and type(map_i.callback) == 'function'
            local has_esc_i = type(map_esc) == 'table' and type(map_esc.callback) == 'function'
            return { has_leader_i = has_leader_i, has_esc_i = has_esc_i }
            """,
            setup_opts="{ backend = 'lua', insert_mode = 'native', mappings = { clear = '<leader>m<Esc>' } }",
            pre_setup_lua="vim.g.mapleader = ' '",
        )
        self.assertFalse(result["has_leader_i"])
        self.assertTrue(result["has_esc_i"])

    def test_statusline_set_and_restore(self):
        result = self.run_case(
            """
            vim.wo.statusline = 'BASELINE'
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'abc' })
            vim.api.nvim_win_set_cursor(0, { 1, 0 })
            local a = require('multi_cursor.actions')
            local s = require('multi_cursor.state')
            a.add_cursor_at_pos()
            local active = vim.wo.statusline
            a.clear()
            local restored = vim.wo.statusline
            return { active = active, restored = restored, enabled = s.current().enabled }
            """,
            setup_opts="{ backend = 'lua', set_statusline = 2, silent_exit = true }",
        )
        self.assertIn("MultiCursor", result["active"])
        self.assertEqual(result["restored"], "BASELINE")
        self.assertFalse(result["enabled"])

    def test_statusline_setting_2_updates_on_cursorhold_only(self):
        result = self.run_case(
            """
            vim.wo.statusline = 'BASELINE'
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'abc' })
            vim.api.nvim_win_set_cursor(0, { 1, 0 })
            local a = require('multi_cursor.actions')
            local s = require('multi_cursor.state')
            local r = require('multi_cursor.render')
            a.add_cursor_at_pos()
            local st = s.current()
            local active = vim.wo.statusline
            vim.wo.statusline = 'EXTERNAL'
            r.sync(st, 'CursorMoved')
            local after_moved = vim.wo.statusline
            r.sync(st, 'CursorHold')
            local after_hold = vim.wo.statusline
            return { active = active, moved = after_moved, hold = after_hold }
            """,
            setup_opts="{ backend = 'lua', set_statusline = 2 }",
        )
        self.assertIn("MultiCursor", result["active"])
        self.assertEqual(result["moved"], "EXTERNAL")
        self.assertIn("MultiCursor", result["hold"])

    def test_silent_exit_suppresses_notify(self):
        result = self.run_case(
            """
            vim.g.mc_notify_count = 0
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'abc' })
            vim.api.nvim_win_set_cursor(0, { 1, 0 })
            local a = require('multi_cursor.actions')
            a.add_cursor_at_pos()
            a.clear()
            return { count = vim.g.mc_notify_count }
            """,
            setup_opts="{ backend = 'lua', silent_exit = true }",
            pre_setup_lua=(
                "vim.notify = function(msg, level)\n  vim.g.mc_notify_count = (vim.g.mc_notify_count or 0) + 1\nend"
            ),
        )
        self.assertEqual(result["count"], 0)

    def test_show_warnings_for_map_conflicts(self):
        result = self.run_case(
            """
            return { count = vim.g.mc_notify_count or 0 }
            """,
            setup_opts=(
                "{ backend = 'lua', show_warnings = true, check_mappings = true, mappings = { find_next = 'Zz' } }"
            ),
            pre_setup_lua=(
                "vim.g.mc_notify_count = 0\n"
                "vim.notify = function(msg, level)\n"
                "  if string.find(msg, 'mapping conflicts', 1, true) then\n"
                "    vim.g.mc_notify_count = (vim.g.mc_notify_count or 0) + 1\n"
                "  end\n"
                "end\n"
                "vim.keymap.set('n', 'Zz', 'w', { buffer = 0, noremap = true })"
            ),
        )
        self.assertEqual(result["count"], 1)

    def test_disable_syntax_in_imode_behavior(self):
        result = self.run_case(
            """
            vim.bo.synmaxcol = 3000
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'abc' })
            vim.api.nvim_win_set_cursor(0, { 1, 0 })
            local a = require('multi_cursor.actions')
            a.add_cursor_at_pos()
            a.begin_insert('insert')
            local during = vim.bo.synmaxcol
            a.end_insert()
            local after = vim.bo.synmaxcol
            return { during = during, after = after }
            """,
            setup_opts="{ backend = 'lua', insert_mode = 'native', disable_syntax_in_imode = true }",
        )
        self.assertEqual(result["during"], 1)
        self.assertEqual(result["after"], 3000)

    def test_quit_after_insert_leave_behavior(self):
        result = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'abc', 'def' })
            vim.api.nvim_win_set_cursor(0, { 1, 0 })
            local a = require('multi_cursor.actions')
            local s = require('multi_cursor.state')
            a.add_cursor_vertical(1, 1)
            a.begin_insert('insert')
            a.end_insert()
            local st = s.current()
            return { enabled = st.enabled, total = #st.cursors }
            """,
            setup_opts=("{ backend = 'lua', insert_mode = 'native', quit_after_leaving_insert_mode = true }"),
        )
        self.assertFalse(result["enabled"])
        self.assertEqual(result["total"], 0)

    def test_reindent_filetypes_behavior(self):
        result = self.run_case(
            """
            vim.bo.filetype = 'lua'
            vim.bo.equalprg = ''
            vim.bo.indentexpr = '2'
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'local x = 1', 'y = 2' })
            vim.api.nvim_win_set_cursor(0, { 2, 0 })
            local a = require('multi_cursor.actions')
            a.add_cursor_at_pos()
            a.begin_insert('insert')
            a.end_insert()
            return { line2 = vim.api.nvim_buf_get_lines(0, 1, 2, false)[1] }
            """,
            setup_opts="{ backend = 'lua', insert_mode = 'native', reindent_filetypes = { 'lua' } }",
        )
        self.assertTrue(result["line2"].startswith("  "))

    def test_single_mode_insert_tab_cycle(self):
        result = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'a', 'b', 'c' })
            vim.api.nvim_win_set_cursor(0, { 1, 0 })
            local a = require('multi_cursor.actions')
            local s = require('multi_cursor.state')
            a.add_cursor_vertical(1, 2)
            a.toggle_single_region()
            a.goto_region(1)
            a.begin_insert('insert')
            local out = a.handle_single_mode_cycle(1, '<Tab>')
            local st = s.current()
            local p = s.cursor_pos(st, st.current)
            a.end_insert()
            return { current = st.current, row = p and p.row or -1, out = out }
            """,
            setup_opts="{ backend = 'lua', insert_mode = 'native', single_mode_maps = true }",
        )
        self.assertEqual(result["current"], 2)
        self.assertEqual(result["row"], 1)
        self.assertEqual(result["out"], "")

    def test_single_mode_auto_reset_on_insert_leave(self):
        result = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'a', 'b' })
            vim.api.nvim_win_set_cursor(0, { 1, 0 })
            local a = require('multi_cursor.actions')
            local s = require('multi_cursor.state')
            a.add_cursor_vertical(1, 1)
            a.toggle_single_region()
            a.begin_insert('insert')
            a.end_insert()
            return { single = s.current().single_region }
            """,
            setup_opts="{ backend = 'lua', insert_mode = 'native', single_mode_auto_reset = true }",
        )
        self.assertFalse(result["single"])

    def test_single_mode_auto_reset_can_be_disabled(self):
        result = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'a', 'b' })
            vim.api.nvim_win_set_cursor(0, { 1, 0 })
            local a = require('multi_cursor.actions')
            local s = require('multi_cursor.state')
            a.add_cursor_vertical(1, 1)
            a.toggle_single_region()
            a.begin_insert('insert')
            a.end_insert()
            return { single = s.current().single_region }
            """,
            setup_opts="{ backend = 'lua', insert_mode = 'native', single_mode_auto_reset = false }",
        )
        self.assertTrue(result["single"])

    def test_vm_single_mode_globals(self):
        result = self.run_case(
            """
            local cfg = require('multi_cursor.config').values
            return {
              maps = cfg.single_mode_maps,
              auto = cfg.single_mode_auto_reset,
            }
            """,
            setup_opts="{ backend = 'lua' }",
            pre_setup_lua="vim.g.VM_single_mode_maps = 0; vim.g.VM_single_mode_auto_reset = 0",
        )
        self.assertFalse(result["maps"])
        self.assertFalse(result["auto"])

    def test_vm_single_mode_maps_table_compat(self):
        result = self.run_case(
            """
            local cfg = require('multi_cursor.config').values
            return { maps = cfg.single_mode_maps, n = cfg.mappings.i_next, p = cfg.mappings.i_prev }
            """,
            setup_opts="{ backend = 'lua' }",
            pre_setup_lua="vim.g.VM_single_mode_maps = { ['<Tab>'] = '1', ['<S-Tab>'] = '-1' }",
        )
        self.assertTrue(result["maps"])
        self.assertEqual(result["n"], "<Tab>")
        self.assertEqual(result["p"], "<S-Tab>")

    def test_vm_use_visual_mode_global(self):
        result = self.run_case(
            """
            local cfg = require('multi_cursor.config').values
            local m = vim.fn.maparg(cfg.mappings.visual_all, 'x', false, true)
            return {
              use_visual = cfg.use_visual_mode,
              has_visual_map = type(m) == 'table' and m.lhs == cfg.mappings.visual_all,
            }
            """,
            setup_opts="{ backend = 'lua' }",
            pre_setup_lua="vim.g.VM_use_visual_mode = 0",
        )
        self.assertFalse(result["use_visual"])
        self.assertFalse(result["has_visual_map"])

    def test_vm_single_mode_maps_keys_override(self):
        result = self.run_case(
            """
            local cfg = require('multi_cursor.config').values
            return { n = cfg.mappings.i_next, p = cfg.mappings.i_prev }
            """,
            setup_opts="{ backend = 'lua' }",
            pre_setup_lua="vim.g.VM_maps = { ['I Next'] = '<A-j>', ['I Prev'] = '<A-k>' }",
        )
        self.assertEqual(result["n"], "<A-j>")
        self.assertEqual(result["p"], "<A-k>")

    def test_single_mode_insert_maps_can_be_disabled(self):
        result = self.run_case(
            """
            local m = vim.fn.maparg('<Tab>', 'i', false, true)
            local rhs = (type(m) == 'table' and m.rhs) or ''
            return { rhs = rhs }
            """,
            setup_opts="{ backend = 'lua', insert_mode = 'native', single_mode_maps = false }",
        )
        self.assertNotIn("handle_single_mode_cycle", result["rhs"])

    def test_custom_user_operator_mapping_installed(self):
        result = self.run_case(
            """
            local m = vim.fn.maparg('yz', 'n', false, true)
            return { has = type(m) == 'table' and m.lhs == 'yz' }
            """,
            setup_opts="{ backend = 'lua', user_operators = { 'yz' } }",
        )
        self.assertTrue(result["has"])

    def test_reselect_last(self):
        result = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'a', 'b', 'c' })
            vim.api.nvim_win_set_cursor(0, { 1, 0 })
            local a = require('multi_cursor.actions')
            local s = require('multi_cursor.state')
            a.add_cursor_vertical(1, 2)
            a.clear()
            a.reselect_last()
            local st = s.current()
            return { total = #st.cursors }
            """
        )
        self.assertEqual(result["total"], 3)

    def test_single_region_and_goto(self):
        result = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'a', 'b', 'c' })
            vim.api.nvim_win_set_cursor(0, { 1, 0 })
            local a = require('multi_cursor.actions')
            local s = require('multi_cursor.state')
            a.add_cursor_vertical(1, 2)
            a.toggle_single_region()
            local st = s.current()
            local first = st.current
            a.goto_region(1)
            local second = st.current
            a.goto_region(-1)
            local third = st.current
            return {
              single = st.single_region,
              first = first,
              second = second,
              third = third,
            }
            """
        )
        self.assertTrue(result["single"])
        self.assertEqual(result["first"], result["third"])
        self.assertNotEqual(result["first"], result["second"])

    def test_invert_direction_and_multiline_toggle(self):
        result = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'abcd' })
            vim.api.nvim_win_set_cursor(0, { 1, 1 })
            local a = require('multi_cursor.actions')
            local s = require('multi_cursor.state')
            a.add_cursor_at_pos()
            a.toggle_mode()
            a.shift_selection(2)
            local st = s.current()
            local before = s.cursor_pos(st, st.current)
            a.invert_direction()
            a.toggle_multiline()
            local after = s.cursor_pos(st, st.current)
            return {
              before_col = before.col,
              before_acol = before.acol,
              after_col = after.col,
              after_acol = after.acol,
              multiline = st.multiline,
              direction = st.direction,
            }
            """
        )
        self.assertEqual(result["before_col"], result["after_acol"])
        self.assertEqual(result["before_acol"], result["after_col"])
        self.assertTrue(result["multiline"])
        self.assertEqual(result["direction"], -1)

    def test_extend_delete_and_change(self):
        result = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'foo', 'bar' })
            vim.api.nvim_win_set_cursor(0, { 1, 1 })
            local a = require('multi_cursor.actions')
            local s = require('multi_cursor.state')
            a.add_cursor_vertical(1, 1)
            local st = s.current()
            st.mode = 'extend'
            for i = 1, #st.cursors do
              local p = s.cursor_pos(st, i)
              s.set_anchor(st, i, p.row, 0)
              s.set_pos(st, i, p.row, 3)
            end
            a.delete_regions()
            a.change_regions('Z')
            return { lines = vim.api.nvim_buf_get_lines(0, 0, -1, false) }
            """
        )
        self.assertEqual(result["lines"], ["Z", "Z"])

    def test_operator_with_motion(self):
        result = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'foo bar', 'foo baz' })
            vim.api.nvim_win_set_cursor(0, { 1, 0 })
            local a = require('multi_cursor.actions')
            a.add_cursor_vertical(1, 1)
            a.operator_with_motion('d', 'w')
            return { lines = vim.api.nvim_buf_get_lines(0, 0, -1, false) }
            """
        )
        self.assertEqual(result["lines"], ["bar", "baz"])

    def test_remove_every_n_regions(self):
        result = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'a', 'b', 'c', 'd' })
            vim.api.nvim_win_set_cursor(0, { 1, 0 })
            local a = require('multi_cursor.actions')
            local s = require('multi_cursor.state')
            a.add_cursor_vertical(1, 3)
            a.remove_every_n_regions(2)
            local st = s.current()
            return { total = #st.cursors }
            """
        )
        self.assertEqual(result["total"], 2)

    def test_run_normal_and_visual(self):
        result = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'aa', 'bb' })
            vim.api.nvim_win_set_cursor(0, { 1, 0 })
            local a = require('multi_cursor.actions')
            local s = require('multi_cursor.state')
            a.add_cursor_vertical(1, 1)
            a.run_normal('A!')
            local st = s.current()
            st.mode = 'extend'
            for i = 1, #st.cursors do
              local p = s.cursor_pos(st, i)
              s.set_anchor(st, i, p.row, 0)
              s.set_pos(st, i, p.row, 2)
            end
            a.run_visual('gU')
            return { lines = vim.api.nvim_buf_get_lines(0, 0, -1, false) }
            """
        )
        self.assertEqual(result["lines"], ["AA!", "BB!"])
