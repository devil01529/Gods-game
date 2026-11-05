"""Configure local Godot editor paths without writing machine paths or keys to Git."""
import os
import re
from pathlib import Path

config = Path(os.environ.get("XDG_CONFIG_HOME", str(Path.home() / ".config"))) / "godot/editor_settings-4.6.tres"
if not config.exists():
    raise SystemExit("Run godot --headless --editor --import --quit first.")
settings = {
    "export/android/android_sdk_path": os.environ.get("ANDROID_HOME", os.environ.get("ANDROID_SDK_ROOT", "")),
    "export/android/java_sdk_path": os.environ.get("JAVA_HOME", ""),
}
text = config.read_text()
for key, value in settings.items():
    if not value or not Path(value).is_dir():
        raise SystemExit(f"Set a valid path for {key} using ANDROID_HOME and JAVA_HOME.")
    line = f'{key} = "{value}"'
    pattern = rf"^{re.escape(key)} = .*?$"
    if re.search(pattern, text, flags=re.M):
        text = re.sub(pattern, lambda _: line, text, flags=re.M)
    else:
        text = text.replace("[resource]", "[resource]\n" + line)
config.write_text(text)
print("Configured local Android SDK and Java SDK paths.")
