from tests.nvim_case import NvimCase


class TestBackendParitySubset(NvimCase):
    def run_both(self, lua_body: str, pre_setup_lua: str = ""):
        legacy = self.run_case(lua_body, setup_opts="{ backend = 'legacy' }", pre_setup_lua=pre_setup_lua)
        lua = self.run_case(lua_body, setup_opts="{ backend = 'lua' }", pre_setup_lua=pre_setup_lua)
        return legacy, lua

    def test_find_under_and_select_all_parity(self):
        body = """
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'foo x foo', 'foo' })
        vim.api.nvim_win_set_cursor(0, { 1, 0 })

        if vim.g.loaded_visual_multi == 1 then
          vim.fn['vm#commands#find_under'](0, 1, 1)
          vim.fn['vm#commands#find_all'](0, 1)
          local vm = vim.b.VM_Selection
          return { total = #vm.Regions }
        else
          local a = require('multi_cursor.actions')
          local s = require('multi_cursor.state')
          a.find_under()
          a.select_all()
          local st = s.current()
          return { total = #st.cursors }
        end
        """
        legacy, lua = self.run_both(body)
        self.assertEqual(lua, legacy)

    def test_find_all_command_parity(self):
        body = """
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'foo x foo', 'foo' })
        vim.api.nvim_win_set_cursor(0, { 1, 0 })

        if vim.g.loaded_visual_multi == 1 then
          vim.fn['vm#commands#find_under'](0, 1, 1)
          vim.fn['vm#commands#find_all'](0, 1)
          local vm = vim.b.VM_Selection
          return { total = #vm.Regions }
        else
          local a = require('multi_cursor.actions')
          local s = require('multi_cursor.state')
          a.find_under()
          a.select_all()
          local st = s.current()
          return { total = #st.cursors }
        end
        """
        legacy, lua = self.run_both(body)
        self.assertEqual(lua, legacy)

    def test_find_subword_under_visual_parity(self):
        body = """
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'foo bar foo' })
        vim.fn.setpos("'<", { 0, 1, 1, 0 })
        vim.fn.setpos("'>", { 0, 1, 3, 0 })

        if vim.g.loaded_visual_multi == 1 then
          vim.fn['vm#commands#find_under'](1, 1)
          local vm = vim.b.VM_Selection
          return { total = #vm.Regions }
        else
          local a = require('multi_cursor.actions')
          local s = require('multi_cursor.state')
          a.find_under_visual()
          local st = s.current()
          return { total = #st.cursors }
        end
        """
        legacy, lua = self.run_both(body)
        self.assertEqual(lua, legacy)

    def test_add_cursor_vertical_parity(self):
        body = """
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'a', 'b', 'c' })
        vim.api.nvim_win_set_cursor(0, { 1, 0 })

        if vim.g.loaded_visual_multi == 1 then
          vim.fn['vm#commands#add_cursor_down'](0, 2)
          local vm = vim.b.VM_Selection
          local rows = {}
          for _, r in ipairs(vm.Regions) do
            table.insert(rows, r.l - 1)
          end
          table.sort(rows)
          return { total = #vm.Regions, rows = rows }
        else
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
        end
        """
        legacy, lua = self.run_both(body)
        self.assertEqual(lua, legacy)

    def test_add_cursor_up_parity(self):
        body = """
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'a', 'b', 'c' })
        vim.api.nvim_win_set_cursor(0, { 3, 0 })

        if vim.g.loaded_visual_multi == 1 then
          vim.fn['vm#commands#add_cursor_up'](0, 2)
          local vm = vim.b.VM_Selection
          local rows = {}
          for _, r in ipairs(vm.Regions) do
            table.insert(rows, r.l - 1)
          end
          table.sort(rows)
          return { total = #vm.Regions, rows = rows }
        else
          local a = require('multi_cursor.actions')
          local s = require('multi_cursor.state')
          a.add_cursor_vertical(-1, 2)
          local st = s.current()
          local rows = {}
          local idxs = s.sort_indices_asc(st)
          for _, i in ipairs(idxs) do
            local p = s.cursor_pos(st, i)
            table.insert(rows, p.row)
          end
          return { total = #st.cursors, rows = rows }
        end
        """
        legacy, lua = self.run_both(body)
        self.assertEqual(lua, legacy)

    def test_add_cursor_at_pos_toggle_parity(self):
        body = """
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'abc' })
        vim.api.nvim_win_set_cursor(0, { 1, 1 })

        if vim.g.loaded_visual_multi == 1 then
          vim.fn['vm#commands#add_cursor_at_pos'](0)
          local vm1 = vim.b.VM_Selection
          local before = (vm1 and vm1.Regions) and #vm1.Regions or 0
          vim.fn['vm#commands#add_cursor_at_pos'](0)
          local vm = vim.b.VM_Selection
          local after = (vm and vm.Regions) and #vm.Regions or 0
          return { before = before, after = after }
        else
          local a = require('multi_cursor.actions')
          local s = require('multi_cursor.state')
          a.add_cursor_at_pos()
          local before = #s.current().cursors
          a.add_cursor_at_pos()
          local after = #s.current().cursors
          return { before = before, after = after }
        end
        """
        legacy, lua = self.run_both(body)
        self.assertEqual(lua, legacy)

    def test_select_operator_iw_parity(self):
        body = """
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'foo bar', 'foo baz' })
        vim.api.nvim_win_set_cursor(0, { 1, 0 })

        if vim.g.loaded_visual_multi == 1 then
          vim.fn['vm#commands#find_under'](0, 1, 1)
          vim.fn['vm#commands#find_next'](0, 0)
          vim.fn['vm#operators#select'](0, 'iw')
          local vm = vim.b.VM_Selection
          local items = {}
          for _, r in ipairs(vm.Regions) do
            local parts = vim.api.nvim_buf_get_text(0, r.l - 1, r.a - 1, r.L - 1, r.b, {})
            table.insert(items, table.concat(parts, '\\n'))
          end
          table.sort(items)
          return { items = items }
        else
          local a = require('multi_cursor.actions')
          local s = require('multi_cursor.state')
          a.find_under()
          a.find_next(false)
          a.select_operator_with_motion('iw')
          local st = s.current()
          local items = {}
          for _, i in ipairs(s.sort_indices_asc(st)) do
            local p = s.cursor_pos(st, i)
            if p then
              local sr, sc, er, ec = p.arow, p.acol, p.row, p.col
              if sr > er or (sr == er and sc > ec) then
                sr, er = er, sr
                sc, ec = ec, sc
              end
              local parts = vim.api.nvim_buf_get_text(0, sr, sc, er, ec, {})
              table.insert(items, table.concat(parts, '\\n'))
            end
          end
          table.sort(items)
          return { items = items }
        end
        """
        legacy, lua = self.run_both(body)
        self.assertEqual(lua, legacy)

    def test_find_operator_iw_parity(self):
        body = """
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'foo x foo y foo' })
        vim.api.nvim_win_set_cursor(0, { 1, 0 })

        if vim.g.loaded_visual_multi == 1 then
          vim.fn['vm#commands#find_under'](0, 1, 1)
          vim.fn['vm#operators#find'](1, 0)
          vim.cmd('normal! yiw')
          vim.fn['vm#operators#find'](0, 0)
          local vm = vim.b.VM_Selection
          local cols = {}
          for _, r in ipairs(vm.Regions) do
            table.insert(cols, r.a - 1)
          end
          table.sort(cols)
          return { total = #vm.Regions, cols = cols }
        else
          local a = require('multi_cursor.actions')
          local s = require('multi_cursor.state')
          a.find_under()
          a.find_operator_with_motion('iw')
          local st = s.current()
          local cols = {}
          for _, i in ipairs(s.sort_indices_asc(st)) do
            local p = s.cursor_pos(st, i)
            if p then
              table.insert(cols, p.col)
            end
          end
          table.sort(cols)
          return { total = #st.cursors, cols = cols }
        end
        """
        legacy, lua = self.run_both(body)
        self.assertEqual(lua, legacy)

    def test_run_ex_parity(self):
        body = """
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'a', 'b' })
        vim.api.nvim_win_set_cursor(0, { 1, 0 })

        if vim.g.loaded_visual_multi == 1 then
          vim.fn['vm#commands#add_cursor_down'](0, 1)
          vim.cmd([[call b:VM_Selection.Edit.run_ex('normal! I!')]])
          return { lines = vim.api.nvim_buf_get_lines(0, 0, -1, false) }
        else
          local a = require('multi_cursor.actions')
          a.add_cursor_vertical(1, 1)
          a.run_ex('normal! I!')
          return { lines = vim.api.nvim_buf_get_lines(0, 0, -1, false) }
        end
        """
        legacy, lua = self.run_both(body)
        self.assertEqual(lua, legacy)

    def test_run_normal_parity(self):
        body = """
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'a', 'b' })
        vim.api.nvim_win_set_cursor(0, { 1, 0 })

        if vim.g.loaded_visual_multi == 1 then
          vim.fn['vm#commands#add_cursor_down'](0, 1)
          vim.cmd([[call b:VM_Selection.Edit.run_normal('I!')]])
          return { lines = vim.api.nvim_buf_get_lines(0, 0, -1, false) }
        else
          local a = require('multi_cursor.actions')
          a.add_cursor_vertical(1, 1)
          a.run_normal('I!')
          return { lines = vim.api.nvim_buf_get_lines(0, 0, -1, false) }
        end
        """
        legacy, lua = self.run_both(body)
        self.assertEqual(lua, legacy)

    def test_run_visual_gU_parity(self):
        body = """
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'foo', 'bar' })
        vim.api.nvim_win_set_cursor(0, { 1, 0 })

        if vim.g.loaded_visual_multi == 1 then
          vim.fn['vm#commands#add_cursor_down'](0, 1)
          vim.fn['vm#operators#select'](0, 'iw')
          vim.cmd([[call b:VM_Selection.Edit.run_visual('gU', 0)]])
          return { lines = vim.api.nvim_buf_get_lines(0, 0, -1, false) }
        else
          local a = require('multi_cursor.actions')
          a.add_cursor_vertical(1, 1)
          a.select_operator_with_motion('iw')
          a.run_visual('gU')
          return { lines = vim.api.nvim_buf_get_lines(0, 0, -1, false) }
        end
        """
        legacy, lua = self.run_both(body)
        self.assertEqual(lua, legacy)

    def test_run_macro_parity(self):
        body = """
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'a', 'b' })
        vim.api.nvim_win_set_cursor(0, { 1, 0 })
        vim.fn.setreg('q', 'r#')

        if vim.g.loaded_visual_multi == 1 then
          vim.fn['vm#commands#add_cursor_down'](0, 1)
          vim.cmd([[call b:VM_Selection.Edit.run_normal('@q')]])
          return { lines = vim.api.nvim_buf_get_lines(0, 0, -1, false) }
        else
          local a = require('multi_cursor.actions')
          a.add_cursor_vertical(1, 1)
          a.run_normal('@q')
          return { lines = vim.api.nvim_buf_get_lines(0, 0, -1, false) }
        end
        """
        legacy, lua = self.run_both(body)
        self.assertEqual(lua, legacy)

    def test_visual_cursors_parity(self):
        body = """
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'aa', 'bb', 'cc' })
        vim.fn.setpos("'<", { 0, 1, 1, 0 })
        vim.fn.setpos("'>", { 0, 3, 2, 0 })

        if vim.g.loaded_visual_multi == 1 then
          vim.fn['vm#commands#visual_cursors']()
          local vm = vim.b.VM_Selection
          local rows = {}
          for _, r in ipairs(vm.Regions) do
            table.insert(rows, r.l - 1)
          end
          table.sort(rows)
          return { total = #vm.Regions, rows = rows }
        else
          local a = require('multi_cursor.actions')
          local s = require('multi_cursor.state')
          a.visual_cursors()
          local st = s.current()
          local rows = {}
          local idxs = s.sort_indices_asc(st)
          for _, i in ipairs(idxs) do
            local p = s.cursor_pos(st, i)
            table.insert(rows, p.row)
          end
          return { total = #st.cursors, rows = rows }
        end
        """
        legacy, lua = self.run_both(body)
        self.assertEqual(lua, legacy)

    def test_clear_parity(self):
        body = """
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'a', 'b' })
        vim.api.nvim_win_set_cursor(0, { 1, 0 })

        if vim.g.loaded_visual_multi == 1 then
          vim.fn['vm#commands#add_cursor_down'](0, 1)
          vim.cmd('VMClear')
          local vm = vim.b.VM_Selection
          return { total = (vm and vm.Regions) and #vm.Regions or 0 }
        else
          local a = require('multi_cursor.actions')
          local s = require('multi_cursor.state')
          a.add_cursor_vertical(1, 1)
          a.clear()
          return { total = #s.current().cursors }
        end
        """
        legacy, lua = self.run_both(body)
        self.assertEqual(lua, legacy)

    def test_toggle_mode_parity(self):
        body = """
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'abcd', 'efgh' })
        vim.api.nvim_win_set_cursor(0, { 1, 1 })

        if vim.g.loaded_visual_multi == 1 then
          vim.fn['vm#commands#add_cursor_down'](0, 1)
          local before = vim.g.Vm.extend_mode == 1
          vim.cmd([[call b:VM_Selection.Global.change_mode(1)]])
          local after = vim.g.Vm.extend_mode == 1
          return { before = before, after = after }
        else
          local a = require('multi_cursor.actions')
          a.add_cursor_vertical(1, 1)
          local before = a.info().mode == 'extend'
          a.toggle_mode()
          local after = a.info().mode == 'extend'
          return { before = before, after = after }
        end
        """
        legacy, lua = self.run_both(body)
        self.assertEqual(lua, legacy)

    def test_transpose_extend_parity(self):
        body = """
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'a', 'bb' })
        vim.api.nvim_win_set_cursor(0, { 1, 0 })

        if vim.g.loaded_visual_multi == 1 then
          vim.fn['vm#commands#add_cursor_down'](0, 1)
          vim.fn['vm#operators#select'](0, 'iw')
          vim.cmd([[call b:VM_Selection.Edit.transpose()]])
          return { lines = vim.api.nvim_buf_get_lines(0, 0, -1, false) }
        else
          local a = require('multi_cursor.actions')
          a.add_cursor_vertical(1, 1)
          a.select_operator_with_motion('iw')
          a.transpose()
          return { lines = vim.api.nvim_buf_get_lines(0, 0, -1, false) }
        end
        """
        legacy, lua = self.run_both(body)
        self.assertEqual(lua, legacy)

    def test_duplicate_extend_parity(self):
        body = """
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'a', 'bb' })
        vim.api.nvim_win_set_cursor(0, { 1, 0 })

        if vim.g.loaded_visual_multi == 1 then
          vim.fn['vm#commands#add_cursor_down'](0, 1)
          vim.fn['vm#operators#select'](0, 'iw')
          vim.cmd([[call b:VM_Selection.Edit.duplicate()]])
          return { lines = vim.api.nvim_buf_get_lines(0, 0, -1, false) }
        else
          local a = require('multi_cursor.actions')
          a.add_cursor_vertical(1, 1)
          a.select_operator_with_motion('iw')
          a.duplicate()
          return { lines = vim.api.nvim_buf_get_lines(0, 0, -1, false) }
        end
        """
        legacy, lua = self.run_both(body)
        self.assertEqual(lua, legacy)

    def test_align_parity(self):
        body = """
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'a', 'bb' })
        vim.api.nvim_win_set_cursor(0, { 1, 0 })

        if vim.g.loaded_visual_multi == 1 then
          vim.fn['vm#commands#add_cursor_down'](0, 1)
          vim.cmd([[call b:VM_Selection.Edit.align()]])
          return { lines = vim.api.nvim_buf_get_lines(0, 0, -1, false) }
        else
          local a = require('multi_cursor.actions')
          a.add_cursor_vertical(1, 1)
          a.align()
          return { lines = vim.api.nvim_buf_get_lines(0, 0, -1, false) }
        end
        """
        legacy, lua = self.run_both(body)
        self.assertEqual(lua, legacy)

    def test_delete_extend_parity(self):
        body = """
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'foo', 'bar' })
        vim.api.nvim_win_set_cursor(0, { 1, 0 })

        if vim.g.loaded_visual_multi == 1 then
          vim.fn['vm#commands#add_cursor_down'](0, 1)
          vim.fn['vm#operators#select'](0, 'iw')
          vim.cmd([[call b:VM_Selection.Edit.delete(1, 'a', 1, 1)]])
          return { lines = vim.api.nvim_buf_get_lines(0, 0, -1, false) }
        else
          local a = require('multi_cursor.actions')
          local s = require('multi_cursor.state')
          a.add_cursor_vertical(1, 1)
          a.select_operator_with_motion('iw')
          local st = s.current()
          st.mode = 'extend'
          a.delete_regions()
          return { lines = vim.api.nvim_buf_get_lines(0, 0, -1, false) }
        end
        """
        legacy, lua = self.run_both(body)
        self.assertEqual(lua, legacy)

    def test_remove_every_n_regions_parity(self):
        body = """
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'x', 'x', 'x', 'x', 'x', 'x' })
        vim.api.nvim_win_set_cursor(0, { 1, 0 })

        if vim.g.loaded_visual_multi == 1 then
          vim.fn['vm#commands#add_cursor_down'](0, 5)
          vim.fn['vm#commands#remove_every_n_regions'](2)
          local vm = vim.b.VM_Selection
          return { total = #vm.Regions }
        else
          local a = require('multi_cursor.actions')
          local s = require('multi_cursor.state')
          a.add_cursor_vertical(1, 5)
          a.remove_every_n_regions(2)
          return { total = #s.current().cursors }
        end
        """
        legacy, lua = self.run_both(body)
        self.assertEqual(lua, legacy)

    def test_active_motion_dollar_parity(self):
        body = """
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'abcde', 'vwxyz' })
        vim.api.nvim_win_set_cursor(0, { 1, 1 })

        if vim.g.loaded_visual_multi == 1 then
          vim.fn['vm#commands#add_cursor_down'](0, 1)
          vim.api.nvim_feedkeys('$', 'mtx', false)
          vim.cmd('redraw')
          local cols = {}
          for _, r in ipairs(vim.b.VM_Selection.Regions) do
            table.insert(cols, r.a - 1)
          end
          table.sort(cols)
          return { cols = cols }
        else
          local a = require('multi_cursor.actions')
          local s = require('multi_cursor.state')
          a.add_cursor_vertical(1, 1)
          vim.api.nvim_feedkeys('$', 'mtx', false)
          vim.cmd('redraw')
          local st = s.current()
          local cols = {}
          for _, i in ipairs(s.sort_indices_asc(st)) do
            local p = s.cursor_pos(st, i)
            table.insert(cols, p.col)
          end
          return { cols = cols }
        end
        """
        legacy, lua = self.run_both(body)
        self.assertEqual(lua, legacy)

    def test_multiline_toggle_key_parity(self):
        body = """
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'abc', 'def' })
        vim.api.nvim_win_set_cursor(0, { 1, 0 })

        if vim.g.loaded_visual_multi == 1 then
          vim.fn['vm#commands#add_cursor_down'](0, 1)
          local before = vim.b.VM_Selection.Vars.multiline
          vim.api.nvim_feedkeys('M', 'mtx', false)
          vim.cmd('redraw')
          local after = vim.b.VM_Selection.Vars.multiline
          return { changed = before ~= after, value = after }
        else
          local a = require('multi_cursor.actions')
          a.add_cursor_vertical(1, 1)
          local before = a.info().multiline
          vim.api.nvim_feedkeys('M', 'mtx', false)
          vim.cmd('redraw')
          local after = a.info().multiline
          return { changed = before ~= after, value = after }
        end
        """
        legacy, lua = self.run_both(body)
        self.assertEqual(lua, legacy)

    def test_tab_toggle_mode_parity(self):
        body = """
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'abc', 'def' })
        vim.api.nvim_win_set_cursor(0, { 1, 0 })

        if vim.g.loaded_visual_multi == 1 then
          vim.fn['vm#commands#add_cursor_down'](0, 1)
          local before = vim.g.Vm.extend_mode == 1
          vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<Tab>', true, false, true), 'mtx', false)
          vim.cmd('redraw')
          local after = vim.g.Vm.extend_mode == 1
          return { changed = before ~= after, value = after }
        else
          local a = require('multi_cursor.actions')
          a.add_cursor_vertical(1, 1)
          local before = a.info().mode == 'extend'
          vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<Tab>', true, false, true), 'mtx', false)
          vim.cmd('redraw')
          local after = a.info().mode == 'extend'
          return { changed = before ~= after, value = after }
        end
        """
        legacy, lua = self.run_both(body)
        self.assertEqual(lua, legacy)

    def test_skip_region_parity(self):
        body = """
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'foo x foo y foo' })
        vim.api.nvim_win_set_cursor(0, { 1, 0 })

        if vim.g.loaded_visual_multi == 1 then
          vim.fn['vm#commands#find_under'](0, 1, 1)
          vim.fn['vm#commands#find_next'](0, 0)
          vim.fn['vm#commands#skip'](0)
          local vm = vim.b.VM_Selection
          local total = #vm.Regions
          local idx = vm.Vars.index + 1
          local cur = vm.Regions[idx]
          return { total = total, row = cur and (cur.l - 1) or -1, col = cur and (cur.a - 1) or -1 }
        else
          local a = require('multi_cursor.actions')
          local s = require('multi_cursor.state')
          a.find_under()
          a.find_next(false)
          a.skip_current(false)
          local st = s.current()
          local p = s.cursor_pos(st, st.current)
          return { total = #st.cursors, row = p and p.row or -1, col = p and p.col or -1 }
        end
        """
        legacy, lua = self.run_both(body)
        self.assertEqual(lua, legacy)

    def test_skip_respects_backward_direction_parity(self):
        body = """
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'foo x foo y foo' })
        vim.api.nvim_win_set_cursor(0, { 1, 0 })

        if vim.g.loaded_visual_multi == 1 then
          vim.fn['vm#commands#find_under'](0, 1, 1)
          vim.fn['vm#commands#find_next'](0, 0)
          vim.fn['vm#commands#find_prev'](0, 0)
          vim.fn['vm#commands#skip'](0)
          local vm = vim.b.VM_Selection
          local idx = vm.Vars.index + 1
          local cur = vm.Regions[idx]
          return { total = #vm.Regions, col = cur and (cur.a - 1) or -1 }
        else
          local a = require('multi_cursor.actions')
          local s = require('multi_cursor.state')
          a.find_under()
          a.find_next(false)
          a.find_next(true)
          a.skip_current(nil)
          local st = s.current()
          local p = s.cursor_pos(st, st.current)
          return { total = #st.cursors, col = p and p.col or -1 }
        end
        """
        legacy, lua = self.run_both(body)
        self.assertEqual(lua, legacy)

    def test_remove_region_parity(self):
        body = """
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'foo x foo y foo' })
        vim.api.nvim_win_set_cursor(0, { 1, 0 })

        if vim.g.loaded_visual_multi == 1 then
          vim.fn['vm#commands#find_under'](0, 1, 1)
          vim.fn['vm#commands#find_next'](0, 0)
          vim.fn['vm#commands#skip'](1)
          local vm = vim.b.VM_Selection
          local total = #vm.Regions
          local idx = vm.Vars.index + 1
          local cur = vm.Regions[idx]
          return { total = total, row = cur and (cur.l - 1) or -1, col = cur and (cur.a - 1) or -1 }
        else
          local a = require('multi_cursor.actions')
          local s = require('multi_cursor.state')
          a.find_under()
          a.find_next(false)
          a.remove_current()
          local st = s.current()
          local p = s.cursor_pos(st, st.current)
          return { total = #st.cursors, row = p and p.row or -1, col = p and p.col or -1 }
        end
        """
        legacy, lua = self.run_both(body)
        self.assertEqual(lua, legacy)

    def test_find_prev_navigation_parity(self):
        body = """
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'foo x foo y foo' })
        vim.api.nvim_win_set_cursor(0, { 1, 0 })

        if vim.g.loaded_visual_multi == 1 then
          vim.fn['vm#commands#find_under'](0, 1, 1)
          vim.fn['vm#commands#find_next'](0, 0)
          vim.fn['vm#commands#find_prev'](0, 0)
          local vm = vim.b.VM_Selection
          local idx = vm.Vars.index + 1
          local cur = vm.Regions[idx]
          return { total = #vm.Regions, col = cur and (cur.a - 1) or -1 }
        else
          local a = require('multi_cursor.actions')
          local s = require('multi_cursor.state')
          a.find_under()
          a.find_next(false)
          a.find_next(true)
          local st = s.current()
          local p = s.cursor_pos(st, st.current)
          return { total = #st.cursors, col = p and p.col or -1 }
        end
        """
        legacy, lua = self.run_both(body)
        self.assertEqual(lua, legacy)

    def test_find_next_cycle_parity(self):
        body = """
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'foo x foo y foo' })
        vim.api.nvim_win_set_cursor(0, { 1, 0 })

        if vim.g.loaded_visual_multi == 1 then
          vim.fn['vm#commands#find_under'](0, 1, 1)
          vim.fn['vm#commands#find_next'](0, 0)
          vim.fn['vm#commands#find_next'](0, 0)
          vim.fn['vm#commands#find_next'](0, 0)
          local vm = vim.b.VM_Selection
          local idx = vm.Vars.index + 1
          local cur = vm.Regions[idx]
          return { total = #vm.Regions, col = cur and (cur.a - 1) or -1 }
        else
          local a = require('multi_cursor.actions')
          local s = require('multi_cursor.state')
          a.find_under()
          a.find_next(false)
          a.find_next(false)
          a.find_next(false)
          local st = s.current()
          local p = s.cursor_pos(st, st.current)
          return { total = #st.cursors, col = p and p.col or -1 }
        end
        """
        legacy, lua = self.run_both(body)
        self.assertEqual(lua, legacy)

    def test_goto_region_wrap_parity(self):
        body = """
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'foo x foo y foo' })
        vim.api.nvim_win_set_cursor(0, { 1, 0 })

        if vim.g.loaded_visual_multi == 1 then
          vim.fn['vm#commands#find_under'](0, 1, 1)
          vim.fn['vm#commands#find_next'](0, 0)
          vim.fn['vm#commands#find_next'](0, 0)
          vim.fn['vm#commands#find_next'](0, 1)
          local vm = vim.b.VM_Selection
          local c = vm.Regions[vm.Vars.index + 1]
          return { col = c and (c.a - 1) or -1, total = #vm.Regions }
        else
          local a = require('multi_cursor.actions')
          local s = require('multi_cursor.state')
          a.find_under()
          a.find_next(false)
          a.find_next(false)
          a.goto_region(1)
          local st = s.current()
          local p = s.cursor_pos(st, st.current)
          return { col = p and p.col or -1, total = #st.cursors }
        end
        """
        legacy, lua = self.run_both(body)
        self.assertEqual(lua, legacy)

    def test_find_prev_cycle_parity(self):
        body = """
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'foo x foo y foo' })
        vim.api.nvim_win_set_cursor(0, { 1, 12 })

        if vim.g.loaded_visual_multi == 1 then
          vim.fn['vm#commands#find_under'](0, 1, 1)
          vim.fn['vm#commands#find_prev'](0, 0)
          vim.fn['vm#commands#find_prev'](0, 0)
          local vm = vim.b.VM_Selection
          local idx = vm.Vars.index + 1
          local cur = vm.Regions[idx]
          return { total = #vm.Regions, col = cur and (cur.a - 1) or -1 }
        else
          local a = require('multi_cursor.actions')
          local s = require('multi_cursor.state')
          a.find_under()
          a.find_next(true)
          a.find_next(true)
          local st = s.current()
          local p = s.cursor_pos(st, st.current)
          return { total = #st.cursors, col = p and p.col or -1 }
        end
        """
        legacy, lua = self.run_both(body)
        self.assertEqual(lua, legacy)

    def test_goto_next_wrap_parity(self):
        body = """
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'foo x foo y foo' })
        vim.api.nvim_win_set_cursor(0, { 1, 0 })

        if vim.g.loaded_visual_multi == 1 then
          vim.fn['vm#commands#find_under'](0, 1, 1)
          vim.fn['vm#commands#find_next'](0, 0)
          vim.fn['vm#commands#find_next'](0, 0)
          vim.fn['vm#commands#find_next'](0, 1)
          local vm = vim.b.VM_Selection
          local r = vm.Regions[vm.Vars.index + 1]
          return { col = r and (r.a - 1) or -1, total = #vm.Regions }
        else
          local a = require('multi_cursor.actions')
          local s = require('multi_cursor.state')
          a.find_under()
          a.find_next(false)
          a.find_next(false)
          a.goto_region(1)
          local st = s.current()
          local p = s.cursor_pos(st, st.current)
          return { col = p and p.col or -1, total = #st.cursors }
        end
        """
        legacy, lua = self.run_both(body)
        self.assertEqual(lua, legacy)

    def test_goto_prev_wrap_parity(self):
        body = """
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'foo x foo y foo' })
        vim.api.nvim_win_set_cursor(0, { 1, 0 })

        if vim.g.loaded_visual_multi == 1 then
          vim.fn['vm#commands#find_under'](0, 1, 1)
          vim.fn['vm#commands#find_next'](0, 0)
          vim.fn['vm#commands#find_next'](0, 0)
          vim.fn['vm#commands#find_prev'](0, 1)
          local vm = vim.b.VM_Selection
          local r = vm.Regions[vm.Vars.index + 1]
          return { col = r and (r.a - 1) or -1, total = #vm.Regions }
        else
          local a = require('multi_cursor.actions')
          local s = require('multi_cursor.state')
          a.find_under()
          a.find_next(false)
          a.find_next(false)
          a.goto_region(-1)
          local st = s.current()
          local p = s.cursor_pos(st, st.current)
          return { col = p and p.col or -1, total = #st.cursors }
        end
        """
        legacy, lua = self.run_both(body)
        self.assertEqual(lua, legacy)

    def test_reselect_last_parity(self):
        body = """
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'a', 'b', 'c' })
        vim.api.nvim_win_set_cursor(0, { 1, 0 })

        if vim.g.loaded_visual_multi == 1 then
          vim.fn['vm#commands#add_cursor_down'](0, 2)
          local before = #vim.b.VM_Selection.Regions
          vim.cmd('VMClear')
          vim.fn['vm#commands#reselect_last']()
          local after = #vim.b.VM_Selection.Regions
          return { before = before, after = after }
        else
          local a = require('multi_cursor.actions')
          local s = require('multi_cursor.state')
          a.add_cursor_vertical(1, 2)
          local before = #s.current().cursors
          a.clear()
          a.reselect_last()
          local after = #s.current().cursors
          return { before = before, after = after }
        end
        """
        legacy, lua = self.run_both(body)
        self.assertEqual(lua, legacy)

    def test_invert_direction_parity(self):
        body = """
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'foo', 'bar' })
        vim.api.nvim_win_set_cursor(0, { 1, 0 })

        if vim.g.loaded_visual_multi == 1 then
          vim.fn['vm#commands#add_cursor_down'](0, 1)
          local vm = vim.b.VM_Selection
          local d1 = vm.Vars.direction
          vim.fn['vm#commands#invert_direction']()
          local d2 = vm.Vars.direction
          vim.fn['vm#commands#invert_direction']()
          local d3 = vm.Vars.direction
          return { d1 = d1, d2 = d2, d3 = d3 }
        else
          local a = require('multi_cursor.actions')
          a.add_cursor_vertical(1, 1)
          local d1 = a.info().direction
          a.invert_direction()
          local d2 = a.info().direction
          a.invert_direction()
          local d3 = a.info().direction
          return { d1 = d1, d2 = d2, d3 = d3 }
        end
        """
        legacy, lua = self.run_both(body)
        self.assertEqual(lua, legacy)

    def test_key_driven_operator_motion_parity(self):
        body = """
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'foo bar', 'foo baz' })
        vim.api.nvim_win_set_cursor(0, { 1, 0 })

        if vim.g.loaded_visual_multi == 1 then
          vim.fn['vm#commands#find_under'](0, 1, 1)
          vim.fn['vm#commands#find_next'](0, 0)
          vim.fn['vm#cursors#operation']('d', 1, 'a', 'daw')
          return { lines = vim.api.nvim_buf_get_lines(0, 0, -1, false) }
        else
          local a = require('multi_cursor.actions')
          a.find_under()
          a.find_next(false)
          a.operator_with_motion('d', 'aw')
          return { lines = vim.api.nvim_buf_get_lines(0, 0, -1, false) }
        end
        """
        legacy, lua = self.run_both(body)
        self.assertEqual(lua, legacy)

    def test_select_operator_aw_parity(self):
        body = """
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'foo bar', 'foo baz' })
        vim.api.nvim_win_set_cursor(0, { 1, 1 })

        if vim.g.loaded_visual_multi == 1 then
          vim.fn['vm#commands#find_under'](0, 1, 1)
          vim.fn['vm#commands#find_next'](0, 0)
          vim.fn['vm#operators#select'](0, 'aw')
          local vm = vim.b.VM_Selection
          local items = {}
          for _, r in ipairs(vm.Regions) do
            local parts = vim.api.nvim_buf_get_text(0, r.l - 1, r.a - 1, r.L - 1, r.b, {})
            table.insert(items, table.concat(parts, '\\n'))
          end
          table.sort(items)
          return { items = items }
        else
          local a = require('multi_cursor.actions')
          local s = require('multi_cursor.state')
          a.find_under()
          a.find_next(false)
          a.select_operator_with_motion('aw')
          local st = s.current()
          local items = {}
          for _, i in ipairs(s.sort_indices_asc(st)) do
            local p = s.cursor_pos(st, i)
            if p then
              local sr, sc, er, ec = p.arow, p.acol, p.row, p.col
              if sr > er or (sr == er and sc > ec) then
                sr, er = er, sr
                sc, ec = ec, sc
              end
              local parts = vim.api.nvim_buf_get_text(0, sr, sc, er, ec, {})
              table.insert(items, table.concat(parts, '\\n'))
            end
          end
          table.sort(items)
          return { items = items }
        end
        """
        legacy, lua = self.run_both(body)
        self.assertEqual(lua, legacy)

    def test_select_operator_a_angle_parity(self):
        body = """
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { '<foo> x <foo>', '<foo> y <foo>' })
        vim.api.nvim_win_set_cursor(0, { 1, 2 })

        if vim.g.loaded_visual_multi == 1 then
          vim.fn['vm#commands#find_under'](0, 1, 1)
          vim.fn['vm#commands#find_next'](0, 0)
          vim.fn['vm#operators#select'](0, 'a<')
          local vm = vim.b.VM_Selection
          local items = {}
          for _, r in ipairs(vm.Regions) do
            local parts = vim.api.nvim_buf_get_text(0, r.l - 1, r.a - 1, r.L - 1, r.b, {})
            table.insert(items, table.concat(parts, '\\n'))
          end
          table.sort(items)
          return { items = items }
        else
          local a = require('multi_cursor.actions')
          local s = require('multi_cursor.state')
          a.find_under()
          a.find_next(false)
          a.select_operator_with_motion('a<')
          local st = s.current()
          local items = {}
          for _, i in ipairs(s.sort_indices_asc(st)) do
            local p = s.cursor_pos(st, i)
            if p then
              local sr, sc, er, ec = p.arow, p.acol, p.row, p.col
              if sr > er or (sr == er and sc > ec) then
                sr, er = er, sr
                sc, ec = ec, sc
              end
              local parts = vim.api.nvim_buf_get_text(0, sr, sc, er, ec, {})
              table.insert(items, table.concat(parts, '\\n'))
            end
          end
          table.sort(items)
          return { items = items }
        end
        """
        legacy, lua = self.run_both(body)
        self.assertEqual(lua, legacy)

    def test_select_operator_iw_eol_edge_parity(self):
        body = """
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'foo', 'foo' })
        vim.api.nvim_win_set_cursor(0, { 1, 3 })

        if vim.g.loaded_visual_multi == 1 then
          vim.fn['vm#commands#add_cursor_down'](0, 1)
          vim.fn['vm#operators#select'](0, 'iw')
          local vm = vim.b.VM_Selection
          local items = {}
          for _, r in ipairs(vm.Regions) do
            local parts = vim.api.nvim_buf_get_text(0, r.l - 1, r.a - 1, r.L - 1, r.b, {})
            table.insert(items, table.concat(parts, '\\n'))
          end
          table.sort(items)
          return { items = items }
        else
          local a = require('multi_cursor.actions')
          local s = require('multi_cursor.state')
          a.add_cursor_vertical(1, 1)
          a.select_operator_with_motion('iw')
          local st = s.current()
          local items = {}
          for _, i in ipairs(s.sort_indices_asc(st)) do
            local p = s.cursor_pos(st, i)
            if p then
              local sr, sc, er, ec = p.arow, p.acol, p.row, p.col
              if sr > er or (sr == er and sc > ec) then
                sr, er = er, sr
                sc, ec = ec, sc
              end
              local parts = vim.api.nvim_buf_get_text(0, sr, sc, er, ec, {})
              table.insert(items, table.concat(parts, '\\n'))
            end
          end
          table.sort(items)
          return { items = items }
        end
        """
        legacy, lua = self.run_both(body)
        self.assertEqual(lua, legacy)

    def test_case_convert_snake_parity(self):
        body = """
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'fooBar x', 'fooBar y' })
        vim.api.nvim_win_set_cursor(0, { 1, 0 })

        if vim.g.loaded_visual_multi == 1 then
          vim.fn['vm#commands#find_under'](0, 1, 1)
          vim.fn['vm#commands#find_next'](0, 0)
          vim.cmd("call b:VM_Selection.Case.convert('snake')")
          return { lines = vim.api.nvim_buf_get_lines(0, 0, -1, false) }
        else
          local a = require('multi_cursor.actions')
          a.find_under()
          a.find_next(false)
          a.case_convert('snake')
          return { lines = vim.api.nvim_buf_get_lines(0, 0, -1, false) }
        end
        """
        legacy, lua = self.run_both(body)
        self.assertEqual(lua, legacy)

    def test_case_convert_upper_extend_parity(self):
        body = """
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { '<foo> bar', '<zip> zap' })
        vim.api.nvim_win_set_cursor(0, { 1, 2 })

        if vim.g.loaded_visual_multi == 1 then
          vim.fn['vm#commands#add_cursor_down'](0, 1)
          vim.fn['vm#operators#select'](0, 'i<')
          vim.cmd("call b:VM_Selection.Case.convert('upper')")
          local vm = vim.b.VM_Selection
          return { mode = vm.Vars.extend_mode == 1, lines = vim.api.nvim_buf_get_lines(0, 0, -1, false) }
        else
          local a = require('multi_cursor.actions')
          local s = require('multi_cursor.state')
          a.add_cursor_vertical(1, 1)
          a.select_operator_with_motion('i<')
          a.case_convert('upper')
          local st = s.current()
          return { mode = st.mode == 'extend', lines = vim.api.nvim_buf_get_lines(0, 0, -1, false) }
        end
        """
        legacy, lua = self.run_both(body)
        self.assertEqual(lua, legacy)

    def test_numbers_expression_prepend_parity(self):
        body = """
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'x', 'x', 'x' })
        vim.api.nvim_win_set_cursor(0, { 1, 0 })

        if vim.g.loaded_visual_multi == 1 then
          vim.fn['vm#commands#add_cursor_down'](0, 2)
          vim.cmd("call b:VM_Selection.Edit._numbers(10, 2, '-', 0)")
          return { lines = vim.api.nvim_buf_get_lines(0, 0, -1, false) }
        else
          local a = require('multi_cursor.actions')
          a.add_cursor_vertical(1, 2)
          a.number_regions_prompt(1, false, '10/2/-')
          return { lines = vim.api.nvim_buf_get_lines(0, 0, -1, false) }
        end
        """
        legacy, lua = self.run_both(body)
        self.assertEqual(lua, legacy)

    def test_goto_regex_parity(self):
        body = """
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'a x b', 'c x d' })
        vim.api.nvim_win_set_cursor(0, { 1, 0 })

        if vim.g.loaded_visual_multi == 1 then
          vim.fn['vm#commands#add_cursor_down'](0, 1)
          vim.fn['vm#commands#regex_motion']('x', 1, 0)
          local vm = vim.b.VM_Selection
          local cols = {}
          for _, r in ipairs(vm.Regions) do
            table.insert(cols, r.a - 1)
          end
          table.sort(cols)
          return { total = #vm.Regions, cols = cols }
        else
          local a = require('multi_cursor.actions')
          local s = require('multi_cursor.state')
          a.add_cursor_vertical(1, 1)
          a.goto_regex('x', false, 1)
          local st = s.current()
          local cols = {}
          for _, i in ipairs(s.sort_indices_asc(st)) do
            local p = s.cursor_pos(st, i)
            table.insert(cols, p.col)
          end
          table.sort(cols)
          return { total = #st.cursors, cols = cols }
        end
        """
        legacy, lua = self.run_both(body)
        self.assertEqual(lua, legacy)

    def test_goto_regex_remove_parity(self):
        body = """
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'abc', 'def' })
        vim.api.nvim_win_set_cursor(0, { 1, 0 })

        if vim.g.loaded_visual_multi == 1 then
          vim.fn['vm#commands#add_cursor_down'](0, 1)
          vim.fn['vm#commands#regex_motion']('zzz', 1, 1)
          local vm = vim.b.VM_Selection
          local total = (vm and vm.Regions) and #vm.Regions or 0
          return { total = total }
        else
          local a = require('multi_cursor.actions')
          local s = require('multi_cursor.state')
          a.add_cursor_vertical(1, 1)
          a.goto_regex('zzz', true, 1)
          return { total = #s.current().cursors }
        end
        """
        legacy, lua = self.run_both(body)
        self.assertEqual(lua, legacy)

    def test_add_cursor_at_word_parity(self):
        body = """
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'foo bar foo' })
        vim.api.nvim_win_set_cursor(0, { 1, 0 })

        if vim.g.loaded_visual_multi == 1 then
          vim.fn['vm#commands#find_under'](0, 1, 1)
          vim.api.nvim_win_set_cursor(0, { 1, 8 })
          vim.fn['vm#commands#add_cursor_at_word'](0, 0)
          local vm = vim.b.VM_Selection
          local cols = {}
          for _, r in ipairs(vm.Regions) do
            table.insert(cols, r.a - 1)
          end
          table.sort(cols)
          return { total = #vm.Regions, cols = cols }
        else
          local a = require('multi_cursor.actions')
          local s = require('multi_cursor.state')
          a.find_under()
          vim.api.nvim_win_set_cursor(0, { 1, 8 })
          a.add_cursor_at_word(false)
          local st = s.current()
          local cols = {}
          for _, i in ipairs(s.sort_indices_asc(st)) do
            local p = s.cursor_pos(st, i)
            table.insert(cols, p.col)
          end
          table.sort(cols)
          return { total = #st.cursors, cols = cols }
        end
        """
        legacy, lua = self.run_both(body)
        self.assertEqual(lua, legacy)

    def test_remove_last_region_parity(self):
        body = """
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'a', 'b', 'c' })
        vim.api.nvim_win_set_cursor(0, { 1, 0 })

        if vim.g.loaded_visual_multi == 1 then
          vim.fn['vm#commands#add_cursor_down'](0, 2)
          vim.cmd("call b:VM_Selection.Global.remove_last_region()")
          local vm = vim.b.VM_Selection
          local rows = {}
          for _, r in ipairs(vm.Regions) do
            table.insert(rows, r.l - 1)
          end
          table.sort(rows)
          return { total = #vm.Regions, rows = rows }
        else
          local a = require('multi_cursor.actions')
          local s = require('multi_cursor.state')
          a.add_cursor_vertical(1, 2)
          a.remove_last_region()
          local st = s.current()
          local rows = {}
          for _, i in ipairs(s.sort_indices_asc(st)) do
            local p = s.cursor_pos(st, i)
            table.insert(rows, p.row)
          end
          table.sort(rows)
          return { total = #st.cursors, rows = rows }
        end
        """
        legacy, lua = self.run_both(body)
        self.assertEqual(lua, legacy)

    def test_toggle_whole_word_parity(self):
        body = """
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'foo food foo' })
        vim.api.nvim_win_set_cursor(0, { 1, 0 })

        if vim.g.loaded_visual_multi == 1 then
          vim.fn['vm#commands#find_under'](0, 1, 1)
          vim.cmd("call b:VM_Selection.Funcs.toggle_option('whole_word')")
          local vm = vim.b.VM_Selection
          local pat = (vm and vm.Vars and vm.Vars.search and vm.Vars.search[1]) or ''
          return { pattern = pat }
        else
          local a = require('multi_cursor.actions')
          a.find_under()
          a.toggle_whole_word()
          return { pattern = a.info().pattern }
        end
        """
        legacy, lua = self.run_both(body)
        self.assertEqual(lua, legacy)

    def test_one_region_per_line_parity(self):
        body = """
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'foo foo', 'foo foo' })
        vim.api.nvim_win_set_cursor(0, { 1, 0 })

        if vim.g.loaded_visual_multi == 1 then
          vim.fn['vm#commands#find_under'](0, 1, 1)
          vim.fn['vm#commands#find_next'](0, 0)
          vim.fn['vm#commands#find_next'](0, 0)
          vim.fn['vm#commands#find_next'](0, 0)
          vim.cmd("call b:VM_Selection.Global.one_region_per_line()")
          vim.cmd("call b:VM_Selection.Global.update_and_select_region()")
          local vm = vim.b.VM_Selection
          local rows = {}
          for _, r in ipairs(vm.Regions) do
            table.insert(rows, r.l - 1)
          end
          table.sort(rows)
          return { total = #vm.Regions, rows = rows }
        else
          local a = require('multi_cursor.actions')
          local s = require('multi_cursor.state')
          a.find_under()
          a.find_next(false)
          a.find_next(false)
          a.find_next(false)
          a.one_region_per_line()
          local st = s.current()
          local rows = {}
          for _, i in ipairs(s.sort_indices_asc(st)) do
            local p = s.cursor_pos(st, i)
            table.insert(rows, p.row)
          end
          table.sort(rows)
          return { total = #st.cursors, rows = rows }
        end
        """
        legacy, lua = self.run_both(body)
        self.assertEqual(lua, legacy)

    def test_split_regions_parity(self):
        body = """
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'ab', 'cd' })
        vim.api.nvim_win_set_cursor(0, { 1, 0 })

        if vim.g.loaded_visual_multi == 1 then
          vim.fn['vm#commands#find_under'](0, 1, 1)
          vim.fn['vm#operators#select'](1, 'j')
          vim.fn['vm#commands#split_lines']()
          local vm = vim.b.VM_Selection
          local spans = {}
          for _, r in ipairs(vm.Regions) do
            table.insert(spans, {
              sr = r.l - 1,
              sc = r.a - 1,
              er = r.L - 1,
              ec = r.b,
            })
          end
          table.sort(spans, function(a, b)
            if a.sr == b.sr then
              return a.sc < b.sc
            end
            return a.sr < b.sr
          end)
          return { total = #vm.Regions, spans = spans }
        else
          local a = require('multi_cursor.actions')
          local s = require('multi_cursor.state')
          a.find_under()
          a.select_operator_with_motion('j')
          a.split_lines()
          local st = s.current()
          local spans = {}
          for _, i in ipairs(s.sort_indices_asc(st)) do
            local p = s.cursor_pos(st, i)
            local sr, sc, er, ec = p.arow, p.acol, p.row, p.col
            if sr > er or (sr == er and sc > ec) then
              sr, er = er, sr
              sc, ec = ec, sc
            end
            table.insert(spans, { sr = sr, sc = sc, er = er, ec = ec })
          end
          table.sort(spans, function(a, b)
            if a.sr == b.sr then
              return a.sc < b.sc
            end
            return a.sr < b.sr
          end)
          return { total = #st.cursors, spans = spans }
        end
        """
        legacy, lua = self.run_both(body)
        self.assertEqual(lua, legacy)

    def test_visual_add_parity(self):
        body = """
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'alpha beta', 'gamma beta' })
        vim.api.nvim_win_set_cursor(0, { 1, 6 })

        if vim.g.loaded_visual_multi == 1 then
          vim.fn['vm#commands#find_under'](0, 1, 1)
          vim.fn.setpos("'<", { 0, 1, 1, 0 })
          vim.fn.setpos("'>", { 0, 1, 5, 0 })
          vim.fn['vm#visual#add']('v')
          local vm = vim.b.VM_Selection
          local spans = {}
          for _, r in ipairs(vm.Regions) do
            table.insert(spans, { sr = r.l - 1, sc = r.a - 1, er = r.L - 1, ec = r.b })
          end
          table.sort(spans, function(a, b)
            if a.sr == b.sr then
              return a.sc < b.sc
            end
            return a.sr < b.sr
          end)
          return { total = #vm.Regions, spans = spans }
        else
          local a = require('multi_cursor.actions')
          local s = require('multi_cursor.state')
          a.find_under()
          vim.fn.setpos("'<", { 0, 1, 1, 0 })
          vim.fn.setpos("'>", { 0, 1, 5, 0 })
          a.visual_add()
          local st = s.current()
          local spans = {}
          for _, i in ipairs(s.sort_indices_asc(st)) do
            local p = s.cursor_pos(st, i)
            local sr, sc, er, ec = p.arow, p.acol, p.row, p.col
            if sr > er or (sr == er and sc > ec) then
              sr, er = er, sr
              sc, ec = ec, sc
            end
            table.insert(spans, { sr = sr, sc = sc, er = er, ec = ec })
          end
          table.sort(spans, function(a, b)
            if a.sr == b.sr then
              return a.sc < b.sc
            end
            return a.sr < b.sr
          end)
          return { total = #st.cursors, spans = spans }
        end
        """
        legacy, lua = self.run_both(body)
        self.assertEqual(lua, legacy)

    def test_visual_subtract_parity(self):
        body = """
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'foo foo', 'foo foo' })
        vim.api.nvim_win_set_cursor(0, { 1, 0 })

        if vim.g.loaded_visual_multi == 1 then
          vim.fn['vm#commands#find_under'](0, 1, 1)
          vim.fn['vm#commands#find_next'](0, 0)
          vim.fn['vm#commands#find_next'](0, 0)
          vim.fn['vm#commands#find_next'](0, 0)
          vim.fn.setpos("'<", { 0, 2, 1, 0 })
          vim.fn.setpos("'>", { 0, 2, 3, 0 })
          vim.fn['vm#visual#subtract']('v')
          local vm = vim.b.VM_Selection
          local rows = {}
          for _, r in ipairs(vm.Regions) do
            table.insert(rows, r.l - 1)
          end
          table.sort(rows)
          return { total = #vm.Regions, rows = rows }
        else
          local a = require('multi_cursor.actions')
          local s = require('multi_cursor.state')
          a.find_under()
          a.find_next(false)
          a.find_next(false)
          a.find_next(false)
          vim.fn.setpos("'<", { 0, 2, 1, 0 })
          vim.fn.setpos("'>", { 0, 2, 3, 0 })
          a.visual_subtract()
          local st = s.current()
          local rows = {}
          for _, i in ipairs(s.sort_indices_asc(st)) do
            local p = s.cursor_pos(st, i)
            table.insert(rows, p.row)
          end
          table.sort(rows)
          return { total = #st.cursors, rows = rows }
        end
        """
        legacy, lua = self.run_both(body)
        self.assertEqual(lua, legacy)

    def test_visual_reduce_parity(self):
        body = """
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'foo foo', 'foo foo' })
        vim.api.nvim_win_set_cursor(0, { 1, 0 })

        if vim.g.loaded_visual_multi == 1 then
          vim.fn['vm#commands#find_under'](0, 1, 1)
          vim.fn['vm#commands#find_next'](0, 0)
          vim.fn['vm#commands#find_next'](0, 0)
          vim.fn['vm#commands#find_next'](0, 0)
          vim.fn.setpos("'<", { 0, 1, 1, 0 })
          vim.fn.setpos("'>", { 0, 1, 7, 0 })
          vim.fn['vm#visual#reduce']()
          local vm = vim.b.VM_Selection
          local rows = {}
          for _, r in ipairs(vm.Regions) do
            table.insert(rows, r.l - 1)
          end
          table.sort(rows)
          return { total = #vm.Regions, rows = rows }
        else
          local a = require('multi_cursor.actions')
          local s = require('multi_cursor.state')
          a.find_under()
          a.find_next(false)
          a.find_next(false)
          a.find_next(false)
          vim.fn.setpos("'<", { 0, 1, 1, 0 })
          vim.fn.setpos("'>", { 0, 1, 7, 0 })
          a.visual_reduce()
          local st = s.current()
          local rows = {}
          for _, i in ipairs(s.sort_indices_asc(st)) do
            local p = s.cursor_pos(st, i)
            table.insert(rows, p.row)
          end
          table.sort(rows)
          return { total = #st.cursors, rows = rows }
        end
        """
        legacy, lua = self.run_both(body)
        self.assertEqual(lua, legacy)

    def test_remove_empty_lines_parity(self):
        body = """
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'a', '', 'b' })
        vim.api.nvim_win_set_cursor(0, { 1, 0 })

        if vim.g.loaded_visual_multi == 1 then
          vim.fn['vm#commands#add_cursor_down'](0, 2)
          vim.fn['vm#commands#remove_empty_lines']()
          local vm = vim.b.VM_Selection
          local rows = {}
          for _, r in ipairs(vm.Regions) do
            table.insert(rows, r.l - 1)
          end
          table.sort(rows)
          return { total = #vm.Regions, rows = rows }
        else
          local a = require('multi_cursor.actions')
          local s = require('multi_cursor.state')
          a.add_cursor_vertical(1, 2)
          a.remove_empty_lines()
          local st = s.current()
          local rows = {}
          for _, i in ipairs(s.sort_indices_asc(st)) do
            local p = s.cursor_pos(st, i)
            table.insert(rows, p.row)
          end
          table.sort(rows)
          return { total = #st.cursors, rows = rows }
        end
        """
        legacy, lua = self.run_both(body)
        self.assertEqual(lua, legacy)

    def test_zero_numbers_prepend_parity(self):
        body = """
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'x', 'x', 'x' })
        vim.api.nvim_win_set_cursor(0, { 1, 0 })

        if vim.g.loaded_visual_multi == 1 then
          vim.fn['vm#commands#add_cursor_down'](0, 2)
          vim.cmd("call b:VM_Selection.Edit._numbers(0, 1, '', 0)")
          return { lines = vim.api.nvim_buf_get_lines(0, 0, -1, false) }
        else
          local a = require('multi_cursor.actions')
          a.add_cursor_vertical(1, 2)
          a.number_regions_zero(0, false)
          return { lines = vim.api.nvim_buf_get_lines(0, 0, -1, false) }
        end
        """
        legacy, lua = self.run_both(body)
        self.assertEqual(lua, legacy)

    def test_zero_numbers_append_parity(self):
        body = """
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'x', 'x', 'x' })
        vim.api.nvim_win_set_cursor(0, { 1, 0 })

        if vim.g.loaded_visual_multi == 1 then
          vim.fn['vm#commands#add_cursor_down'](0, 2)
          vim.cmd("call b:VM_Selection.Edit._numbers(0, 1, '', 1)")
          return { lines = vim.api.nvim_buf_get_lines(0, 0, -1, false) }
        else
          local a = require('multi_cursor.actions')
          a.add_cursor_vertical(1, 2)
          a.number_regions_zero(0, true)
          return { lines = vim.api.nvim_buf_get_lines(0, 0, -1, false) }
        end
        """
        legacy, lua = self.run_both(body)
        self.assertEqual(lua, legacy)

    def test_rotate_parity(self):
        body = """
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'aa', 'bb', 'cc' })
        vim.api.nvim_win_set_cursor(0, { 1, 0 })

        if vim.g.loaded_visual_multi == 1 then
          vim.fn['vm#commands#add_cursor_down'](0, 2)
          vim.fn['vm#operators#select'](1, 'iw')
          vim.cmd("call b:VM_Selection.Edit.rotate()")
          return { lines = vim.api.nvim_buf_get_lines(0, 0, -1, false) }
        else
          local a = require('multi_cursor.actions')
          a.add_cursor_vertical(1, 2)
          a.select_operator_with_motion('iw')
          a.rotate()
          return { lines = vim.api.nvim_buf_get_lines(0, 0, -1, false) }
        end
        """
        legacy, lua = self.run_both(body)
        self.assertEqual(lua, legacy)

    def test_run_last_normal_parity(self):
        body = """
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'ab', 'ab' })
        vim.api.nvim_win_set_cursor(0, { 1, 0 })

        if vim.g.loaded_visual_multi == 1 then
          vim.fn['vm#commands#add_cursor_down'](0, 1)
          vim.cmd("call b:VM_Selection.Edit.run_normal('A!', {'recursive': 0})")
          vim.cmd("call b:VM_Selection.Edit.run_normal(g:Vm.last_normal[0], {'recursive': g:Vm.last_normal[1]})")
          return { lines = vim.api.nvim_buf_get_lines(0, 0, -1, false) }
        else
          local a = require('multi_cursor.actions')
          a.add_cursor_vertical(1, 1)
          a.run_normal('A!')
          a.run_last_normal()
          return { lines = vim.api.nvim_buf_get_lines(0, 0, -1, false) }
        end
        """
        legacy, lua = self.run_both(body)
        self.assertEqual(lua, legacy)

    def test_run_last_ex_parity(self):
        body = """
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'ab', 'ab' })
        vim.api.nvim_win_set_cursor(0, { 1, 0 })

        if vim.g.loaded_visual_multi == 1 then
          vim.fn['vm#commands#add_cursor_down'](0, 1)
          vim.cmd("call b:VM_Selection.Edit.run_ex('normal! A?')")
          vim.cmd("call b:VM_Selection.Edit.run_ex(g:Vm.last_ex)")
          return { lines = vim.api.nvim_buf_get_lines(0, 0, -1, false) }
        else
          local a = require('multi_cursor.actions')
          a.add_cursor_vertical(1, 1)
          a.run_ex('normal! A?')
          a.run_last_ex()
          return { lines = vim.api.nvim_buf_get_lines(0, 0, -1, false) }
        end
        """
        legacy, lua = self.run_both(body)
        self.assertEqual(lua, legacy)

    def test_run_last_visual_parity(self):
        body = """
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'foo', 'foo' })
        vim.api.nvim_win_set_cursor(0, { 1, 0 })

        if vim.g.loaded_visual_multi == 1 then
          vim.fn['vm#commands#add_cursor_down'](0, 1)
          vim.fn['vm#operators#select'](1, 'iw')
          vim.cmd("call b:VM_Selection.Edit.run_visual('~', 1)")
          vim.cmd("call b:VM_Selection.Edit.run_visual(g:Vm.last_visual[0], g:Vm.last_visual[1])")
          return { lines = vim.api.nvim_buf_get_lines(0, 0, -1, false) }
        else
          local a = require('multi_cursor.actions')
          a.add_cursor_vertical(1, 1)
          a.select_operator_with_motion('iw')
          a.run_visual('~')
          a.run_last_visual()
          return { lines = vim.api.nvim_buf_get_lines(0, 0, -1, false) }
        end
        """
        legacy, lua = self.run_both(body)
        self.assertEqual(lua, legacy)

    def test_case_setting_cycle_parity(self):
        body = """
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'foo' })
        vim.api.nvim_win_set_cursor(0, { 1, 0 })

        if vim.g.loaded_visual_multi == 1 then
          vim.fn['vm#commands#find_under'](0, 1, 1)
          local before = { smart = vim.o.smartcase, ignore = vim.o.ignorecase }
          vim.cmd("call b:VM_Selection.Search.case()")
          local s1 = { smart = vim.o.smartcase, ignore = vim.o.ignorecase }
          vim.cmd("call b:VM_Selection.Search.case()")
          local s2 = { smart = vim.o.smartcase, ignore = vim.o.ignorecase }
          vim.cmd("call b:VM_Selection.Search.case()")
          local s3 = { smart = vim.o.smartcase, ignore = vim.o.ignorecase }
          return { before = before, s1 = s1, s2 = s2, s3 = s3 }
        else
          local a = require('multi_cursor.actions')
          local before = { smart = vim.o.smartcase, ignore = vim.o.ignorecase }
          a.case_setting_cycle()
          local s1 = { smart = vim.o.smartcase, ignore = vim.o.ignorecase }
          a.case_setting_cycle()
          local s2 = { smart = vim.o.smartcase, ignore = vim.o.ignorecase }
          a.case_setting_cycle()
          local s3 = { smart = vim.o.smartcase, ignore = vim.o.ignorecase }
          return { before = before, s1 = s1, s2 = s2, s3 = s3 }
        end
        """
        legacy, lua = self.run_both(body)
        self.assertEqual(lua, legacy)

    def test_run_dot_parity(self):
        body = """
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'ab', 'ab' })
        vim.api.nvim_win_set_cursor(0, { 1, 0 })

        if vim.g.loaded_visual_multi == 1 then
          vim.fn['vm#commands#add_cursor_down'](0, 1)
          vim.cmd("call b:VM_Selection.Edit.run_normal('A!', {'recursive': 0})")
          vim.cmd("call b:VM_Selection.Edit.dot()")
          return { lines = vim.api.nvim_buf_get_lines(0, 0, -1, false) }
        else
          local a = require('multi_cursor.actions')
          a.add_cursor_vertical(1, 1)
          a.run_normal('A!')
          a.run_dot()
          return { lines = vim.api.nvim_buf_get_lines(0, 0, -1, false) }
        end
        """
        legacy, lua = self.run_both(body)
        self.assertEqual(lua, legacy)

    def test_shrink_enlarge_parity(self):
        body = """
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'alpha', 'bravo' })
        vim.api.nvim_win_set_cursor(0, { 1, 1 })

        if vim.g.loaded_visual_multi == 1 then
          vim.fn['vm#commands#add_cursor_down'](1, 1)
          vim.fn['vm#operators#select'](0, 'iw')
          vim.fn['vm#commands#shrink_or_enlarge'](1)
          vim.fn['vm#commands#shrink_or_enlarge'](0)
          local vm = vim.b.VM_Selection
          local items = {}
          for _, r in ipairs(vm.Regions) do
            local sr = r.l - 1
            local sc = r.a - 1
            local er = r.L - 1
            local ec = r.b
            local parts = vim.api.nvim_buf_get_text(0, sr, sc, er, ec, {})
            table.insert(items, table.concat(parts, '\\n'))
          end
          table.sort(items)
          return { lines = vim.api.nvim_buf_get_lines(0, 0, -1, false), items = items }
        else
          local a = require('multi_cursor.actions')
          local s = require('multi_cursor.state')
          a.add_cursor_vertical(1, 1)
          a.select_operator_with_motion('iw')
          a.shrink_or_enlarge(true)
          a.shrink_or_enlarge(false)
          local st = s.current()
          local items = {}
          for _, i in ipairs(s.sort_indices_asc(st)) do
            local p = s.cursor_pos(st, i)
            local sr, sc, er, ec = p.arow, p.acol, p.row, p.col
            if sr > er or (sr == er and sc > ec) then
              sr, er = er, sr
              sc, ec = ec, sc
            end
            local parts = vim.api.nvim_buf_get_text(0, sr, sc, er, ec, {})
            table.insert(items, table.concat(parts, '\\n'))
          end
          table.sort(items)
          return { lines = vim.api.nvim_buf_get_lines(0, 0, -1, false), items = items }
        end
        """
        legacy, lua = self.run_both(body)
        self.assertEqual(lua, legacy)

    def test_alpha_increase_decrease_parity(self):
        body = """
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'a1', 'z9' })
        vim.api.nvim_win_set_cursor(0, { 1, 0 })

        if vim.g.loaded_visual_multi == 1 then
          vim.fn['vm#commands#add_cursor_down'](0, 1)
          vim.fn['vm#commands#increase_or_decrease'](1, 1, 1, false)
          vim.fn['vm#commands#increase_or_decrease'](0, 1, 1, false)
          return { lines = vim.api.nvim_buf_get_lines(0, 0, -1, false) }
        else
          local a = require('multi_cursor.actions')
          a.add_cursor_vertical(1, 1)
          a.increase_or_decrease(true, true, 1, false)
          a.increase_or_decrease(false, true, 1, false)
          return { lines = vim.api.nvim_buf_get_lines(0, 0, -1, false) }
        end
        """
        legacy, lua = self.run_both(body)
        self.assertEqual(lua, legacy)

    def test_gincrease_gdecrease_parity(self):
        body = """
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { '5', '10' })
        vim.api.nvim_win_set_cursor(0, { 1, 0 })

        if vim.g.loaded_visual_multi == 1 then
          vim.fn['vm#commands#add_cursor_down'](0, 1)
          vim.fn['vm#commands#increase_or_decrease'](1, 0, 3, true)
          vim.fn['vm#commands#increase_or_decrease'](0, 0, 2, true)
          return { lines = vim.api.nvim_buf_get_lines(0, 0, -1, false) }
        else
          local a = require('multi_cursor.actions')
          a.add_cursor_vertical(1, 1)
          a.increase_or_decrease(true, false, 3, true)
          a.increase_or_decrease(false, false, 2, true)
          return { lines = vim.api.nvim_buf_get_lines(0, 0, -1, false) }
        end
        """
        legacy, lua = self.run_both(body)
        self.assertEqual(lua, legacy)

    def test_replace_chars_extend_parity(self):
        body = """
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'foo', 'bar' })
        vim.api.nvim_win_set_cursor(0, { 1, 0 })

        if vim.g.loaded_visual_multi == 1 then
          vim.fn['vm#commands#add_cursor_down'](0, 1)
          vim.fn['vm#operators#select'](1, 'iw')
          vim.cmd([[call b:VM_Selection.Edit.run_visual('rX', 0)]])
          return { lines = vim.api.nvim_buf_get_lines(0, 0, -1, false) }
        else
          local a = require('multi_cursor.actions')
          a.add_cursor_vertical(1, 1)
          a.select_operator_with_motion('iw')
          a.replace_chars('X')
          return { lines = vim.api.nvim_buf_get_lines(0, 0, -1, false) }
        end
        """
        legacy, lua = self.run_both(body)
        self.assertEqual(lua, legacy)

    def test_custom_noremap_motion_parity(self):
        body = """
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { '  foo', '  bar' })
        vim.api.nvim_win_set_cursor(0, { 1, 3 })

        if vim.g.loaded_visual_multi == 1 then
          vim.cmd('normal C')
          vim.cmd('normal H')
          local vm = vim.b.VM_Selection
          local cols = {}
          for _, r in ipairs(vm.Regions) do
            table.insert(cols, r.a - 1)
          end
          table.sort(cols)
          return { cols = cols }
        else
          local a = require('multi_cursor.actions')
          local s = require('multi_cursor.state')
          vim.cmd('normal C')
          vim.cmd('normal H')
          local st = s.current()
          local cols = {}
          for _, i in ipairs(s.sort_indices_asc(st)) do
            local p = s.cursor_pos(st, i)
            if p then
              table.insert(cols, p.col)
            end
          end
          table.sort(cols)
          return { cols = cols }
        end
        """
        pre = "vim.g.VM_maps = { ['Add Cursor Down'] = 'C' }\nvim.g.VM_custom_noremaps = { H = '0' }"
        legacy, lua = self.run_both(body, pre_setup_lua=pre)
        self.assertEqual(lua, legacy)

    def test_multicursor_charwise_p_parity(self):
        body = """
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'ab', 'cd' })
        vim.api.nvim_win_set_cursor(0, { 1, 0 })
        vim.fn.setreg('"', 'X')

        if vim.g.loaded_visual_multi == 1 then
          vim.fn['vm#commands#add_cursor_down'](0, 1)
          vim.cmd('normal p')
          local vm = vim.b.VM_Selection
          local cols_p = {}
          for _, r in ipairs(vm.Regions) do
            table.insert(cols_p, r.a - 1)
          end
          table.sort(cols_p)
          local lines_p = vim.api.nvim_buf_get_lines(0, 0, -1, false)
          return { lines = lines_p, cols = cols_p }
        else
          local a = require('multi_cursor.actions')
          local s = require('multi_cursor.state')
          a.add_cursor_vertical(1, 1)
          a.paste_multicursor(true)
          local st = s.current()
          local cols_p = {}
          for _, i in ipairs(s.sort_indices_asc(st)) do
            local p = s.cursor_pos(st, i)
            table.insert(cols_p, p.col)
          end
          table.sort(cols_p)
          local lines_p = vim.api.nvim_buf_get_lines(0, 0, -1, false)
          return { lines = lines_p, cols = cols_p }
        end
        """
        legacy, lua = self.run_both(body)
        self.assertEqual(lua, legacy)

    def test_multicursor_charwise_P_parity(self):
        body = """
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'ab', 'cd' })
        vim.api.nvim_win_set_cursor(0, { 1, 0 })
        vim.fn.setreg('"', 'X')

        if vim.g.loaded_visual_multi == 1 then
          vim.fn['vm#commands#add_cursor_down'](0, 1)
          vim.cmd('normal P')
          local vm = vim.b.VM_Selection
          local cols_P = {}
          for _, r in ipairs(vm.Regions) do
            table.insert(cols_P, r.a - 1)
          end
          table.sort(cols_P)
          local lines_P = vim.api.nvim_buf_get_lines(0, 0, -1, false)
          return { lines = lines_P, cols = cols_P }
        else
          local a = require('multi_cursor.actions')
          local s = require('multi_cursor.state')
          a.add_cursor_vertical(1, 1)
          a.paste_multicursor(false)
          local st = s.current()
          local cols_P = {}
          for _, i in ipairs(s.sort_indices_asc(st)) do
            local p = s.cursor_pos(st, i)
            table.insert(cols_P, p.col)
          end
          table.sort(cols_P)
          local lines_P = vim.api.nvim_buf_get_lines(0, 0, -1, false)
          return { lines = lines_P, cols = cols_P }
        end
        """
        legacy, lua = self.run_both(body)
        self.assertEqual(lua, legacy)

    def test_multicursor_linewise_p_parity(self):
        body = """
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'a', 'b' })
        vim.api.nvim_win_set_cursor(0, { 1, 0 })
        vim.fn.setreg('"', 'X\\n', 'V')

        if vim.g.loaded_visual_multi == 1 then
          vim.fn['vm#commands#add_cursor_down'](0, 1)
          vim.cmd('normal p')
          return { lines = vim.api.nvim_buf_get_lines(0, 0, -1, false) }
        else
          local a = require('multi_cursor.actions')
          a.add_cursor_vertical(1, 1)
          a.paste_multicursor(true)
          return { lines = vim.api.nvim_buf_get_lines(0, 0, -1, false) }
        end
        """
        legacy, lua = self.run_both(body)
        self.assertEqual(lua, legacy)

    def test_multicursor_linewise_P_parity(self):
        body = """
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'a', 'b' })
        vim.api.nvim_win_set_cursor(0, { 1, 0 })
        vim.fn.setreg('"', 'X\\n', 'V')

        if vim.g.loaded_visual_multi == 1 then
          vim.fn['vm#commands#add_cursor_down'](0, 1)
          vim.cmd('normal P')
          return { lines = vim.api.nvim_buf_get_lines(0, 0, -1, false) }
        else
          local a = require('multi_cursor.actions')
          a.add_cursor_vertical(1, 1)
          a.paste_multicursor(false)
          return { lines = vim.api.nvim_buf_get_lines(0, 0, -1, false) }
        end
        """
        legacy, lua = self.run_both(body)
        self.assertEqual(lua, legacy)
