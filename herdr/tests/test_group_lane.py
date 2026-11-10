"""The lane data, web and API share (BibleStandard BS-IOS-TASK-1619 D4, D5)."""
import importlib.util, json, pathlib, sys, tempfile, unittest

SCRIPT = pathlib.Path(__file__).resolve().parents[1] / "group_lane.py"
spec = importlib.util.spec_from_file_location("group_lane", SCRIPT)
group_lane = importlib.util.module_from_spec(spec)
sys.modules["group_lane"] = group_lane
spec.loader.exec_module(group_lane)

CLAUDE = "claude --model opus --effort medium --permission-mode auto"
HOLDER = {100: (1, f"{CLAUDE} /build BS-DATA-BUG-81")}
CALLER_PID = 200


def table(caller_boot: str, extra: dict | None = None) -> dict:
    """A check run from a shell under a `claude` booted `caller_boot`."""
    return {**HOLDER, 150: (1, f"{CLAUDE} {caller_boot}".rstrip()), CALLER_PID: (150, "/bin/zsh -c x"),
            **(extra or {})}


class GroupLane(unittest.TestCase):
    def setUp(self) -> None:
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.data = pathlib.Path(tmp.name)

    def plant_data(self, *held: str) -> None:
        (self.data / "tools").mkdir()
        (self.data / "tools/session_worktree.py").write_text(f"print({json.dumps(json.dumps({'held': list(held)}))})\n")

    def check(self, ident: str, tab: dict, opener: bool = False) -> str:
        return group_lane.holder(ident, opener, tab, CALLER_PID, self.data)

    def test_free_when_nothing_holds_it(self) -> None:
        self.assertEqual(self.check("BS-WEB-FEAT-2", {150: (1, f"{CLAUDE} /build BS-WEB-FEAT-2"),
                                                     CALLER_PID: (150, "zsh")}), "")

    def test_held_by_another_id_names_it(self) -> None:
        self.assertEqual(self.check("BS-API-TASK-3", table("/build BS-API-TASK-3")), "BS-DATA-BUG-81 (pid 100)")

    def test_its_own_id_passes(self) -> None:
        self.assertEqual(self.check("BS-DATA-BUG-81", table("/build BS-DATA-BUG-81")), "")

    def test_a_hand_opened_caller_passes(self) -> None:
        self.assertEqual(self.check("BS-API-TASK-3", table("")), "")
        self.assertEqual(self.check("BS-API-TASK-3", table("/spec BS-API-TASK-3")), "")

    def test_no_claude_above_the_caller_passes(self) -> None:
        self.assertEqual(self.check("BS-API-TASK-3", {**HOLDER, CALLER_PID: (1, "/bin/zsh")}), "")

    def test_a_chain_opener_is_always_gated(self) -> None:
        self.assertEqual(self.check("BS-API-TASK-3", {**HOLDER, CALLER_PID: (1, "/bin/bash goal_done.sh")}, opener=True),
                         "BS-DATA-BUG-81 (pid 100)")

    def test_an_app_build_or_a_mention_holds_nothing(self) -> None:
        tab = {150: (1, f"{CLAUDE} /build BS-WEB-FEAT-2"), CALLER_PID: (150, "zsh"),
               300: (1, f"{CLAUDE} /build BS-IOS-TASK-1619"),
               301: (1, "/bin/zsh -c grep /build BS-DATA-BUG-81"),
               302: (1, f"{CLAUDE} /spec BS-DATA-BUG-9 see /build BS-DATA-BUG-81")}
        self.assertEqual(self.check("BS-WEB-FEAT-2", tab), "")

    def test_a_finishing_tab_handing_over_holds_nothing_against_its_successor(self) -> None:
        tab = {150: (1, f"{CLAUDE} /build BS-DATA-BUG-81"), CALLER_PID: (150, "/bin/bash goal_done.sh")}
        self.assertEqual(self.check("BS-DATA-BUG-90", tab, opener=True), "BS-DATA-BUG-81 (pid 150)")
        self.assertEqual(group_lane.holder("BS-DATA-BUG-90", True, tab, CALLER_PID, self.data, handing_over=True), "")
        tab[300] = (1, f"{CLAUDE} /build BS-WEB-FEAT-2")
        self.assertEqual(group_lane.holder("BS-DATA-BUG-90", True, tab, CALLER_PID, self.data, handing_over=True),
                         "BS-WEB-FEAT-2 (pid 300)")

    def test_the_boot_is_the_first_word_after_the_flags(self) -> None:
        cases = {"claude --model opus Opus: fix it, then /build BS-DATA-BUG-5 later": None,
                 "claude --add-dir /tmp /build BS-DATA-BUG-5": ("/build", "BS-DATA-BUG-5"),
                 "claude --dangerously-skip-permissions /build BS-WEB-FEAT-2": ("/build", "BS-WEB-FEAT-2"),
                 "claude --model opus /build bs-web-feat-2 — track Web": ("/build", "BS-WEB-FEAT-2"),
                 "/opt/bin/codex /build BS-API-TASK-3": ("/build", "BS-API-TASK-3"),
                 "node /usr/local/bin/pi /build BS-API-TASK-3": ("/build", "BS-API-TASK-3"),
                 "grep claude /build BS-DATA-BUG-1": None,
                 "claude": None}
        for command, want in cases.items():
            self.assertEqual(group_lane.boot(command), want, command)

    def test_a_data_checkout_holds_it(self) -> None:
        self.plant_data("bs-data-task-7")
        tab = {150: (1, f"{CLAUDE} /build BS-WEB-FEAT-2"), CALLER_PID: (150, "zsh")}
        self.assertEqual(self.check("BS-WEB-FEAT-2", tab), "data checkout bs-data-task-7")
        self.assertEqual(self.check("BS-DATA-TASK-7", {150: (1, f"{CLAUDE} /build BS-DATA-TASK-7"),
                                                       CALLER_PID: (150, "zsh")}), "")

    def test_an_id_outside_the_group_passes(self) -> None:
        self.assertEqual(self.check("BS-IOS-TASK-1", table("/build BS-IOS-TASK-1")), "")


if __name__ == "__main__":
    unittest.main()
