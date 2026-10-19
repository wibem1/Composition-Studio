"""Execute the standalone updater on real temporary files with simulated HTTP outcomes."""
from pathlib import Path
import shlex,tempfile,re
from lupa.lua54 import LuaRuntime
root=Path(__file__).resolve().parents[1]
helper=(root/'Composition-Studio-Update.lua').read_text()
fresh=(root/'Composition Studio.lua').read_text()
old='-- @version 1.0.75\nlocal SCRIPT_NAME="Composition Studio"\n'+'-- original\n'*100

def case(name,statuses=('200',),payload=fresh,installed=old,cancel=False,rename_failure=False,windows=False):
 with tempfile.TemporaryDirectory() as d:
  folder=Path(d);target=folder/'registered studio.lua';target.write_text(installed)
  r=LuaRuntime(unpack_returned_tuples=True);r.globals().TARGET=str(target);r.globals().ROOT=str(folder)
  calls=[];messages=[];deferred=[]
  def execute(command,timeout):
   if windows:
    ps=Path(shlex.split(command)[-1]).read_text(encoding='utf-8-sig')
    out=Path(re.search(r"WriteAllBytes\('([^']+)',\$bytes\)",ps).group(1))
    pending=re.search(r"WriteAllText\('([^']+)',\$code\)",ps).group(1)
    assert 'FromSeconds(20)' in ps and 'SecurityProtocolType]::Tls12' in ps
   else:
    # Parse the shipped Unix command rather than replacing fetch_update.
    argv=shlex.split(command)
    assert len(argv)==2 and argv[0]=='/bin/sh' and Path(argv[1]).suffix=='.sh'
    shell_script=Path(argv[1]).read_text()
    lexer=shlex.shlex(shell_script,posix=True,punctuation_chars=';');lexer.whitespace_split=True
    tokens=list(lexer);out=Path(tokens[tokens.index('-o')+1]);pending=tokens[tokens.index('>')+1]
   status=statuses[min(len(calls),len(statuses)-1)];calls.append(ps if windows else shell_script)
   if not cancel:
    out.write_text(payload);Path(pending.removesuffix('.pending')).write_text(status)
   return ''
  api=r.table_from({'GetExtState':lambda *_:str(target),'GetOS':lambda:'Win64' if windows else 'Linux','GetResourcePath':lambda:str(folder),
   'RecursiveCreateDirectory':lambda path,*_:Path(path).mkdir(exist_ok=True),
   'ExecProcess':execute,'time_precise':lambda:0,'SetExtState':lambda *_:None,
   'ShowMessageBox':lambda text,*_:messages.append(text),'defer':lambda fn:deferred.append(fn)})
  r.globals().reaper=api
  r.execute('gfx={init=function()end,quit=function()end,getchar=function()return 0 end,set=function()end,rect=function()end,drawstr=function()end,update=function()end,w=440,h=90}')
  if cancel:r.execute('gfx.getchar=function()return -1 end')
  if rename_failure:r.execute('local rename=os.rename;os.rename=function(a,b)if a:match("%.pending$")then return nil,"simulated permission error"end;return rename(a,b)end')
  r.execute(helper)
  for _ in range(5):
   if not deferred:break
   deferred.pop(0)()
  assert not deferred,(name,"unexpected waiting")
  changed=name in ('install','fallback','windows-install','windows-fallback')
  assert target.read_text()==(fresh if changed else installed),(name,messages)
  if changed:assert Path(str(target)+'.backup').read_text()==installed
  if name=='fallback':assert len(calls)==2 and 'api.github.com' in calls[1]
  if name=='windows-fallback':assert len(calls)==2
  if name=='cancel':assert any('abgebrochen' in x for x in messages)
  else:assert messages,(name,'No visible completion message')
  assert not Path(str(target)+'.pending').exists()
  print('PASS standalone updater:',name)
for kwargs in [dict(name='install'),dict(name='fallback',statuses=('503','200')),
 dict(name='windows-install',windows=True),dict(name='windows-fallback',windows=True,statuses=('503','200')),
 dict(name='http-error',statuses=('503',)),dict(name='invalid-body',payload='<html>'+('x'*1500)),
 dict(name='syntax-error',payload=fresh+'\nlocal ='),dict(name='cancel',cancel=True),
 dict(name='rename-failure',rename_failure=True),dict(name='already-current',installed=fresh)]:case(**kwargs)
# No registered Studio path must leave everything untouched and give an explicit message.
r=LuaRuntime();messages=[];r.globals().reaper=r.table_from({'GetExtState':lambda *_:'','ShowMessageBox':lambda text,*_:messages.append(text)})
r.execute(helper);assert messages and 'nicht gefunden' in messages[0]
print('PASS standalone updater: missing target reports failure without guessing a path')
