"""Install, load skills/hooks through Codex app-server, and uninstall in isolation."""
import json
import os
from pathlib import Path
import queue
import subprocess
import tempfile
import threading

ROOT = Path(__file__).resolve().parents[1]
PLUGIN_ID = "oh-my-agents@oh-my-agents-codex"


def cli(env, *args):
    result = subprocess.run(["codex", "plugin", *args, "--json"],
                            capture_output=True, text=True, check=True, env=env, timeout=30)
    return json.loads(result.stdout)


def check_discovery(env):
    with tempfile.TemporaryFile() as errors:
        server = subprocess.Popen(["codex", "app-server"], stdin=subprocess.PIPE,
                                  stdout=subprocess.PIPE, stderr=errors,
                                  text=True, env=env)
        messages = queue.Queue()

        def read():
            for line in server.stdout:
                messages.put(json.loads(line))
            messages.put(None)

        reader = threading.Thread(target=read, daemon=True)
        reader.start()

        def request(identifier, method, params):
            server.stdin.write(json.dumps(dict(id=identifier, method=method, params=params)) + "\n")
            server.stdin.flush()
            while True:
                message = messages.get(timeout=20)
                if message is None:
                    raise RuntimeError("Codex app-server exited before discovery")
                if message.get("id") == identifier:
                    if "error" in message:
                        raise RuntimeError(f"{method}: {message['error']}")
                    return message["result"]

        try:
            request(1, "initialize", dict(clientInfo=dict(name="oma-smoke", version="1"),
                                          capabilities=dict(experimentalApi=True)))
            server.stdin.write('{"method":"initialized"}\n')
            server.stdin.flush()
            plugin = request(2, "plugin/read", dict(pluginName="oh-my-agents",
                             marketplacePath=str(ROOT / ".agents/plugins/marketplace.json")))["plugin"]
            expected = {"oh-my-agents:" + p.parent.name for p in (ROOT / "skills").glob("*/SKILL.md")}
            actual = {skill["name"] for skill in plugin["skills"]}
            assert actual == expected, (actual, expected)
            assert len(plugin["hooks"]) == 5, plugin["hooks"]
            listing = request(3, "skills/list", dict(cwds=[str(ROOT)], forceReload=True))
            records = listing["data"][0]
            assert not records.get("errors"), records.get("errors")
            installed_skills = [s for s in records["skills"] if s.get("pluginId") == PLUGIN_ID]
            assert {s["name"] for s in installed_skills} == expected
            for skill in installed_skills:
                assert skill["enabled"] and skill.get("interface"), skill["name"]
                assert Path(skill["path"]).is_file(), skill["path"]
            hooks = request(4, "hooks/list", dict(cwds=[str(ROOT)]))["data"][0]
            assert not hooks.get("errors"), hooks.get("errors")
            installed_hooks = [h for h in hooks["hooks"] if h.get("pluginId") == PLUGIN_ID]
            assert len(installed_hooks) == 5
            for hook in installed_hooks:
                assert "${PLUGIN_ROOT}" not in hook["command"], hook["command"]
                # A fresh install must not silently bypass native command-hook trust.
                assert hook["trustStatus"] == "untrusted", hook["trustStatus"]
            print("PASS: Codex discovers 11 namespaced skills, metadata and 5 untrusted hook registrations")
        finally:
            server.terminate()
            try:
                server.wait(timeout=5)
            except subprocess.TimeoutExpired:
                server.kill()
                server.wait()
            server.stdin.close()
            server.stdout.close()
            reader.join(timeout=1)


def main():
    with tempfile.TemporaryDirectory(prefix="oma-codex-smoke-") as directory:
        env = dict(os.environ)
        # CODEX_HOME is used for its intended isolated configuration purpose.
        env["CODEX_HOME"] = directory
        market = cli(env, "marketplace", "add", str(ROOT))
        assert market["marketplaceName"] == "oh-my-agents-codex", market
        install = cli(env, "add", PLUGIN_ID)
        assert install["pluginId"] == PLUGIN_ID, install
        assert Path(install["installedPath"], ".codex-plugin/plugin.json").is_file()
        listed = cli(env, "list")["installed"]
        assert len(listed) == 1 and listed[0]["enabled"], listed
        print("PASS: local marketplace installs the native Codex plugin")
        cli(env, "add", PLUGIN_ID)
        assert len(cli(env, "list")["installed"]) == 1
        print("PASS: repeated installation preserves one plugin")
        check_discovery(env)
        cli(env, "remove", PLUGIN_ID)
        assert not cli(env, "list")["installed"]
        cli(env, "marketplace", "remove", "oh-my-agents-codex")
        print("PASS: uninstall and marketplace removal complete in isolated configuration")


if __name__ == "__main__":
    main()
