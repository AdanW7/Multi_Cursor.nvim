from tests.nvim_case import NvimCase


class TestLegacyParity(NvimCase):
    def test_legacy_backend_loads_visual_multi(self):
        result = self.run_case(
            """
            return {
              loaded = vim.g.loaded_visual_multi == 1,
              vm_clear = vim.fn.exists(':VMClear') == 2,
              vm_search = vim.fn.exists(':VMSearch') == 2,
              alias_clear = vim.fn.exists(':MultiCursorClear') == 2,
            }
            """,
            setup_opts="{ backend = 'legacy' }",
        )
        self.assertTrue(result["loaded"])
        self.assertTrue(result["vm_clear"])
        self.assertTrue(result["vm_search"])
        self.assertTrue(result["alias_clear"])

    def test_legacy_backend_respects_vm_maps_override(self):
        result = self.run_case(
            """
            local map = vim.fn.maparg('C', 'n', false, true)
            return {
              lhs = map.lhs or '',
              rhs = map.rhs or '',
            }
            """,
            setup_opts="{ backend = 'legacy' }",
            pre_setup_lua="vim.g.VM_maps = { ['Add Cursor Down'] = 'C' }",
        )
        self.assertEqual(result["lhs"], "C")
        self.assertIn("VM-Add-Cursor-Down", result["rhs"])

    def test_legacy_backend_mapping_parity_checklist(self):
        result = self.run_case(
            """
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'alpha beta alpha', 'gamma alpha' })
            vim.api.nvim_win_set_cursor(0, { 1, 0 })
            vim.fn['vm#commands#find_under'](0, 1)

            local expected = {}
            local function add_expected(tbl)
              for name, spec in pairs(tbl or {}) do
                local lhs = spec[1]
                local mode = spec[2]
                if type(lhs) == 'string' and lhs ~= '' and (mode == 'n' or mode == 'x') then
                  local plug = '<Plug>(VM-' .. string.gsub(name, ' ', '-') .. ')'
                  table.insert(expected, { name = name, lhs = lhs, mode = mode, plug = plug })
                end
              end
            end

            add_expected(vim.fn['vm#maps#all#permanent']())
            add_expected(vim.fn['vm#maps#all#buffer']())

            local missing = {}
            for _, e in ipairs(expected) do
              local m = vim.fn.maparg(e.lhs, e.mode, false, true)
              local rhs = (type(m) == 'table' and m.rhs) and m.rhs or ''
              if rhs == '' or not string.find(rhs, e.plug, 1, true) then
                table.insert(missing, {
                  name = e.name,
                  lhs = e.lhs,
                  mode = e.mode,
                  expected = e.plug,
                  got = rhs,
                })
              end
            end

            return {
              total_expected = #expected,
              missing_total = #missing,
              missing = missing,
              vm_active = vim.b.VM_Selection ~= nil,
            }
            """,
            setup_opts="{ backend = 'legacy' }",
        )
        self.assertTrue(result["vm_active"])
        self.assertGreater(result["total_expected"], 0)
        self.assertEqual(result["missing_total"], 0, msg=str(result["missing"][:10]))

    def test_legacy_backend_accepts_lua_style_opts(self):
        result = self.run_case(
            """
            local map = vim.g.VM_maps or {}
            local leader = vim.g.VM_leader
            local leader_default = type(leader) == 'table' and leader.default or leader
            return {
              add_cursor_down = map['Add Cursor Down'],
              select_all = map['Select All'],
              leader_default = leader_default,
              theme = vim.g.VM_theme,
              use_visual_mode = vim.g.VM_use_visual_mode,
            }
            """,
            setup_opts=(
                "{ backend = 'legacy', leader = { default = '<leader>m', visual = '<leader>m', "
                "buffer = '<leader>m' }, theme = 'iceblue', use_visual_mode = true, "
                "mappings = { add_cursor_down = 'C', select_all = '<leader>mA' } }"
            ),
        )
        self.assertEqual(result["add_cursor_down"], "C")
        self.assertEqual(result["select_all"], "<leader>mA")
        self.assertEqual(result["leader_default"], "<leader>m")
        self.assertEqual(result["theme"], "iceblue")
        self.assertEqual(result["use_visual_mode"], 1)
