from tests.nvim_case import NvimCase


class TestLuaTools(NvimCase):
    def test_theme_applies_highlight_groups(self):
        result = self.run_case(
            """
            local cursor = vim.api.nvim_get_hl(0, { name = 'MultiCursorCursor', link = false })
            local extend = vim.api.nvim_get_hl(0, { name = 'MultiCursorExtend', link = false })
            local mono = vim.api.nvim_get_hl(0, { name = 'MultiCursorMono', link = false })
            local ins = vim.api.nvim_get_hl(0, { name = 'MultiCursorInsert', link = false })
            return {
              cursor_bg = cursor.bg ~= nil,
              extend_bg = extend.bg ~= nil,
              mono_bg = mono.bg ~= nil,
              insert_set = next(ins) ~= nil,
            }
            """,
            setup_opts="{ backend = 'lua', theme = 'iceblue' }",
        )
        self.assertTrue(result["cursor_bg"])
        self.assertTrue(result["extend_bg"])
        self.assertTrue(result["mono_bg"])
        self.assertTrue(result["insert_set"])

    def test_search_menu_dispatches_select_all(self):
        result = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'foo', 'foo', 'bar' })
            vim.api.nvim_win_set_cursor(0, { 1, 0 })
            local a = require('multi_cursor.actions')
            local s = require('multi_cursor.state')
            a.seed_word_search()
            a.search_menu('select_all')
            local st = s.current()
            return { total = #st.cursors, mode = st.mode }
            """,
            setup_opts="{ backend = 'lua' }",
        )
        self.assertEqual(result["total"], 2)
        self.assertEqual(result["mode"], "cursor")

    def test_tools_menu_dispatches_toggle_mode(self):
        result = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'foo', 'bar' })
            vim.api.nvim_win_set_cursor(0, { 1, 0 })
            local a = require('multi_cursor.actions')
            local s = require('multi_cursor.state')
            a.add_cursor_vertical(1, 1)
            a.tools_menu('toggle_mode')
            local st = s.current()
            return { mode = st.mode, total = #st.cursors }
            """,
            setup_opts="{ backend = 'lua' }",
        )
        self.assertEqual(result["mode"], "extend")
        self.assertEqual(result["total"], 2)

    def test_builtin_picker_drives_search_menu_without_choice_arg(self):
        result = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'foo', 'foo', 'bar' })
            vim.api.nvim_win_set_cursor(0, { 1, 0 })
            local a = require('multi_cursor.actions')
            local p = require('multi_cursor.picker')
            local s = require('multi_cursor.state')
            local old_select = p.select
            p.select = function(items, _, cb)
              cb(items[4]) -- select_all
              return true
            end
            a.seed_word_search()
            a.search_menu(nil)
            p.select = old_select
            local st = s.current()
            return { total = #st.cursors }
            """,
            setup_opts="{ backend = 'lua', picker = 'builtin' }",
        )
        self.assertEqual(result["total"], 2)

    def test_picker_backend_builtin_when_forced(self):
        result = self.run_case(
            """
            local picker = require('multi_cursor.picker')
            return { backend = picker.backend() }
            """,
            setup_opts="{ backend = 'lua', picker = 'builtin' }",
        )
        self.assertEqual(result["backend"], "builtin")

    def test_regex_search_uses_picker_matches_and_applies_selected(self):
        result = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'foo', 'foo', 'foo' })
            vim.api.nvim_win_set_cursor(0, { 1, 0 })
            local a = require('multi_cursor.actions')
            local p = require('multi_cursor.picker')
            local s = require('multi_cursor.state')
            local old_input = vim.fn.input
            local old = p.select_matches
            vim.fn.input = function(_)
              return 'foo'
            end
            p.select_matches = function(_, _, matches, cb)
              cb(matches[2])
              return true
            end
            local ok = a.find_by_regex(nil, { select_all = false })
            vim.fn.input = old_input
            p.select_matches = old
            local st = s.current()
            local pos = s.cursor_pos(st, st.current)
            return { ok = ok, total = #st.cursors, row = pos and pos.row or -1 }
            """,
            setup_opts="{ backend = 'lua', picker = 'builtin' }",
        )
        self.assertTrue(result["ok"])
        self.assertEqual(result["total"], 3)
        self.assertEqual(result["row"], 1)

    def test_regex_select_all_picker_sets_current_from_choice(self):
        result = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'foo', 'foo', 'foo' })
            vim.api.nvim_win_set_cursor(0, { 1, 0 })
            local a = require('multi_cursor.actions')
            local p = require('multi_cursor.picker')
            local s = require('multi_cursor.state')
            local old_input = vim.fn.input
            local old = p.select_matches
            vim.fn.input = function(_)
              return 'foo'
            end
            p.select_matches = function(_, _, matches, cb)
              cb(matches[3])
              return true
            end
            local ok = a.find_by_regex(nil, { select_all = true })
            vim.fn.input = old_input
            p.select_matches = old
            local st = s.current()
            local pos = s.cursor_pos(st, st.current)
            return { ok = ok, total = #st.cursors, row = pos and pos.row or -1 }
            """,
            setup_opts="{ backend = 'lua', picker = 'builtin' }",
        )
        self.assertTrue(result["ok"])
        self.assertEqual(result["total"], 3)
        self.assertEqual(result["row"], 2)

    def test_additional_legacy_theme_name_supported(self):
        result = self.run_case(
            """
            local cursor = vim.api.nvim_get_hl(0, { name = 'MultiCursorCursor', link = false })
            return { has_bg = cursor.bg ~= nil }
            """,
            setup_opts="{ backend = 'lua', theme = 'paper' }",
        )
        self.assertTrue(result["has_bg"])

    def test_helix_theme_name_supported(self):
        result = self.run_case(
            """
            local cursor = vim.api.nvim_get_hl(0, { name = 'MultiCursorCursor', link = false })
            return { has_bg = cursor.bg ~= nil }
            """,
            setup_opts="{ backend = 'lua', theme = 'helix' }",
        )
        self.assertTrue(result["has_bg"])

    def test_persistent_registers_save_and_load(self):
        saved = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'one', 'two' })
            vim.api.nvim_win_set_cursor(0, { 1, 0 })
            local a = require('multi_cursor.actions')
            a.add_cursor_vertical(1, 1)
            a.yank()
            local store = vim.g.multi_cursor_registers_store or {}
            local reg = store['"'] or { items = {} }
            return { count = #reg.items, first = reg.items[1], second = reg.items[2] }
            """,
            setup_opts="{ backend = 'lua', persistent_registers = true }",
        )
        self.assertEqual(saved["count"], 2)
        self.assertEqual(saved["first"], "one")
        self.assertEqual(saved["second"], "two")

        loaded = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'target' })
            vim.api.nvim_win_set_cursor(0, { 1, 0 })
            local a = require('multi_cursor.actions')
            a.paste_single_cursor(true)
            return { lines = vim.api.nvim_buf_get_lines(0, 0, -1, false) }
            """,
            setup_opts="{ backend = 'lua', persistent_registers = true }",
            pre_setup_lua=(
                "vim.g.multi_cursor_registers_store = { ['\"'] = { items = { 'one', 'two' }, kind = 'line' } }"
            ),
        )
        self.assertEqual(loaded["lines"], ["target", "one", "two"])

    def test_paste_single_cursor_reads_vim_register_fallback(self):
        result = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'target' })
            vim.api.nvim_win_set_cursor(0, { 1, 0 })
            local s = require('multi_cursor.state')
            local a = require('multi_cursor.actions')
            s.registers['"'] = { items = {}, kind = 'line' }
            vim.fn.setreg('"', { 'one', 'two' }, 'V')
            a.paste_single_cursor(true)
            return { lines = vim.api.nvim_buf_get_lines(0, 0, -1, false) }
            """,
            setup_opts="{ backend = 'lua' }",
        )
        self.assertEqual(result["lines"], ["target", "one", "two"])

    def test_mouse_cursor_word_column_actions(self):
        result = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'foo bar', 'foo baz', 'foo qux' })
            vim.api.nvim_win_set_cursor(0, { 1, 1 })
            local a = require('multi_cursor.actions')
            local s = require('multi_cursor.state')

            a.add_cursor_at_pos()
            a.mouse_cursor(1, 2)
            local st1 = s.current()
            local c1 = #st1.cursors

            a.clear()
            vim.api.nvim_win_set_cursor(0, { 1, 1 })
            a.mouse_word(1, 1)
            local st2 = s.current()
            local c2 = #st2.cursors

            a.clear()
            vim.api.nvim_win_set_cursor(0, { 1, 1 })
            a.mouse_column(2, 1)
            local st3 = s.current()
            local rows = {}
            for _, i in ipairs(s.sort_indices_asc(st3)) do
              local p = s.cursor_pos(st3, i)
              if p then
                table.insert(rows, p.row)
              end
            end

            return { mouse_cursor_total = c1, mouse_word_total = c2, mouse_column_rows = rows }
            """,
            setup_opts="{ backend = 'lua' }",
        )
        self.assertEqual(result["mouse_cursor_total"], 2)
        self.assertEqual(result["mouse_word_total"], 1)
        self.assertEqual(result["mouse_column_rows"], [0, 1, 2])

    def test_multicursor_yank_and_single_cursor_paste(self):
        result = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'one', 'two', 'three', 'target' })
            vim.api.nvim_win_set_cursor(0, { 1, 0 })
            local a = require('multi_cursor.actions')
            a.add_cursor_vertical(1, 1)
            a.yank()
            a.clear()
            vim.api.nvim_win_set_cursor(0, { 4, 0 })
            a.paste_single_cursor(true)
            return { lines = vim.api.nvim_buf_get_lines(0, 0, -1, false) }
            """
        )
        self.assertEqual(result["lines"], ["one", "two", "three", "target", "one", "two"])

    def test_multicursor_paste_distributes_items(self):
        result = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'a', 'b', 'c' })
            vim.api.nvim_win_set_cursor(0, { 1, 0 })
            local a = require('multi_cursor.actions')
            local s = require('multi_cursor.state')
            a.add_cursor_vertical(1, 1)
            s.registers['"'] = { items = { 'X', 'Y' }, kind = 'line' }
            a.paste_multicursor(true)
            return { lines = vim.api.nvim_buf_get_lines(0, 0, -1, false) }
            """
        )
        self.assertEqual(result["lines"], ["a", "X", "b", "Y", "c"])

    def test_align_transpose_duplicate(self):
        result = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'a', 'bb' })
            vim.api.nvim_win_set_cursor(0, { 1, 0 })
            local a = require('multi_cursor.actions')
            a.add_cursor_vertical(1, 1)
            a.align()
            a.transpose()
            a.duplicate()
            return { lines = vim.api.nvim_buf_get_lines(0, 0, -1, false) }
            """
        )
        self.assertGreaterEqual(len(result["lines"]), 3)
        self.assertTrue(any(line.endswith("a") for line in result["lines"]))
        self.assertTrue(any(line.endswith("bb") for line in result["lines"]))

    def test_align_char_and_regex(self):
        result = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'a=x', 'bbb=2' })
            vim.api.nvim_win_set_cursor(0, { 1, 0 })
            local a = require('multi_cursor.actions')
            a.add_cursor_vertical(1, 1)
            a.align_char(1, '=')
            a.align_regex('=')
            return { lines = vim.api.nvim_buf_get_lines(0, 0, -1, false) }
            """
        )
        self.assertEqual(result["lines"], ["  a=x", "bbb=2"])

    def test_transform_number_case(self):
        result = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'foo', 'bar', 'baz' })
            vim.api.nvim_win_set_cursor(0, { 1, 0 })
            local a = require('multi_cursor.actions')
            a.add_cursor_vertical(1, 2)
            a.transform_regions([[%t .. "_x"]])
            a.number_regions(1, 1, true)
            a.case_convert('upper')
            return { lines = vim.api.nvim_buf_get_lines(0, 0, -1, false) }
            """
        )
        self.assertEqual(result["lines"], ["FOO_X1", "BAR_X2", "BAZ_X3"])

    def test_filter_regions(self):
        result = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'foo', 'bar', 'baz' })
            vim.api.nvim_win_set_cursor(0, { 1, 0 })
            local a = require('multi_cursor.actions')
            local s = require('multi_cursor.state')
            a.add_cursor_vertical(1, 2)
            a.filter_regions('ba', false)
            local st = s.current()
            return { total = #st.cursors }
            """
        )
        self.assertEqual(result["total"], 2)

    def test_replace_and_subtract_pattern_in_regions(self):
        result = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'foo123', 'foo456' })
            vim.api.nvim_win_set_cursor(0, { 1, 3 })
            local a = require('multi_cursor.actions')
            local s = require('multi_cursor.state')
            a.add_cursor_vertical(1, 1)
            local st = s.current()
            st.mode = 'extend'
            for i = 1, #st.cursors do
              local p = s.cursor_pos(st, i)
              s.set_anchor(st, i, p.row, 0)
              s.set_pos(st, i, p.row, 6)
            end
            a.replace_pattern_in_regions('foo', 'bar')
            a.subtract_pattern([[\\d]])
            return { lines = vim.api.nvim_buf_get_lines(0, 0, -1, false) }
            """
        )
        self.assertEqual(len(result["lines"]), 2)
        self.assertTrue(result["lines"][0].startswith("bar"))
        self.assertTrue(result["lines"][1].startswith("bar"))

    def test_run_ex_and_macro(self):
        result = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'a', 'b' })
            vim.api.nvim_win_set_cursor(0, { 1, 0 })
            local a = require('multi_cursor.actions')
            a.add_cursor_vertical(1, 1)
            a.run_ex('normal! I!')
            vim.fn.setreg('q', 'r#')
            a.run_macro('q')
            return { lines = vim.api.nvim_buf_get_lines(0, 0, -1, false) }
            """
        )
        self.assertEqual(result["lines"], ["#a", "#b"])

    def test_surround_in_cursor_mode(self):
        result = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'foo', 'bar' })
            vim.api.nvim_win_set_cursor(0, { 1, 0 })
            local a = require('multi_cursor.actions')
            a.add_cursor_vertical(1, 1)
            a.surround('(')
            return { lines = vim.api.nvim_buf_get_lines(0, 0, -1, false) }
            """
        )
        self.assertEqual(result["lines"], ["(foo)", "(bar)"])

    def test_surround_in_extend_mode(self):
        result = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'foo', 'bar' })
            vim.api.nvim_win_set_cursor(0, { 1, 0 })
            local a = require('multi_cursor.actions')
            a.add_cursor_vertical(1, 1)
            a.select_operator_with_motion('iw')
            a.surround('"')
            return { lines = vim.api.nvim_buf_get_lines(0, 0, -1, false) }
            """
        )
        self.assertEqual(result["lines"], ['"foo"', '"bar"'])

    def test_replace_chars_in_extend_mode(self):
        result = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'foo', 'bar' })
            vim.api.nvim_win_set_cursor(0, { 1, 0 })
            local a = require('multi_cursor.actions')
            a.add_cursor_vertical(1, 1)
            a.select_operator_with_motion('iw')
            a.replace_chars('x')
            return { lines = vim.api.nvim_buf_get_lines(0, 0, -1, false) }
            """
        )
        self.assertEqual(result["lines"], ["xxx", "xxx"])

    def test_native_insert_mode_multicursor_typing(self):
        result = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'ab', 'cd' })
            vim.api.nvim_win_set_cursor(0, { 1, 0 })
            local a = require('multi_cursor.actions')
            local s = require('multi_cursor.state')
            a.add_cursor_vertical(1, 1)
            local keys = vim.api.nvim_replace_termcodes('iX<Esc>', true, false, true)
            vim.api.nvim_feedkeys(keys, 'xt', false)
            vim.cmd('redraw')
            local st = s.current()
            return {
              lines = vim.api.nvim_buf_get_lines(0, 0, -1, false),
              insert_active = st.insert_active,
            }
            """,
            setup_opts="{ backend = 'lua', insert_mode = 'native' }",
        )
        self.assertEqual(result["lines"], ["Xab", "Xcd"])
        self.assertFalse(result["insert_active"])

    def test_live_editing_disabled_defers_replication_until_insert_leave(self):
        result = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'abc', 'def' })
            vim.api.nvim_win_set_cursor(0, { 1, 1 })
            local a = require('multi_cursor.actions')
            local s = require('multi_cursor.state')
            a.add_cursor_vertical(1, 1)
            a.begin_insert('insert')
            local st = s.current()
            st.insert_pending = { ch = 'X', row = 0, col = 1 }
            vim.api.nvim_exec_autocmds('TextChangedI', { buffer = 0 })
            local mid = vim.api.nvim_buf_get_lines(0, 0, -1, false)
            vim.api.nvim_exec_autocmds('InsertLeave', { buffer = 0 })
            local fin = vim.api.nvim_buf_get_lines(0, 0, -1, false)
            return { mid = mid, fin = fin }
            """,
            setup_opts="{ backend = 'lua', insert_mode = 'native', live_editing = false }",
        )
        self.assertEqual(result["mid"], ["abc", "def"])
        self.assertEqual(result["fin"], ["abc", "dXef"])

    def test_live_editing_enabled_applies_on_textchangedi(self):
        result = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'abc', 'def' })
            vim.api.nvim_win_set_cursor(0, { 1, 1 })
            local a = require('multi_cursor.actions')
            local s = require('multi_cursor.state')
            a.add_cursor_vertical(1, 1)
            a.begin_insert('insert')
            local st = s.current()
            st.insert_pending = { ch = 'X', row = 0, col = 1 }
            vim.api.nvim_exec_autocmds('TextChangedI', { buffer = 0 })
            local mid = vim.api.nvim_buf_get_lines(0, 0, -1, false)
            return { mid = mid }
            """,
            setup_opts="{ backend = 'lua', insert_mode = 'native', live_editing = true }",
        )
        self.assertEqual(result["mid"], ["abc", "dXef"])

    def test_case_setting_applied_on_start_and_restored_on_clear(self):
        result = self.run_case(
            """
            vim.o.smartcase = true
            vim.o.ignorecase = true
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'abc' })
            vim.api.nvim_win_set_cursor(0, { 1, 0 })
            local a = require('multi_cursor.actions')
            a.add_cursor_at_pos()
            local during = { smart = vim.o.smartcase, ignore = vim.o.ignorecase }
            a.clear()
            local after = { smart = vim.o.smartcase, ignore = vim.o.ignorecase }
            return { during = during, after = after }
            """,
            setup_opts="{ backend = 'lua', case_setting = 'sensitive', silent_exit = true }",
        )
        self.assertFalse(result["during"]["smart"])
        self.assertFalse(result["during"]["ignore"])
        self.assertTrue(result["after"]["smart"])
        self.assertTrue(result["after"]["ignore"])

    def test_plugins_compatibility_disable_enable_cycle(self):
        result = self.run_case(
            """
            vim.g.mc_plugin_enabled = 1
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'abc' })
            vim.api.nvim_win_set_cursor(0, { 1, 0 })
            local a = require('multi_cursor.actions')
            a.add_cursor_at_pos()
            local during = vim.g.mc_plugin_enabled
            a.clear()
            local after = vim.g.mc_plugin_enabled
            return { during = during, after = after }
            """,
            setup_opts=(
                "{ backend = 'lua', plugins_compatibility = { demo = { "
                "test = 'g:mc_plugin_enabled == 1', "
                "disable = 'let g:mc_plugin_enabled = 0', "
                "enable = 'let g:mc_plugin_enabled = 1' } }, "
                "silent_exit = true }"
            ),
        )
        self.assertEqual(result["during"], 0)
        self.assertEqual(result["after"], 1)

    def test_reselect_first_on_insert_leave(self):
        result = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'a', 'b', 'c' })
            vim.api.nvim_win_set_cursor(0, { 1, 0 })
            local a = require('multi_cursor.actions')
            local s = require('multi_cursor.state')
            a.add_cursor_vertical(1, 2)
            local st = s.current()
            st.current = 3
            a.begin_insert('insert')
            a.end_insert()
            return { current = st.current }
            """,
            setup_opts="{ backend = 'lua', insert_mode = 'native', reselect_first = true }",
        )
        self.assertEqual(result["current"], 1)

    def test_native_insert_mode_ctrl_w_and_ctrl_u(self):
        result = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'foo bar', 'zip zap' })
            vim.api.nvim_win_set_cursor(0, { 1, 7 })
            local a = require('multi_cursor.actions')
            a.add_cursor_vertical(1, 1)
            a.begin_insert('insert')
            a.apply_insert_special_now('ctrl_w')
            local after_w = vim.api.nvim_buf_get_lines(0, 0, -1, false)
            a.apply_insert_special_now('ctrl_u')
            local after_u = vim.api.nvim_buf_get_lines(0, 0, -1, false)
            a.end_insert()
            return { after_w = after_w, after_u = after_u }
            """,
            setup_opts="{ backend = 'lua', insert_mode = 'native' }",
        )
        self.assertEqual(result["after_w"], ["foo ", "zip "])
        self.assertEqual(result["after_u"], ["", ""])

    def test_native_insert_mode_ctrl_d(self):
        result = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'abc', 'def' })
            vim.api.nvim_win_set_cursor(0, { 1, 1 })
            local a = require('multi_cursor.actions')
            a.add_cursor_vertical(1, 1)
            a.begin_insert('insert')
            a.apply_insert_special_now('ctrl_d')
            local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
            a.end_insert()
            return { lines = lines }
            """,
            setup_opts="{ backend = 'lua', insert_mode = 'native' }",
        )
        self.assertEqual(result["lines"], ["ac", "df"])

    def test_native_insert_mode_replace_toggle(self):
        result = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'abc', 'def' })
            vim.api.nvim_win_set_cursor(0, { 1, 1 })
            local a = require('multi_cursor.actions')
            local s = require('multi_cursor.state')
            a.add_cursor_vertical(1, 1)
            a.begin_insert('insert')
            local st = s.current()
            st.replace_mode = true
            vim.api.nvim_buf_set_text(0, 0, 1, 0, 2, { 'X' })
            vim.api.nvim_win_set_cursor(0, { 1, 2 })
            st.insert_pending = { ch = 'X', row = 0, col = 1 }
            a.apply_pending_insert()
            local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
            a.end_insert()
            return { lines = lines }
            """,
            setup_opts="{ backend = 'lua', insert_mode = 'native' }",
        )
        self.assertEqual(result["lines"], ["aXc", "dXf"])

    def test_native_insert_mode_unknown_special_passthrough(self):
        result = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'abc', 'def' })
            vim.api.nvim_win_set_cursor(0, { 1, 1 })
            local a = require('multi_cursor.actions')
            local s = require('multi_cursor.state')
            a.add_cursor_vertical(1, 1)
            a.begin_insert('insert')
            local out = a.handle_insert_special('paste_passthrough', 'abc')
            local st = s.current()
            a.end_insert()
            return { out = out, active = st.insert_active }
            """,
            setup_opts="{ backend = 'lua', insert_mode = 'native' }",
        )
        self.assertEqual(result["out"], "abc")
        self.assertFalse(result["active"])

    def test_native_insert_pending_queue_accumulates_fast_input(self):
        result = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'abc', 'def' })
            vim.api.nvim_win_set_cursor(0, { 1, 1 })
            local a = require('multi_cursor.actions')
            local s = require('multi_cursor.state')
            a.add_cursor_vertical(1, 1)
            a.begin_insert('insert')
            a.insert_char_pre('x')
            a.insert_char_pre(' ')
            local st = s.current()
            local pending = st.insert_pending
            local count = 0
            if type(pending) == 'table' and pending.ch ~= nil then
              count = 1
            elseif type(pending) == 'table' then
              count = #pending
            end
            a.end_insert()
            return { count = count }
            """,
            setup_opts="{ backend = 'lua', insert_mode = 'native' }",
        )
        self.assertEqual(result["count"], 2)

    def test_native_insert_escape_exits_insert_but_keeps_multicursor(self):
        result = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'abc', 'def' })
            vim.api.nvim_win_set_cursor(0, { 1, 1 })
            local a = require('multi_cursor.actions')
            local s = require('multi_cursor.state')
            a.add_cursor_vertical(1, 1)
            a.begin_insert('insert')
            local out = a.handle_insert_special('esc', '<Esc>')
            vim.wait(50)
            local st = s.current()
            return { out = out, enabled = st.enabled, active = st.insert_active, total = #st.cursors }
            """,
            setup_opts="{ backend = 'lua', insert_mode = 'native', silent_exit = true }",
        )
        self.assertEqual(result["out"], "<Esc>")
        self.assertTrue(result["enabled"])
        self.assertTrue(result["active"])
        self.assertEqual(result["total"], 2)

    def test_native_insert_escape_keeps_multicursor_with_custom_clear_mapping(self):
        result = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'abc', 'def' })
            vim.api.nvim_win_set_cursor(0, { 1, 1 })
            local a = require('multi_cursor.actions')
            local s = require('multi_cursor.state')
            a.add_cursor_vertical(1, 1)
            a.begin_insert('insert')
            local out = a.handle_insert_special('esc', '<Esc>')
            vim.wait(50)
            local st = s.current()
            return { out = out, enabled = st.enabled, active = st.insert_active, total = #st.cursors }
            """,
            setup_opts=(
                "{ backend = 'lua', insert_mode = 'native', silent_exit = true, "
                "mappings = { clear = '<leader>m<Esc>' } }"
            ),
        )
        self.assertEqual(result["out"], "<Esc>")
        self.assertTrue(result["enabled"])
        self.assertTrue(result["active"])
        self.assertEqual(result["total"], 2)

    def test_insert_special_inactive_fallback_is_not_termcoded(self):
        result = self.run_case(
            """
            local a = require('multi_cursor.actions')
            local out = a.handle_insert_special('bs', '<BS>')
            return { out = out }
            """,
            setup_opts="{ backend = 'lua', insert_mode = 'native' }",
        )
        self.assertEqual(result["out"], "<BS>")

    def test_lua_keymaps_include_desc_for_which_key(self):
        result = self.run_case(
            """
            local map = vim.fn.maparg('<C-n>', 'n', false, true)
            return { desc = map.desc or '' }
            """,
            setup_opts="{ backend = 'lua' }",
        )
        self.assertIn("MultiCursor:", result["desc"])

    def test_seed_word_search_starts_session_and_next_adds_cursor(self):
        result = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'foo x foo x foo' })
            vim.api.nvim_win_set_cursor(0, { 1, 1 })
            local a = require('multi_cursor.actions')
            local s = require('multi_cursor.state')
            a.seed_word_search()
            a.find_next(false)
            local st = s.current()
            return {
              total = #st.cursors,
              search = st.search[1] or '',
            }
            """,
            setup_opts="{ backend = 'lua' }",
        )
        self.assertEqual(result["total"], 2)
        self.assertNotEqual(result["search"], "")

    def test_find_subword_under_select_all_matches_substrings(self):
        result = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'foo foobar', 'barfoo foo' })
            vim.api.nvim_win_set_cursor(0, { 1, 0 })
            local a = require('multi_cursor.actions')
            local s = require('multi_cursor.state')
            a.find_subword_under()
            a.select_all()
            local st = s.current()
            return { total = #st.cursors }
            """,
            setup_opts="{ backend = 'lua' }",
        )
        self.assertEqual(result["total"], 4)

    def test_regex_picker_applies_only_filtered_results(self):
        result = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'foo', 'foo', 'foo', 'foo' })
            local a = require('multi_cursor.actions')
            local s = require('multi_cursor.state')
            local p = require('multi_cursor.picker')
            local old = p.select_matches
            p.select_matches = function(_, _, matches, on_choice)
              on_choice(matches[2], { matches[2], matches[4] })
              return true
            end
            a.find_by_regex('foo', { select_all = true, force_picker = true })
            p.select_matches = old
            local st = s.current()
            local rows = {}
            for i = 1, #st.cursors do
              local cp = s.cursor_pos(st, i)
              rows[#rows + 1] = cp and cp.row or -1
            end
            table.sort(rows)
            return { total = #st.cursors, rows = rows, current = st.current }
            """,
            setup_opts="{ backend = 'lua' }",
        )
        self.assertEqual(result["total"], 2)
        self.assertEqual(result["rows"], [1, 3])
        self.assertIn(result["current"], [1, 2])

    def test_seed_word_search_leader_mapping_exists_with_desc(self):
        result = self.run_case(
            """
            local map = vim.fn.maparg('<leader>m*', 'n', false, true)
            return { lhs = map.lhs or '', desc = map.desc or '' }
            """,
            setup_opts="{ backend = 'lua', multicursor_leader = '<leader>m' }",
        )
        self.assertNotEqual(result["lhs"], "")
        self.assertIn("seed word search", result["desc"].lower())

    def test_seed_word_search_clears_native_hlsearch(self):
        result = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'foo bar foo' })
            vim.api.nvim_win_set_cursor(0, { 1, 1 })
            vim.cmd('set hlsearch')
            vim.cmd('normal! /foo\\n')
            vim.cmd('redraw')
            local before = vim.v.hlsearch
            local a = require('multi_cursor.actions')
            a.seed_word_search()
            local after = vim.v.hlsearch
            return { before = before, after = after }
            """,
            setup_opts="{ backend = 'lua' }",
        )
        self.assertEqual(result["before"], 1)
        self.assertEqual(result["after"], 0)

    def test_rewrite_last_search_retargets_current_word(self):
        result = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'foo one', 'bar one', 'bar two' })
            vim.api.nvim_win_set_cursor(0, { 1, 1 })
            local a = require('multi_cursor.actions')
            local s = require('multi_cursor.state')
            a.find_under()
            vim.api.nvim_win_set_cursor(0, { 2, 1 })
            a.rewrite_last_search()
            a.find_next(false)
            local st = s.current()
            return {
              pat = st.search[1] or '',
              total = #st.cursors,
            }
            """,
            setup_opts="{ backend = 'lua' }",
        )
        self.assertIn("bar", result["pat"])
        self.assertEqual(result["total"], 2)

    def test_native_yy_overrides_stale_multicursor_cache_for_p(self):
        result = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'foo', 'bar' })
            local s = require('multi_cursor.state')
            s.registers['"'] = { items = { 'OLD1', 'OLD2' }, kind = 'line' }
            vim.api.nvim_win_set_cursor(0, { 1, 0 })
            vim.cmd('normal! yy')
            vim.api.nvim_win_set_cursor(0, { 2, 0 })
            local keys = vim.api.nvim_replace_termcodes('p', true, false, true)
            vim.api.nvim_feedkeys(keys, 'mtx', false)
            vim.cmd('redraw')
            return { lines = vim.api.nvim_buf_get_lines(0, 0, -1, false) }
            """,
            setup_opts="{ backend = 'lua' }",
        )
        self.assertEqual(result["lines"], ["foo", "bar", "foo"])

    def test_multicursor_paste_uses_native_register_after_yy(self):
        result = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'foo', 'bar' })
            local a = require('multi_cursor.actions')
            local s = require('multi_cursor.state')
            s.registers['"'] = { items = { 'OLD1', 'OLD2' }, kind = 'line' }
            vim.api.nvim_win_set_cursor(0, { 1, 0 })
            a.add_cursor_vertical(1, 1)
            vim.api.nvim_win_set_cursor(0, { 1, 0 })
            vim.cmd('normal! yy')
            a.paste_multicursor(true)
            return { lines = vim.api.nvim_buf_get_lines(0, 0, -1, false) }
            """,
            setup_opts="{ backend = 'lua' }",
        )
        self.assertEqual(result["lines"], ["foo", "foo", "bar", "foo"])

    def test_health_module_and_conflict_command_exist(self):
        result = self.run_case(
            """
            local ok, mod = pcall(require, 'multi_cursor.health')
            return {
              has_module = ok and type(mod.check) == 'function',
              has_cmd = vim.fn.exists(':MultiCursorMappingConflicts') == 2,
            }
            """,
            setup_opts="{ backend = 'lua' }",
        )
        self.assertTrue(result["has_module"])
        self.assertTrue(result["has_cmd"])

    def test_native_insert_mode_word_motions(self):
        result = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'foo bar baz', 'zip zap zip' })
            vim.api.nvim_win_set_cursor(0, { 1, 4 })
            local a = require('multi_cursor.actions')
            local s = require('multi_cursor.state')
            a.add_cursor_vertical(1, 1)
            a.begin_insert('insert')
            a.apply_insert_special_now('word_right')
            local st = s.current()
            local p1 = s.cursor_pos(st, st.current)
            a.apply_insert_special_now('word_left')
            local p2 = s.cursor_pos(st, st.current)
            a.end_insert()
            return {
              after_right = { row = p1.row, col = p1.col },
              after_left = { row = p2.row, col = p2.col },
            }
            """,
            setup_opts="{ backend = 'lua', insert_mode = 'native' }",
        )
        self.assertEqual(result["after_right"]["col"], 7)
        self.assertEqual(result["after_left"]["col"], 4)

    def test_extend_mode_motion_preserves_anchor(self):
        result = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'foo bar', 'zip zap' })
            vim.api.nvim_win_set_cursor(0, { 1, 0 })
            local a = require('multi_cursor.actions')
            local s = require('multi_cursor.state')
            a.add_cursor_vertical(1, 1)
            a.toggle_mode()
            a.apply_mapped_motion('w', 'w')
            local st = s.current()
            local p1 = s.cursor_pos(st, 1)
            local p2 = s.cursor_pos(st, 2)
            return {
              mode = st.mode,
              p1 = { col = p1.col, acol = p1.acol },
              p2 = { col = p2.col, acol = p2.acol },
            }
            """,
            setup_opts="{ backend = 'lua' }",
        )
        self.assertEqual(result["mode"], "extend")
        self.assertNotEqual(result["p1"]["col"], result["p1"]["acol"])
        self.assertNotEqual(result["p2"]["col"], result["p2"]["acol"])

    def test_mapped_motion_f_char_applies_per_cursor_line(self):
        result = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'aa=1', 'bb=2' })
            vim.api.nvim_win_set_cursor(0, { 1, 0 })
            local a = require('multi_cursor.actions')
            local s = require('multi_cursor.state')
            a.add_cursor_vertical(1, 1)
            vim.fn.getchar = function() return string.byte('=') end
            a.apply_mapped_motion('f', 'f')
            local st = s.current()
            local p1 = s.cursor_pos(st, 1)
            local p2 = s.cursor_pos(st, 2)
            return { c1 = p1.col, c2 = p2.col }
            """,
            setup_opts="{ backend = 'lua' }",
        )
        self.assertEqual(result["c1"], 2)
        self.assertEqual(result["c2"], 2)

    def test_mapped_motion_t_char_applies_per_cursor_line(self):
        result = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'aa=1', 'bb=2' })
            vim.api.nvim_win_set_cursor(0, { 1, 0 })
            local a = require('multi_cursor.actions')
            local s = require('multi_cursor.state')
            a.add_cursor_vertical(1, 1)
            vim.fn.getchar = function() return string.byte('=') end
            a.apply_mapped_motion('t', 't')
            local st = s.current()
            local p1 = s.cursor_pos(st, 1)
            local p2 = s.cursor_pos(st, 2)
            return { c1 = p1.col, c2 = p2.col }
            """,
            setup_opts="{ backend = 'lua' }",
        )
        self.assertEqual(result["c1"], 1)
        self.assertEqual(result["c2"], 1)

    def test_extend_mode_yank_collects_all_regions(self):
        result = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'foo bar', 'zip zap' })
            vim.api.nvim_win_set_cursor(0, { 1, 0 })
            local a = require('multi_cursor.actions')
            local s = require('multi_cursor.state')
            a.add_cursor_vertical(1, 1)
            a.toggle_mode()
            a.apply_mapped_motion('w', 'w')
            a.yank()
            local reg = s.registers['"'] or { items = {} }
            return { n = #reg.items, first = reg.items[1] or '', second = reg.items[2] or '' }
            """,
            setup_opts="{ backend = 'lua' }",
        )
        self.assertEqual(result["n"], 2)
        self.assertNotEqual(result["first"], "")
        self.assertNotEqual(result["second"], "")

    def test_extend_mode_yank_matches_exact_selected_range(self):
        result = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'abcd', 'wxyz' })
            vim.api.nvim_win_set_cursor(0, { 1, 0 })
            local a = require('multi_cursor.actions')
            local s = require('multi_cursor.state')
            a.add_cursor_vertical(1, 1)
            a.toggle_mode()
            a.shift_selection(2)
            a.yank()
            local reg = s.registers['"'] or { items = {} }
            return { first = reg.items[1] or '', second = reg.items[2] or '' }
            """,
            setup_opts="{ backend = 'lua' }",
        )
        self.assertEqual(result["first"], "abc")
        self.assertEqual(result["second"], "wxy")

    def test_extend_yank_and_delete_use_same_selection_bounds(self):
        result = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'abcd', 'wxyz' })
            vim.api.nvim_win_set_cursor(0, { 1, 0 })
            local a = require('multi_cursor.actions')
            local s = require('multi_cursor.state')
            a.add_cursor_vertical(1, 1)
            a.toggle_mode()
            a.shift_selection(2)
            a.yank()
            local y = s.registers['"'] or { items = {} }
            local y1, y2 = y.items[1] or '', y.items[2] or ''
            a.delete_regions()
            return {
              y1 = y1,
              y2 = y2,
              lines = vim.api.nvim_buf_get_lines(0, 0, -1, false),
            }
            """,
            setup_opts="{ backend = 'lua' }",
        )
        self.assertEqual(result["y1"], "abc")
        self.assertEqual(result["y2"], "wxy")
        self.assertEqual(result["lines"], ["d", "z"])

    def test_operator_yiw_uses_multicursor_register(self):
        result = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'foo bar', 'zip zap' })
            vim.api.nvim_win_set_cursor(0, { 1, 0 })
            local a = require('multi_cursor.actions')
            local s = require('multi_cursor.state')
            a.add_cursor_vertical(1, 1)
            a.operator_with_motion('y', 'iw')
            local reg = s.registers['"'] or { items = {} }
            return { n = #reg.items, first = reg.items[1] or '', second = reg.items[2] or '' }
            """,
            setup_opts="{ backend = 'lua' }",
        )
        self.assertEqual(result["n"], 2)
        self.assertEqual(result["first"], "foo")
        self.assertEqual(result["second"], "zip")

    def test_operator_diw_updates_multicursor_register(self):
        result = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'foo bar', 'zip zap' })
            vim.api.nvim_win_set_cursor(0, { 1, 0 })
            local a = require('multi_cursor.actions')
            local s = require('multi_cursor.state')
            a.add_cursor_vertical(1, 1)
            a.operator_with_motion('d', 'iw')
            local reg = s.registers['"'] or { items = {} }
            return {
              lines = vim.api.nvim_buf_get_lines(0, 0, -1, false),
              n = #reg.items,
              first = reg.items[1] or '',
              second = reg.items[2] or '',
            }
            """,
            setup_opts="{ backend = 'lua' }",
        )
        self.assertEqual(result["lines"], [" bar", " zap"])
        self.assertEqual(result["n"], 2)
        self.assertEqual(result["first"], "foo")
        self.assertEqual(result["second"], "zip")

    def test_keymap_ciw_enters_multicursor_insert_and_captures_all_regions(self):
        result = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'foo bar', 'zip zap' })
            vim.api.nvim_win_set_cursor(0, { 1, 0 })
            local a = require('multi_cursor.actions')
            local s = require('multi_cursor.state')
            local k = require('multi_cursor.keymaps')
            k.setup()
            a.add_cursor_vertical(1, 1)
            a.operator_with_motion('c', 'iw')
            local st = s.current()
            local reg = s.registers['"'] or { items = {} }
            return {
              active = st.insert_active,
              mode = st.mode,
              n = #reg.items,
              first = reg.items[1] or '',
              second = reg.items[2] or '',
              lines = vim.api.nvim_buf_get_lines(0, 0, -1, false),
            }
            """,
            setup_opts="{ backend = 'lua', insert_mode = 'native' }",
        )
        self.assertTrue(result["active"])
        self.assertEqual(result["mode"], "cursor")
        self.assertEqual(result["n"], 2)
        self.assertEqual(result["first"], "foo")
        self.assertEqual(result["second"], "zip")
        self.assertEqual(result["lines"], [" bar", " zap"])

    def test_manual_extend_delete_keeps_selected_endpoint(self):
        result = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'abcd', 'wxyz' })
            vim.api.nvim_win_set_cursor(0, { 1, 0 })
            local a = require('multi_cursor.actions')
            local s = require('multi_cursor.state')
            a.add_cursor_vertical(1, 1)
            a.toggle_mode()
            a.apply_mapped_motion('l', 'l')
            a.apply_mapped_motion('l', 'l')
            a.yank_exact_selection(true)
            a.delete_regions()
            local reg = s.registers['"'] or { items = {} }
            return {
              first = reg.items[1] or '',
              second = reg.items[2] or '',
              lines = vim.api.nvim_buf_get_lines(0, 0, -1, false),
            }
            """,
            setup_opts="{ backend = 'lua' }",
        )
        self.assertEqual(result["first"], "abc")
        self.assertEqual(result["second"], "wxy")
        self.assertEqual(result["lines"], ["d", "z"])

    def test_extend_delete_yanks_before_deleting(self):
        result = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { '<foo> bar', '<zip> zap' })
            vim.api.nvim_win_set_cursor(0, { 1, 1 })
            local a = require('multi_cursor.actions')
            local s = require('multi_cursor.state')
            a.add_cursor_vertical(1, 1)
            a.select_operator_with_motion('i<')
            a.operator_with_motion('d', 'iw')
            local reg = s.registers['"'] or { items = {} }
            return {
              lines = vim.api.nvim_buf_get_lines(0, 0, -1, false),
              n = #reg.items,
              first = reg.items[1] or '',
              second = reg.items[2] or '',
            }
            """,
            setup_opts="{ backend = 'lua' }",
        )
        self.assertEqual(result["lines"], ["<> bar", "<> zap"])
        self.assertEqual(result["n"], 2)
        self.assertEqual(result["first"], "foo")
        self.assertEqual(result["second"], "zip")

    def test_extend_change_yanks_exact_deleted_text(self):
        result = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { '<foo> bar', '<zip> zap' })
            vim.api.nvim_win_set_cursor(0, { 1, 1 })
            local a = require('multi_cursor.actions')
            local s = require('multi_cursor.state')
            a.add_cursor_vertical(1, 1)
            a.select_operator_with_motion('i<')
            a.change_regions('X')
            local reg = s.registers['"'] or { items = {} }
            return {
              lines = vim.api.nvim_buf_get_lines(0, 0, -1, false),
              n = #reg.items,
              first = reg.items[1] or '',
              second = reg.items[2] or '',
            }
            """,
            setup_opts="{ backend = 'lua' }",
        )
        self.assertEqual(result["lines"], ["<X> bar", "<X> zap"])
        self.assertEqual(result["n"], 2)
        self.assertEqual(result["first"], "foo")
        self.assertEqual(result["second"], "zip")

    def test_unnamed_delete_rotates_numbered_registers(self):
        result = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'foo bar', 'zip zap' })
            vim.api.nvim_win_set_cursor(0, { 1, 0 })
            local a = require('multi_cursor.actions')
            local s = require('multi_cursor.state')
            a.add_cursor_vertical(1, 1)
            a.operator_with_motion('d', 'iw')
            a.clear()
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'bar', 'zap' })
            vim.api.nvim_win_set_cursor(0, { 1, 0 })
            a.add_cursor_vertical(1, 1)
            a.operator_with_motion('d', 'iw')

            local r1 = s.registers['1'] or { items = {} }
            local r2 = s.registers['2'] or { items = {} }
            local v1 = vim.fn.getreg('1', 1, true)
            local v2 = vim.fn.getreg('2', 1, true)
            return {
              lines = vim.api.nvim_buf_get_lines(0, 0, -1, false),
              r1n = #r1.items,
              r2n = #r2.items,
              r1a = r1.items[1] or '',
              r1b = r1.items[2] or '',
              r2a = r2.items[1] or '',
              r2b = r2.items[2] or '',
              v1a = (type(v1) == 'table' and v1[1]) or '',
              v1b = (type(v1) == 'table' and v1[2]) or '',
              v2a = (type(v2) == 'table' and v2[1]) or '',
              v2b = (type(v2) == 'table' and v2[2]) or '',
            }
            """,
            setup_opts="{ backend = 'lua' }",
        )
        self.assertEqual(result["lines"], ["", ""])
        self.assertEqual(result["r1n"], 2)
        self.assertEqual(result["r2n"], 2)
        self.assertEqual(result["r1a"], "bar")
        self.assertEqual(result["r1b"], "zap")
        self.assertEqual(result["r2a"], "foo")
        self.assertEqual(result["r2b"], "zip")
        self.assertEqual(result["v1a"], "bar")
        self.assertEqual(result["v1b"], "zap")
        self.assertEqual(result["v2a"], "foo")
        self.assertEqual(result["v2b"], "zip")

    def test_unnamed_change_rotates_numbered_registers(self):
        result = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { '<foo> bar', '<zip> zap' })
            vim.api.nvim_win_set_cursor(0, { 1, 1 })
            local a = require('multi_cursor.actions')
            local s = require('multi_cursor.state')
            a.add_cursor_vertical(1, 1)
            a.select_operator_with_motion('i<')
            a.change_regions('X')
            local r1 = s.registers['1'] or { items = {} }
            local v1 = vim.fn.getreg('1', 1, true)
            return {
              lines = vim.api.nvim_buf_get_lines(0, 0, -1, false),
              r1a = r1.items[1] or '',
              r1b = r1.items[2] or '',
              v1a = (type(v1) == 'table' and v1[1]) or '',
              v1b = (type(v1) == 'table' and v1[2]) or '',
            }
            """,
            setup_opts="{ backend = 'lua' }",
        )
        self.assertEqual(result["lines"], ["<X> bar", "<X> zap"])
        self.assertEqual(result["r1a"], "foo")
        self.assertEqual(result["r1b"], "zip")
        self.assertEqual(result["v1a"], "foo")
        self.assertEqual(result["v1b"], "zip")

    def test_operator_yiw_restores_cursor_to_start_of_text_object(self):
        result = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'foo bar', 'zip zap' })
            vim.api.nvim_win_set_cursor(0, { 1, 0 })
            local a = require('multi_cursor.actions')
            local s = require('multi_cursor.state')
            a.add_cursor_vertical(1, 1)
            a.operator_with_motion('y', 'iw')
            local st = s.current()
            local p1 = s.cursor_pos(st, 1)
            local p2 = s.cursor_pos(st, 2)
            return { mode = st.mode, p1 = p1, p2 = p2 }
            """,
            setup_opts="{ backend = 'lua' }",
        )
        self.assertEqual(result["mode"], "cursor")
        self.assertEqual(result["p1"]["col"], 0)
        self.assertEqual(result["p2"]["col"], 0)

    def test_multicursor_charwise_p_and_P_differ(self):
        result = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'ab', 'cd' })
            vim.api.nvim_win_set_cursor(0, { 1, 0 })
            local a = require('multi_cursor.actions')
            local s = require('multi_cursor.state')
            a.add_cursor_vertical(1, 1)
            s.registers['"'] = { items = { 'X', 'Y' }, kind = 'char' }
            a.paste_multicursor(true)
            local after_lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'ab', 'cd' })
            vim.api.nvim_win_set_cursor(0, { 1, 0 })
            a.clear()
            a.add_cursor_vertical(1, 1)
            s.registers['"'] = { items = { 'X', 'Y' }, kind = 'char' }
            a.paste_multicursor(false)
            local before_lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
            return { after = after_lines, before = before_lines }
            """,
            setup_opts="{ backend = 'lua' }",
        )
        self.assertEqual(result["after"], ["aXb", "cYd"])
        self.assertEqual(result["before"], ["Xab", "Ycd"])

    def test_single_cursor_charwise_p_and_P_differ_and_move_cursor(self):
        result = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'ab' })
            vim.api.nvim_win_set_cursor(0, { 1, 0 })
            local a = require('multi_cursor.actions')
            local s = require('multi_cursor.state')

            s.registers['"'] = { items = { 'X', 'Y' }, kind = 'char' }
            a.paste_single_cursor(true)
            local after_lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
            local after_cur = vim.api.nvim_win_get_cursor(0)

            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'ab' })
            vim.api.nvim_win_set_cursor(0, { 1, 0 })
            s.registers['"'] = { items = { 'X', 'Y' }, kind = 'char' }
            a.paste_single_cursor(false)
            local before_lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
            local before_cur = vim.api.nvim_win_get_cursor(0)

            return {
              after = after_lines,
              before = before_lines,
              after_row = after_cur[1], after_col = after_cur[2],
              before_row = before_cur[1], before_col = before_cur[2],
            }
            """,
            setup_opts="{ backend = 'lua' }",
        )
        self.assertEqual(result["after"], ["aX", "Yb"])
        self.assertEqual(result["before"], ["X", "Yab"])
        self.assertEqual(result["after_row"], 2)
        self.assertEqual(result["after_col"], 1)
        self.assertEqual(result["before_row"], 2)
        self.assertEqual(result["before_col"], 1)

    def test_named_register_paste_via_pending_register(self):
        result = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'target' })
            vim.api.nvim_win_set_cursor(0, { 1, 0 })
            local s = require('multi_cursor.state')
            local a = require('multi_cursor.actions')
            vim.fn.setreg('a', { 'one', 'two' }, 'V')
            s.current().pending_register = 'a'
            a.paste_single_cursor(true)
            return { lines = vim.api.nvim_buf_get_lines(0, 0, -1, false) }
            """,
            setup_opts="{ backend = 'lua' }",
        )
        self.assertEqual(result["lines"], ["target", "one", "two"])

    def test_append_register_yank_via_pending_register(self):
        result = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'foo bar', 'zip zap' })
            vim.api.nvim_win_set_cursor(0, { 1, 0 })
            vim.fn.setreg('a', { 'X', 'Y' }, 'v')
            local a = require('multi_cursor.actions')
            local s = require('multi_cursor.state')
            a.add_cursor_vertical(1, 1)
            s.current().pending_register = 'A'
            a.operator_with_motion('y', 'iw')
            local ra = vim.fn.getreg('a', 1, true)
            return {
              a1 = (type(ra) == 'table' and ra[1]) or '',
              a2 = (type(ra) == 'table' and ra[2]) or '',
            }
            """,
            setup_opts="{ backend = 'lua' }",
        )
        self.assertEqual(result["a1"], "Xfoo")
        self.assertEqual(result["a2"], "Yzip")

    def test_black_hole_delete_does_not_touch_unnamed_register(self):
        result = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'foo bar', 'zip zap' })
            vim.api.nvim_win_set_cursor(0, { 1, 0 })
            vim.fn.setreg('\"', { 'keep1', 'keep2' }, 'V')
            local a = require('multi_cursor.actions')
            local s = require('multi_cursor.state')
            s.registers['\"'] = { items = { 'keep1', 'keep2' }, kind = 'line' }
            a.add_cursor_vertical(1, 1)
            s.current().pending_register = '_'
            a.operator_with_motion('d', 'iw')
            local unnamed = vim.fn.getreg('\"', 1, true)
            local reg = s.registers['\"'] or { items = {} }
            return {
              lines = vim.api.nvim_buf_get_lines(0, 0, -1, false),
              u1 = (type(unnamed) == 'table' and unnamed[1]) or '',
              u2 = (type(unnamed) == 'table' and unnamed[2]) or '',
              r1 = reg.items[1] or '',
              r2 = reg.items[2] or '',
            }
            """,
            setup_opts="{ backend = 'lua' }",
        )
        self.assertEqual(result["lines"], [" bar", " zap"])
        self.assertEqual(result["u1"], "keep1")
        self.assertEqual(result["u2"], "keep2")
        self.assertEqual(result["r1"], "keep1")
        self.assertEqual(result["r2"], "keep2")

    def test_pending_register_is_consumed_once(self):
        result = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'foo bar', 'zip zap' })
            vim.api.nvim_win_set_cursor(0, { 1, 0 })
            local a = require('multi_cursor.actions')
            local s = require('multi_cursor.state')
            a.add_cursor_vertical(1, 1)
            s.current().pending_register = 'a'
            a.operator_with_motion('y', 'iw')
            local after_first = s.current().pending_register
            a.apply_normal('w', false)
            a.operator_with_motion('y', 'iw')
            local ra = s.registers['a'] or { items = {} }
            local rd = s.registers['"'] or { items = {} }
            return {
              consumed = after_first == nil,
              a1 = ra.items[1] or '',
              a2 = ra.items[2] or '',
              d1 = rd.items[1] or '',
              d2 = rd.items[2] or '',
            }
            """,
            setup_opts="{ backend = 'lua' }",
        )
        self.assertTrue(result["consumed"])
        self.assertEqual(result["a1"], "foo")
        self.assertEqual(result["a2"], "zip")
        self.assertEqual(result["d1"], "bar")
        self.assertEqual(result["d2"], "zap")

    def test_extend_delete_named_register_updates_named_and_default(self):
        result = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { '<foo> bar', '<zip> zap' })
            vim.api.nvim_win_set_cursor(0, { 1, 1 })
            local a = require('multi_cursor.actions')
            local s = require('multi_cursor.state')
            a.add_cursor_vertical(1, 1)
            a.select_operator_with_motion('i<')
            s.current().pending_register = 'a'
            a.operator_with_motion('d', 'iw')
            local ra = s.registers['a'] or { items = {} }
            local rd = s.registers['"'] or { items = {} }
            return {
              lines = vim.api.nvim_buf_get_lines(0, 0, -1, false),
              a1 = ra.items[1] or '',
              a2 = ra.items[2] or '',
              d1 = rd.items[1] or '',
              d2 = rd.items[2] or '',
            }
            """,
            setup_opts="{ backend = 'lua' }",
        )
        self.assertEqual(result["lines"], ["<> bar", "<> zap"])
        self.assertEqual(result["a1"], "foo")
        self.assertEqual(result["a2"], "zip")
        self.assertEqual(result["d1"], "foo")
        self.assertEqual(result["d2"], "zip")

    def test_extend_change_black_hole_keeps_unnamed(self):
        result = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { '<foo> bar', '<zip> zap' })
            vim.api.nvim_win_set_cursor(0, { 1, 1 })
            vim.fn.setreg('\"', { 'keep1', 'keep2' }, 'V')
            local a = require('multi_cursor.actions')
            local s = require('multi_cursor.state')
            s.registers['\"'] = { items = { 'keep1', 'keep2' }, kind = 'line' }
            a.add_cursor_vertical(1, 1)
            a.select_operator_with_motion('i<')
            s.current().pending_register = '_'
            a.change_regions('X')
            local unnamed = vim.fn.getreg('\"', 1, true)
            local rd = s.registers['"'] or { items = {} }
            return {
              lines = vim.api.nvim_buf_get_lines(0, 0, -1, false),
              u1 = (type(unnamed) == 'table' and unnamed[1]) or '',
              u2 = (type(unnamed) == 'table' and unnamed[2]) or '',
              d1 = rd.items[1] or '',
              d2 = rd.items[2] or '',
            }
            """,
            setup_opts="{ backend = 'lua' }",
        )
        self.assertEqual(result["lines"], ["<X> bar", "<X> zap"])
        self.assertEqual(result["u1"], "keep1")
        self.assertEqual(result["u2"], "keep2")
        self.assertEqual(result["d1"], "keep1")
        self.assertEqual(result["d2"], "keep2")

    def test_clipboard_plus_register_paste_via_pending_register(self):
        result = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'target' })
            vim.api.nvim_win_set_cursor(0, { 1, 0 })
            local s = require('multi_cursor.state')
            local a = require('multi_cursor.actions')
            s.registers['+'] = { items = { 'one', 'two' }, kind = 'line' }
            s.current().pending_register = '+'
            a.paste_single_cursor(true)
            return {
              lines = vim.api.nvim_buf_get_lines(0, 0, -1, false),
            }
            """,
            setup_opts="{ backend = 'lua' }",
        )
        self.assertEqual(result["lines"], ["target", "one", "two"])

    def test_clipboard_plus_register_yank_via_pending_register(self):
        result = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'foo bar', 'zip zap' })
            vim.api.nvim_win_set_cursor(0, { 1, 0 })
            local a = require('multi_cursor.actions')
            local s = require('multi_cursor.state')
            a.add_cursor_vertical(1, 1)
            s.current().pending_register = '+'
            a.operator_with_motion('y', 'iw')
            local rp = s.registers['+'] or { items = {} }
            return {
              p1 = rp.items[1] or '',
              p2 = rp.items[2] or '',
            }
            """,
            setup_opts="{ backend = 'lua' }",
        )
        self.assertEqual(result["p1"], "foo")
        self.assertEqual(result["p2"], "zip")

    def test_clipboard_star_register_paste_via_pending_register(self):
        result = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'target' })
            vim.api.nvim_win_set_cursor(0, { 1, 0 })
            local s = require('multi_cursor.state')
            local a = require('multi_cursor.actions')
            s.registers['*'] = { items = { 'red', 'blue' }, kind = 'line' }
            s.current().pending_register = '*'
            a.paste_single_cursor(true)
            return {
              lines = vim.api.nvim_buf_get_lines(0, 0, -1, false),
            }
            """,
            setup_opts="{ backend = 'lua' }",
        )
        self.assertEqual(result["lines"], ["target", "red", "blue"])

    def test_keymap_operator_count_dw_applies_to_each_cursor(self):
        result = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'foo bar baz', 'foo bar baz' })
            vim.api.nvim_win_set_cursor(0, { 1, 0 })
            local a = require('multi_cursor.actions')
            a.add_cursor_vertical(1, 1)
            local keys = vim.api.nvim_replace_termcodes('2dw', true, false, true)
            vim.api.nvim_feedkeys(keys, 'mtx', false)
            vim.cmd('redraw')
            return { lines = vim.api.nvim_buf_get_lines(0, 0, -1, false) }
            """,
            setup_opts="{ backend = 'lua' }",
        )
        self.assertEqual(result["lines"], ["baz", "baz"])

    def test_keymap_paste_count_multicursor(self):
        result = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'ab', 'cd' })
            vim.api.nvim_win_set_cursor(0, { 1, 0 })
            local a = require('multi_cursor.actions')
            local s = require('multi_cursor.state')
            a.add_cursor_vertical(1, 1)
            s.registers['"'] = { items = { 'X', 'Y' }, kind = 'char' }
            local keys = vim.api.nvim_replace_termcodes('2p', true, false, true)
            vim.api.nvim_feedkeys(keys, 'mtx', false)
            vim.cmd('redraw')
            return { lines = vim.api.nvim_buf_get_lines(0, 0, -1, false) }
            """,
            setup_opts="{ backend = 'lua' }",
        )
        self.assertEqual(result["lines"], ["aXXb", "cYYd"])

    def test_run_dot_repeats_operator_delete_motion(self):
        result = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'foo bar baz', 'foo bar baz' })
            vim.api.nvim_win_set_cursor(0, { 1, 0 })
            local a = require('multi_cursor.actions')
            a.add_cursor_vertical(1, 1)
            a.operator_with_motion('d', 'w')
            a.run_dot()
            return { lines = vim.api.nvim_buf_get_lines(0, 0, -1, false) }
            """,
            setup_opts="{ backend = 'lua' }",
        )
        self.assertEqual(result["lines"], ["baz", "baz"])

    def test_run_dot_repeats_multicursor_paste(self):
        result = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'ab', 'cd' })
            vim.api.nvim_win_set_cursor(0, { 1, 0 })
            local a = require('multi_cursor.actions')
            local s = require('multi_cursor.state')
            a.add_cursor_vertical(1, 1)
            s.registers['"'] = { items = { 'X', 'Y' }, kind = 'char' }
            a.paste_multicursor(true)
            a.run_dot()
            return { lines = vim.api.nvim_buf_get_lines(0, 0, -1, false) }
            """,
            setup_opts="{ backend = 'lua' }",
        )
        self.assertEqual(result["lines"], ["aXXb", "cYYd"])

    def test_multicursor_delete_is_single_undo_step(self):
        result = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'foo bar baz', 'foo bar baz' })
            local ul = vim.o.undolevels
            vim.o.undolevels = -1
            vim.o.undolevels = ul
            vim.api.nvim_win_set_cursor(0, { 1, 0 })
            local a = require('multi_cursor.actions')
            a.add_cursor_vertical(1, 1)
            a.operator_with_motion('d', 'w')
            vim.cmd.undo()
            return { lines = vim.api.nvim_buf_get_lines(0, 0, -1, false) }
            """,
            setup_opts="{ backend = 'lua' }",
        )
        self.assertEqual(result["lines"], ["foo bar baz", "foo bar baz"])

    def test_multicursor_paste_is_single_undo_step(self):
        result = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'ab', 'cd' })
            local ul = vim.o.undolevels
            vim.o.undolevels = -1
            vim.o.undolevels = ul
            vim.api.nvim_win_set_cursor(0, { 1, 0 })
            local a = require('multi_cursor.actions')
            local s = require('multi_cursor.state')
            a.add_cursor_vertical(1, 1)
            s.registers['"'] = { items = { 'X', 'Y' }, kind = 'char' }
            a.paste_multicursor(true)
            vim.cmd.undo()
            return { lines = vim.api.nvim_buf_get_lines(0, 0, -1, false) }
            """,
            setup_opts="{ backend = 'lua' }",
        )
        self.assertEqual(result["lines"], ["ab", "cd"])

    def test_run_normal_is_single_undo_step(self):
        result = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'aa', 'bb' })
            local ul = vim.o.undolevels
            vim.o.undolevels = -1
            vim.o.undolevels = ul
            vim.api.nvim_win_set_cursor(0, { 1, 0 })
            local a = require('multi_cursor.actions')
            a.add_cursor_vertical(1, 1)
            a.run_normal('A!')
            vim.cmd.undo()
            return { lines = vim.api.nvim_buf_get_lines(0, 0, -1, false) }
            """,
            setup_opts="{ backend = 'lua' }",
        )
        self.assertEqual(result["lines"], ["aa", "bb"])

    def test_run_dot_repeats_extend_delete_from_keymap_path(self):
        result = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'foo bar baz', 'foo bar baz' })
            vim.api.nvim_win_set_cursor(0, { 1, 0 })
            local a = require('multi_cursor.actions')
            a.add_cursor_vertical(1, 1)
            a.select_operator_with_motion('iw')
            local d = vim.api.nvim_replace_termcodes('d', true, false, true)
            vim.api.nvim_feedkeys(d, 'mtx', false)
            vim.cmd('redraw')
            a.apply_normal('w', false)
            a.select_operator_with_motion('iw')
            a.run_dot()
            return { lines = vim.api.nvim_buf_get_lines(0, 0, -1, false) }
            """,
            setup_opts="{ backend = 'lua' }",
        )
        self.assertEqual(result["lines"], ["  baz", "  baz"])

    def test_case_convert_cursor_mode_preserves_default_register(self):
        result = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'foo bar', 'foo baz' })
            vim.api.nvim_win_set_cursor(0, { 1, 0 })
            vim.fn.setreg('\"', { 'keep1', 'keep2' }, 'V')
            local a = require('multi_cursor.actions')
            local s = require('multi_cursor.state')
            s.registers['\"'] = { items = { 'keep1', 'keep2' }, kind = 'line' }
            a.add_cursor_vertical(1, 1)
            a.case_convert('upper')
            local st = s.current()
            local reg = s.registers['\"'] or { items = {} }
            local unnamed = vim.fn.getreg('\"', 1, true)
            return {
              mode = st.mode,
              lines = vim.api.nvim_buf_get_lines(0, 0, -1, false),
              r1 = reg.items[1] or '',
              r2 = reg.items[2] or '',
              u1 = (type(unnamed) == 'table' and unnamed[1]) or '',
              u2 = (type(unnamed) == 'table' and unnamed[2]) or '',
            }
            """,
            setup_opts="{ backend = 'lua' }",
        )
        self.assertEqual(result["mode"], "cursor")
        self.assertEqual(result["lines"], ["FOO bar", "FOO baz"])
        self.assertEqual(result["r1"], "keep1")
        self.assertEqual(result["r2"], "keep2")
        self.assertEqual(result["u1"], "keep1")
        self.assertEqual(result["u2"], "keep2")

    def test_case_convert_extend_mode_exits_to_cursor(self):
        result = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { '<foo> bar', '<zip> zap' })
            vim.api.nvim_win_set_cursor(0, { 1, 1 })
            local a = require('multi_cursor.actions')
            local s = require('multi_cursor.state')
            a.add_cursor_vertical(1, 1)
            a.select_operator_with_motion('i<')
            a.case_convert('upper')
            local st = s.current()
            return {
              mode = st.mode,
              lines = vim.api.nvim_buf_get_lines(0, 0, -1, false),
            }
            """,
            setup_opts="{ backend = 'lua' }",
        )
        self.assertEqual(result["mode"], "cursor")
        self.assertEqual(result["lines"], ["<FOO> bar", "<ZIP> zap"])

    def test_swap_case_in_extend_mode_toggles_full_selection(self):
        result = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'abc', 'xyz' })
            vim.api.nvim_win_set_cursor(0, { 1, 0 })
            local a = require('multi_cursor.actions')
            local k = require('multi_cursor.keymaps')
            k.setup()
            a.add_cursor_vertical(1, 1)
            a.toggle_mode()
            a.shift_selection(2)
            vim.cmd.normal({ args = { '~' }, bang = false })
            return { lines = vim.api.nvim_buf_get_lines(0, 0, -1, false) }
            """,
            setup_opts="{ backend = 'lua' }",
        )
        self.assertEqual(result["lines"], ["ABC", "XYZ"])

    def test_case_conversion_menu_choice_applies_conversion(self):
        result = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'hello world', 'next item' })
            vim.api.nvim_win_set_cursor(0, { 1, 0 })
            local a = require('multi_cursor.actions')
            a.add_cursor_vertical(1, 1)
            a.case_conversion_menu('upper')
            return { lines = vim.api.nvim_buf_get_lines(0, 0, -1, false) }
            """,
            setup_opts="{ backend = 'lua' }",
        )
        self.assertEqual(result["lines"], ["HELLO world", "NEXT item"])

    def test_case_conversion_ignores_single_region_scope(self):
        result = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'foo one', 'bar two' })
            vim.api.nvim_win_set_cursor(0, { 1, 0 })
            local a = require('multi_cursor.actions')
            local s = require('multi_cursor.state')
            a.add_cursor_vertical(1, 1)
            local st = s.current()
            st.single_region = true
            st.current = 2
            a.case_conversion_menu('upper')
            return {
              lines = vim.api.nvim_buf_get_lines(0, 0, -1, false),
              single = st.single_region,
            }
            """,
            setup_opts="{ backend = 'lua' }",
        )
        self.assertEqual(result["lines"], ["FOO one", "BAR two"])
        self.assertTrue(result["single"])

    def test_case_conversion_menu_in_extend_mode_applies_all_regions(self):
        result = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'foo bar', 'zip zap' })
            vim.api.nvim_win_set_cursor(0, { 1, 0 })
            local a = require('multi_cursor.actions')
            a.add_cursor_vertical(1, 1)
            a.toggle_mode()
            a.shift_selection(2)
            a.case_conversion_menu('upper')
            return { lines = vim.api.nvim_buf_get_lines(0, 0, -1, false) }
            """,
            setup_opts="{ backend = 'lua' }",
        )
        self.assertEqual(result["lines"], ["FOO bar", "ZIP zap"])

    def test_case_convert_cursor_mode_on_symbol_column_targets_next_keyword(self):
        result = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, {
              '---@class MultiCursorCursorMark',
              '---@field id integer',
              '---@field anchor_id integer',
            })
            vim.api.nvim_win_set_cursor(0, { 1, 3 }) -- on '@'
            local a = require('multi_cursor.actions')
            a.add_cursor_vertical(1, 2)
            a.case_convert('upper')
            return { lines = vim.api.nvim_buf_get_lines(0, 0, -1, false) }
            """,
            setup_opts="{ backend = 'lua' }",
        )
        self.assertEqual(result["lines"][0], "---@CLASS MultiCursorCursorMark")
        self.assertEqual(result["lines"][1], "---@FIELD id integer")
        self.assertEqual(result["lines"][2], "---@FIELD anchor_id integer")

    def test_case_convert_extend_mode_without_selection_falls_back_to_words(self):
        result = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'foo bar', 'zip zap', 'abc def' })
            vim.api.nvim_win_set_cursor(0, { 1, 0 })
            local a = require('multi_cursor.actions')
            a.add_cursor_vertical(1, 2)
            a.toggle_mode() -- extend mode, but no visual width yet
            a.case_conversion_menu('upper')
            return { lines = vim.api.nvim_buf_get_lines(0, 0, -1, false) }
            """,
            setup_opts="{ backend = 'lua' }",
        )
        self.assertEqual(result["lines"], ["FOO bar", "ZIP zap", "ABC def"])

    def test_case_setting_cycle_emits_feedback(self):
        result = self.run_case(
            """
            local a = require('multi_cursor.actions')
            local msg = ''
            local old_notify = vim.notify
            vim.notify = function(m, _, _)
              msg = tostring(m or '')
            end
            local mode = a.case_setting_cycle()
            vim.notify = old_notify
            return { mode = mode, msg = msg }
            """,
            setup_opts="{ backend = 'lua' }",
        )
        self.assertIn(result["mode"], ["smart", "ignore", "sensitive"])
        self.assertIn("case setting", result["msg"].lower())

    def test_tools_menu_picker_case_conversion_applies_all_cursors(self):
        result = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'foo one', 'bar two', 'baz three' })
            vim.api.nvim_win_set_cursor(0, { 1, 0 })
            local a = require('multi_cursor.actions')
            local p = require('multi_cursor.picker')
            local calls = 0
            local old_select = p.select
            p.select = function(items, _, on_choice)
              calls = calls + 1
              if calls == 1 then
                on_choice(items[4]) -- tools_menu: case_conversion
              elseif calls == 2 then
                on_choice(items[2]) -- case_conversion_menu: upper
              end
              return true
            end
            a.add_cursor_vertical(1, 2)
            a.tools_menu(nil)
            p.select = old_select
            return {
              calls = calls,
              lines = vim.api.nvim_buf_get_lines(0, 0, -1, false),
            }
            """,
            setup_opts="{ backend = 'lua' }",
        )
        self.assertEqual(result["calls"], 2)
        self.assertEqual(result["lines"], ["FOO one", "BAR two", "BAZ three"])

    def test_tools_menu_picker_case_conversion_applies_all_extend_regions(self):
        result = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'foo one', 'bar two', 'baz three' })
            vim.api.nvim_win_set_cursor(0, { 1, 0 })
            local a = require('multi_cursor.actions')
            local p = require('multi_cursor.picker')
            local calls = 0
            local old_select = p.select
            p.select = function(items, _, on_choice)
              calls = calls + 1
              if calls == 1 then
                on_choice(items[4]) -- tools_menu: case_conversion
              elseif calls == 2 then
                on_choice(items[2]) -- case_conversion_menu: upper
              end
              return true
            end
            a.add_cursor_vertical(1, 2)
            a.toggle_mode()
            a.shift_selection(2) -- select first word on each line
            a.tools_menu(nil)
            p.select = old_select
            return {
              calls = calls,
              mode = require('multi_cursor.state').current().mode,
              lines = vim.api.nvim_buf_get_lines(0, 0, -1, false),
            }
            """,
            setup_opts="{ backend = 'lua' }",
        )
        self.assertEqual(result["calls"], 2)
        self.assertEqual(result["mode"], "cursor")
        self.assertEqual(result["lines"], ["FOO one", "BAR two", "BAZ three"])
