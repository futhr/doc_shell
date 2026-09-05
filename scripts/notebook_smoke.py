#!/usr/bin/env python3
"""Run executable notebook cells against the checkout, replacing Mix.install.

Livebook-only installation cells and explicitly non-evaluated examples are
excluded. Each notebook runs in a fresh BEAM instance with the project's deps.
"""
import os
from pathlib import Path
import re
import subprocess
import tempfile

repo = Path(__file__).resolve().parent.parent
notebooks = sorted((repo / "notebooks").glob("*.livemd"))
assert notebooks, "No notebooks found"
for notebook in notebooks:
    cells = []
    fence = None
    language = None
    lines = []
    skip_next = False
    for line in notebook.read_text().splitlines(keepends=True):
        if fence is None:
            if '"eval":false' in line.replace(" ", ""):
                skip_next = True
            match = re.fullmatch(r"(`{3,})([^`\n]*)\n?", line)
            if match:
                fence, language = match.groups()
                lines = []
        elif line.strip() == fence:
            source = "".join(lines)
            if language == "elixir" and not skip_next and "Mix.install(" not in source:
                cells.append(source)
            fence = None
            skip_next = False
        else:
            lines.append(line)
    assert fence is None, f"Unclosed fence in {notebook}"
    assert cells, f"No executable examples in {notebook}"
    with tempfile.TemporaryDirectory(prefix="doc-shell-notebook-") as root:
        script = Path(root) / "examples.exs"
        script.write_text("\n\n".join(cells))
        subprocess.run(["mix", "run", str(script)], cwd=repo,
                       env={**os.environ, "MIX_ENV": "dev"}, check=True)
    print(f"Passed {notebook.name}: {len(cells)} code cells", flush=True)
