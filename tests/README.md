# Multi_Cursor.nvim Tests

This test suite validates both backends and guards Lua/legacy behavior parity.

## What These Tests Protect

- Core Lua backend behavior (modes, operators, mappings, registers, commands).
- Legacy backend loading and VM compatibility shims.
- Cross-backend parity for high-value workflows.

## Run Everything

```bash
cd /path/to/Multi_Cursor.nvim
uv sync
uv run ruff check .
uv run pyrefly check tests
uv run pytest -q
```

## Run Parity-Focused Subset

```bash
uv run python -m pytest -q tests/test_backend_parity_subset.py tests/test_legacy_parity.py tests/test_backend_switch.py
```

## Useful Files

- `tests/test_lua_tools.py`: Lua behavior and regression tests.
- `tests/test_lua_core.py`: Lua command surface + compatibility aliases.
- `tests/test_backend_parity_subset.py`: direct Lua vs legacy comparisons.
- `tests/test_legacy_parity.py`: legacy backend smoke/parity checks.
