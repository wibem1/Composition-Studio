"""Exercise the user-triggered local AI diagnosis export with mocked REAPER ports."""
import json
from pathlib import Path
from lupa import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
source = (ROOT / "src/ai/local_components.lua").read_text()
lua = LuaRuntime(unpack_returned_tuples=True)
written = {}

reaper = lua.table()
reaper.GetExtState = lambda section, key: {
    "LocalDDSPPythonV1": r"C:\\AI Music Studio\\python\\python.exe",
    "LocalDDSPWorkerV1": r"C:\\AI Music Studio\\midi_ddsp_worker.py",
}.get(key, "")
reaper.SetExtState = lambda *args: None
reaper.GetUserFileName = lambda mode, caption, initial, extensions: (
    (mode == 0), str(ROOT / "diagnosis.json")
)
reaper.ImGui_Text = lambda *args: None
reaper.ImGui_TextWrapped = lambda *args: None
reaper.ImGui_Separator = lambda *args: None
reaper.ImGui_Button = lambda ctx, label, *args: label == "Diagnose exportieren"
lua.globals().reaper = reaper
lua.globals().EXT_SECTION = "CompositionStudio"
lua.globals().IS_WINDOWS = True
lua.globals().TEMP_DIR = str(ROOT)
lua.globals().ps_quote = lambda value: "'" + value + "'"
lua.globals().ps_launch = lambda *args: False
lua.globals().temp_path = lambda suffix: str(ROOT / ("temp" + suffix))
lua.globals().read_file = lambda *args: None
lua.globals().write_file = lambda path, content: written.update(path=str(path), content=str(content)) or True
lua.globals().json_escape = lambda value: json.dumps(str(value), ensure_ascii=False)[1:-1]
lua.globals().trim = lambda value: str(value).strip()

manager = lua.execute(source).ai_component_manager
manager.draw(0)
assert written["path"].endswith("diagnosis.json")
report = json.loads(written["content"])
assert report["schema"] == "composition-studio.local-ai/v1"
assert report["component"] == "MIDI-DDSP"
assert report["python"].endswith("python.exe")
assert report["worker"].endswith("midi_ddsp_worker.py")
assert report["imports_ok"] is False and report["weights_found"] is False
assert "Diagnose gespeichert" in manager.status
print("PASS explicit diagnosis export uses REAPER's new-file dialog and emits valid JSON")
