#!/bin/sh
set -eu

handy_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
settings_file="$handy_dir/settings_store.json"

sh -n "$handy_dir/install.sh"
sh -n "$handy_dir/export.sh"
sh -n "$handy_dir/status.sh"

python3 - "$settings_file" <<'PY'
import json
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
data = json.loads(path.read_text())
settings = data["settings"]
providers = {provider["id"] for provider in settings["post_process_providers"]}
prompts = {prompt["id"] for prompt in settings["post_process_prompts"]}
keys = settings.get("post_process_api_keys", {})
bindings = settings["bindings"]

assert keys and all(value == "" for value in keys.values()), "tracked API keys must be empty"
assert set(keys) == providers, "tracked API-key placeholders must match providers"
assert settings["post_process_enabled"] is True
assert settings["post_process_provider_id"] == "apple_intelligence"
assert settings["post_process_provider_id"] in providers
assert settings["post_process_selected_prompt_id"] in prompts
assert bindings["transcribe_with_post_process"]["current_binding"] == "option+space"
assert bindings["transcribe"]["current_binding"] == "option+shift+space"
assert bindings["transcribe"]["current_binding"] != bindings["transcribe_with_post_process"]["current_binding"]

serialized = path.read_text().lower()
for marker in ("sk-proj-", "sk-ant-", "api_key\": \"sk-"):
    assert marker not in serialized, f"possible credential in tracked settings: {marker}"
PY

echo "handy config verification: PASS"
