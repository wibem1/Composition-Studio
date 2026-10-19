"""Install the bundled Lua source with only native state/message APIs; no network or shell."""
from pathlib import Path
from tempfile import TemporaryDirectory
import subprocess
from lupa.lua54 import LuaRuntime
root=Path(__file__).resolve().parents[1]
installer=(root/'Composition-Studio-Offline-Install.lua').read_text()
expected=(root/'Composition Studio.lua').read_bytes()
for ref in ('d307d19','340291c','3443e83','87fa72c'):
 previous=subprocess.check_output(['git','show',ref+':Composition Studio.lua'],cwd=root)
 with TemporaryDirectory() as d:
  target=Path(d)/"Wilhelm's Studio ä.lua";target.write_bytes(previous)
  messages=[];r=LuaRuntime(unpack_returned_tuples=True)
  # Providing no ExecProcess, HTTP, gfx or ImGui APIs proves none can be used.
  r.globals().reaper=r.table_from({'GetExtState':lambda *_:str(target),'SetExtState':lambda *_:None,'ShowMessageBox':lambda text,*_:messages.append(text)})
  r.execute(installer)
  assert target.read_bytes()==expected,messages
  assert Path(str(target)+'.backup').read_bytes()==previous
  assert any('Version 1.1.5 wurde installiert' in m for m in messages),messages
  print('PASS offline installation from',ref,'with exact original backup and no process/network APIs')
for failure in ('already-current','newer-current','missing-path','wrong-file','write-failure','rename-failure','corrupt-payload'):
 with TemporaryDirectory() as d:
  target=Path(d)/'registered.lua'
  previous=expected if failure=='already-current' else b'-- @version 1.1.4\nlocal SCRIPT_NAME="Composition Studio"\n'
  if failure=='newer-current':previous=previous.replace(b'1.1.4',b'9.9.9')
  if failure=='wrong-file':previous=b'unrelated file'
  target.write_bytes(previous);messages=[];r=LuaRuntime(unpack_returned_tuples=True)
  r.globals().reaper=r.table_from({'GetExtState':lambda *_:'' if failure=='missing-path' else str(target),'SetExtState':lambda *_:None,'ShowMessageBox':lambda text,*_:messages.append(text)})
  if failure=='write-failure':r.execute('local open=io.open;io.open=function(p,m)if p:match("%.pending$")then return nil end;return open(p,m)end')
  if failure=='rename-failure':r.execute('local rename=os.rename;os.rename=function(a,b)if a:match("%.pending$")then return nil,"blocked"end;return rename(a,b)end')
  code=installer.replace('local VERSION="1.1.5"','local =',1) if failure=='corrupt-payload' else installer
  r.execute(code)
  assert target.read_bytes()==previous,(failure,messages)
  assert messages,(failure,'No feedback')
  print('PASS offline installer preserves original on',failure)
