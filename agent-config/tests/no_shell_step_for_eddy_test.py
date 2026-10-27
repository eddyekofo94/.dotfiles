#!/usr/bin/env python3
"""No hook's refusal or closeout text asks Eddy to run a shell step (BS-IOS-BUG-670 D4).

    python3 agent-config/tests/no_shell_step_for_eddy_test.py

A guard that holds a tab is lifted by his message in that tab; the agent runs any
command itself. Every string literal in `agent-config/claude/*.py` other than a
docstring is checked for a `! <command>` line or a trip to a plain terminal. A secret
only Eddy may type (`security add-generic-password`) is not one of these commands.
"""

import ast
import re
import unittest
from pathlib import Path

HOOKS = Path(__file__).resolve().parents[1] / "claude"
ASK = re.compile(r"(?<![\w!=])! ?(touch|mv|rm|cp|mkdir|chmod|ln|kill|python3|git|tools/|herdr[\w-]*)\b"
                 r"|(from|in) a plain terminal|\bhimself\b")


def asks(source: str) -> list[tuple[int, str]]:
    """(line, text) of each non-docstring literal that asks Eddy for a shell step."""
    tree = ast.parse(source)
    docs = {id(node.body[0].value) for node in ast.walk(tree)
            if isinstance(node, (ast.Module, ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef))
            and node.body and isinstance(node.body[0], ast.Expr)
            and isinstance(node.body[0].value, ast.Constant)}
    return [(node.lineno, node.value) for node in ast.walk(tree)
            if isinstance(node, ast.Constant) and isinstance(node.value, str)
            and id(node) not in docs and ASK.search(node.value)]


class NoShellStep(unittest.TestCase):
    def test_the_matcher_catches_the_old_unlock(self):
        old = 'def reason(e):\n    return f"park now. Eddy extends with: ! touch {e}"\n'
        self.assertTrue(asks(old))
        self.assertTrue(asks('x = "run that release himself from a plain terminal pane"\n'))
        self.assertFalse(asks('"""Docs may say `! touch` was the old unlock."""\nx = "done!"\n'))

    def test_no_hook_asks(self):
        found = [f"{path.name}:{line}: {text[:90]!r}" for path in sorted(HOOKS.glob("*.py"))
                 for line, text in asks(path.read_text(errors="replace"))]
        self.assertEqual(found, [])


if __name__ == "__main__":
    unittest.main()
