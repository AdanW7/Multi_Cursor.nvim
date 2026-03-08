from tests.nvim_case import NvimCase


class TestBackendSwitch(NvimCase):
    def test_same_opts_table_works_by_backend_flip(self):
        shared_opts = (
            "leader = { default = '<leader>m', visual = '<leader>m', buffer = '<leader>m' }, "
            "mappings = { add_cursor_down = 'C', add_cursor_up = '<leader>mk' }, "
            "theme = 'iceblue', use_visual_mode = true"
        )

        body = """
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'a', 'b', 'c' })
        vim.api.nvim_win_set_cursor(0, { 1, 0 })
        vim.cmd('normal C')

        if vim.g.loaded_visual_multi == 1 then
          local vm = vim.b.VM_Selection
          return { total = (vm and vm.Regions) and #vm.Regions or 0 }
        else
          local st = require('multi_cursor.state').current()
          return { total = #st.cursors }
        end
        """

        legacy = self.run_case(body, setup_opts="{ backend = 'legacy', " + shared_opts + " }")
        lua = self.run_case(body, setup_opts="{ backend = 'lua', " + shared_opts + " }")
        self.assertEqual(legacy["total"], 2)
        self.assertEqual(lua, legacy)
