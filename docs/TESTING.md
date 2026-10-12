# Testing

Run from the plugin checkout. Required tools are Bash, Git, jq, Python 3.10+ and flock.

```bash
bash tests/test-hooks.sh
python3 -m unittest discover -s tests -p 'test_*.py'
```

The shell suite covers deterministic layer/secret/plan checks, project-root addressing,
metrics, hook output channels and signal freshness. Python tests exercise actual Codex
apply_patch inputs, multi-file/move/EOF edits, full JSON reconstruction, blocking results,
credential redaction, error handling, metrics, and explicit gate decisions.
Package/skill tests check supported metadata, portable paths and internal links.

An additional real-CLI smoke test requires Codex 0.162.1+:

```bash
bash tests/test-plugin-install.sh
```

It uses an isolated temporary CODEX_HOME for its intended configuration purpose, then
registers the local marketplace, installs/lists/removes the plugin. It never overwrites a
user's existing Codex home or copies authentication. This verifies the real loader rather
than relying on a locally invented manifest validator. No model invocation or API key is
needed. Hook process behavior is tested with actual documented event payloads; cloud host
hook admission and authenticated model behavior are separate capabilities.

Some sandbox hosts place placeholder .git directories under /tmp or /workspace. The
suppression test now creates a real Git fixture root so ancestor markers cannot redirect it.
Other fixture roots are already real repositories or use explicit root overrides. Tests
must complete with nonzero exit on failure; do not mask validation errors with `|| true`.

CI runs these checks on the Codex branch. Project templates fail on unset command inputs;
users must supply actual lint/test/architecture commands, not passing TODO placeholders.
