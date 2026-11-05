"""Install and execute a first UI frame using real temporary files and host mocks."""
from pathlib import Path
from tempfile import TemporaryDirectory
from lupa.lua54 import LuaRuntime
from build_semantic_test_installer import candidate_source, ROOT

installer = (ROOT / 'Composition-Studio-Semantic-Test-Install.lua').read_text()
expected = candidate_source()
assert 'local payload=[====[\n' + expected + ']====]' in installer

for failure in (None, 'rename', 'write'):
    with TemporaryDirectory(prefix="Wilhelm's Test ä ") as folder:
        root = Path(folder)
        stable = root / 'Scripts' / 'Composition Studio.lua'
        stable.parent.mkdir()
        stable.write_bytes(b'STABLE SOURCE MUST NOT CHANGE')
        startup = stable.parent / '__startup.lua'
        startup.write_bytes(b'UNCHANGED STARTUP')
        diagnosis = root / 'Composition-Studio-Last-Diagnosis.json'
        diagnosis.write_bytes(b'UNCHANGED STABLE DIAGNOSIS')
        namespace = 'CompositionStudioSemanticTest'
        saved = {('CompositionStudio', 'ActiveScriptPath'): str(stable),
                 ('CompositionStudio', 'WindowOpen'): '0',
                 ('CompositionStudio', 'GoogleAPIKey'): 'SENTINEL-KEY',
                 ('CompositionStudio', 'AIProvider'): 'google',
                 ('CompositionStudio', 'AIModel'): 'gemini-4-argon'}
        project, messages, registered = {}, [], []
        lua = LuaRuntime(unpack_returned_tuples=True)
        def get(section, key):
            return saved.get((section, key), '')
        def save(section, key, value, *_):
            assert section == namespace, (section, key)
            saved[section, key] = value
        def project_save(_, section, key, value):
            assert section == namespace
            project[section, key] = value
        lua.globals().reaper = lua.table_from({
            'GetResourcePath': lambda: folder,
            'RecursiveCreateDirectory': lambda p, *_: Path(p).mkdir(parents=True, exist_ok=True),
            'AddRemoveReaScript': lambda add, context, path, commit: registered.append(path) or 123,
            'GetExtState': get, 'SetExtState': save,
            'GetProjExtState': lambda _, section, key: (1, project.get((section, key), '')),
            'SetProjExtState': project_save,
            'ShowMessageBox': lambda text, *_: messages.append(text),
            'genGuid': lambda *_: '{TEST}', 'GetOS': lambda: 'OSX64',
            'EnumProjects': lambda *_: 1,
            'MIDIEditor_GetActive': lambda: None,
            'ImGui_CreateContext': lambda *_: lua.table(),
            'ImGui_CreateFont': lambda *_: lua.table(),
            'ImGui_Begin': lambda ctx, label, opened, *_: (True, opened),
            'ImGui_BeginPopup': lambda *_: False,
            'ImGui_Button': lambda *_: False, 'ImGui_MenuItem': lambda *_: False,
            'ImGui_BeginChild': lambda *_: False,
            'ImGui_GetContentRegionAvail': lambda *_: (360, 600),
            'ImGui_InputTextMultiline': lambda ctx, label, text, *_: (False, text),
            'defer': lambda fn: None,
        })
        # Unused reads/UI calls default to zero, every mutation API remains absent.
        lua.execute('''for k,v in pairs(reaper)do local fn=v;reaper[k]=function(...)return fn(...)end end
        setmetatable(reaper,{__index=function(_,key)
         if key:match("^ImGui_") then return function()return 0 end end
         if key:match("^Count") then return function()return 0 end end
         return nil
        end})''')
        if failure == 'rename':
            lua.execute('os.rename=function()return nil,"fixture rename failure"end')
        if failure == 'write':
            lua.execute('local open=io.open;io.open=function(p,m)if m=="wb"then return nil end;return open(p,m)end')
        lua.execute(installer)
        target = root / 'Scripts/CompositionStudioSemanticTest/Composition Studio Semantic Test.lua'
        if failure:
            assert messages and not registered and not target.exists()
        else:
            assert not messages, messages
            assert registered == [str(target)]
            assert target.read_text() == expected
            assert saved[namespace, 'WindowOpen'] == '1'
            assert (namespace, 'ActiveScriptPath') not in saved
        assert startup.read_bytes() == b'UNCHANGED STARTUP'
        assert stable.read_bytes() == b'STABLE SOURCE MUST NOT CHANGE'
        assert diagnosis.read_bytes() == b'UNCHANGED STABLE DIAGNOSIS'
        assert saved['CompositionStudio', 'ActiveScriptPath'] == str(stable)
        assert saved['CompositionStudio', 'WindowOpen'] == '0'
        assert saved['CompositionStudio', 'GoogleAPIKey'] == 'SENTINEL-KEY'
        print('PASS isolated installer:', failure or 'install, register, first UI frame, separate state and stable/autostart preservation')
