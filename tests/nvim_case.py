import json
import os
import subprocess
import tempfile
import textwrap
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


class NvimCase(unittest.TestCase):
    def run_case(
        self,
        lua_body: str,
        setup_opts: str = "{ backend = 'lua' }",
        pre_setup_lua: str = "",
    ):
        script = textwrap.dedent(
            f"""
            vim.opt.rtp:append('{ROOT.as_posix()}')
            {pre_setup_lua}
            require('multi_cursor').setup({setup_opts})

            local ok, result = pcall(function()
              {lua_body}
            end)

            if not ok then
              error(result)
            end

            local out = os.getenv('MC_TEST_OUT')
            local f = assert(io.open(out, 'w'))
            f:write(vim.json.encode(result or {{}}))
            f:close()
            """
        )

        with tempfile.NamedTemporaryFile("w", suffix=".lua", delete=False) as lf:
            lf.write(script)
            lua_path = lf.name

        with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as of:
            out_path = of.name

        env = os.environ.copy()
        env["MC_TEST_OUT"] = out_path

        cmd = [
            "nvim",
            "--headless",
            "-u",
            "NONE",
            "-i",
            "NONE",
            "-n",
            "-c",
            "set shadafile=NONE noswapfile",
            "-c",
            f'lua dofile("{lua_path}")',
            "-c",
            "qa!",
        ]

        try:
            completed = subprocess.run(cmd, check=True, capture_output=True, text=True, env=env)
            err = completed.stderr.strip()
            if err and ("Error detected" in err or "E5108" in err or "Traceback" in err):
                self.fail(f"nvim stderr indicates failure: {completed.stderr}")
            with open(out_path, encoding="utf-8") as f:
                return json.loads(f.read() or "{}")
        finally:
            for p in (lua_path, out_path):
                try:
                    os.unlink(p)
                except FileNotFoundError:
                    pass
