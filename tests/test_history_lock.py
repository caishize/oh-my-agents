import concurrent.futures
import fcntl
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

COMMON = Path(os.environ.get("OHMA_HISTORY_COMMON", Path(__file__).resolve().parents[1] / "hooks/lib/common.sh")).resolve()
BASH = shutil.which("bash")


class HistoryLockTests(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.root = Path(tmp.name)
        self.dir = self.root / "metrics"
        self.dir.mkdir()
        self.file = self.dir / "verify.jsonl"
        self.lock = self.dir / "verify.jsonl.lock"
        self.bin = self.root / "bin"
        self.bin.mkdir()
        for name in ("mkdir", "tr"):
            (self.bin / name).symlink_to(shutil.which(name))
        (self.bin / "python3").symlink_to(sys.executable)

    def append(self, record, backend=None, **kwargs):
        env = dict(os.environ)
        if backend is not None:
            env["PATH"] = str(self.bin)
        return subprocess.run(
            [BASH, "-c", 'source "$1"; append_history_record "$2" verify.jsonl "$3"',
             "history-test", str(COMMON), str(self.dir), json.dumps(record)],
            capture_output=True, text=True, timeout=8, env=env, **kwargs,
        )

    def assert_contended(self, backend):
        self.file.write_text('{"old":true}\n', encoding="utf-8")
        with self.lock.open("ab") as handle:
            fcntl.flock(handle, fcntl.LOCK_EX)
            run = self.append({"new": 1}, backend)
            self.assertNotEqual(run.returncode, 0)
            self.assertIn("append_history_record:", run.stderr)
            self.assertEqual(self.file.read_bytes(), b'{"old":true}\n')
        self.assertEqual(self.append({"after": 1}, backend).returncode, 0)

    @unittest.skipUnless(shutil.which("flock"), "flock CLI unavailable")
    def test_cli_respects_same_real_lock(self):
        self.assert_contended(None)

    def test_python_respects_same_real_lock(self):
        self.assert_contended("python")

    def test_lock_open_failure_never_writes(self):
        self.lock.mkdir()
        for backend in (None, "python"):
            with self.subTest(backend=backend):
                run = self.append({"blocked": 1}, backend)
                self.assertNotEqual(run.returncode, 0)
                self.assertIn("append_history_record:", run.stderr)
                self.assertFalse(self.file.exists())

    def test_ledger_write_failure_is_reported(self):
        self.file.mkdir()
        for backend in (None, "python"):
            with self.subTest(backend=backend):
                run = self.append({"blocked": 1}, backend)
                self.assertNotEqual(run.returncode, 0)
                self.assertIn("append_history_record:", run.stderr)

    @unittest.skipUnless(shutil.which("jq"), "jq unavailable")
    def test_jq_cannot_replace_a_lock_backend(self):
        (self.bin / "python3").unlink()
        (self.bin / "jq").symlink_to(shutil.which("jq"))
        run = self.append({"blocked": 1}, "jq-only")
        self.assertNotEqual(run.returncode, 0)
        self.assertIn("no lock backend available", run.stderr)
        self.assertFalse(self.file.exists())

    @unittest.skipUnless(shutil.which("jq") and shutil.which("flock"), "jq/flock unavailable")
    def test_jq_and_cli_work_without_python(self):
        (self.bin / "python3").unlink()
        (self.bin / "jq").symlink_to(shutil.which("jq"))
        (self.bin / "flock").symlink_to(shutil.which("flock"))
        run = self.append({"cli": 1}, "jq-and-flock")
        self.assertEqual(run.returncode, 0, run.stderr)
        self.assertEqual(json.loads(self.file.read_bytes()), {"cli": 1})

    def test_mixed_writers_record_each_entry_once(self):
        records = [{"worker": i, "payload": "多" * 900} for i in range(24)]
        with concurrent.futures.ThreadPoolExecutor(max_workers=8) as executor:
            results = list(executor.map(
                lambda pair: self.append(pair[1], "python" if pair[0] % 2 else None),
                enumerate(records),
            ))
        self.assertEqual([r.stderr for r in results if r.returncode], [])
        actual = [json.loads(line) for line in self.file.read_text(encoding="utf-8").splitlines()]
        self.assertEqual(sorted(actual, key=lambda record: record["worker"]), records)


if __name__ == "__main__":
    unittest.main()
