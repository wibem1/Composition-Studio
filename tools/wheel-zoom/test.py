import ctypes
from pathlib import Path
lib=ctypes.CDLL('liblua5.4.so.0')
lib.luaL_newstate.restype=ctypes.c_void_p
lib.luaL_openlibs.argtypes=[ctypes.c_void_p]
lib.luaL_loadstring.argtypes=[ctypes.c_void_p,ctypes.c_char_p]
lib.lua_pcallk.argtypes=[ctypes.c_void_p,ctypes.c_int,ctypes.c_int,ctypes.c_int,ctypes.c_longlong,ctypes.c_void_p]
lib.lua_tolstring.argtypes=[ctypes.c_void_p,ctypes.c_int,ctypes.c_void_p];lib.lua_tolstring.restype=ctypes.c_char_p
lib.lua_close.argtypes=[ctypes.c_void_p]
root=Path(__file__).parent
mock='''
clock=0; zoom=100; height=100; targetproject="project"; active="project"; locked=0
fresh=true; mode=0; wheel=120; ctx="wheel:"; section=0; callback=nil; writes=0; messages=0; cache={}
reaper={
set_action_options=function(f) assert(f==3) end,
get_action_context=function() return fresh,"script",section,1,mode,127,wheel,ctx end,
EnumProjects=function() return active end,
GetMousePosition=function() return 10,10 end,
GetTrackFromPoint=function() return "track" end,
ValidatePtr2=function(p,t,k) return active==targetproject end,
GetTrackGUID=function() return "guid" end,
GetMediaTrackInfo_Value=function(t,k) if k=="B_HEIGHTLOCK" then return locked end return height end,
GetHZoomLevel=function() return zoom end,
time_precise=function() return clock end,
GetExtState=function(n,k) return cache[k] or "" end,
SetExtState=function(n,k,v,persist) assert(not persist); cache[k]=v end,
DeleteExtState=function(n,k,persist) cache[k]=nil end,
SetMediaTrackInfo_Value=function(t,k,v) assert(k=="I_HEIGHTOVERRIDE"); height=v; writes=writes+1 end,
TrackList_AdjustWindows=function() end, UpdateArrange=function() end,
adjustZoom=function(v,force,update,center) assert(force==1 and update and center==-1); zoom=v; writes=writes+1 end,
defer=function(f) callback=f end,
MB=function() messages=messages+1 end
}
function finish() for i=1,30 do if not callback then break end local f=callback; callback=nil; clock=clock+0.02; f() end assert(callback==nil) end
'''
count=0
for axis in ('Horizontal','Vertikal'):
    source=(root/f'REAPER_Mausrad_{axis}_Zoom.lua').read_text()
    variable='zoom' if axis=='Horizontal' else 'height'
    checks=[
        ('up',source+f'\nfinish(); assert(math.abs({variable}-116)<0.01); assert(cache["last_input"]~=nil)'),
        ('bare-wheel','ctx="wheel"\n'+source+f'\nfinish(); assert(math.abs({variable}-116)<0.01)'),
        ('missing-context','ctx=nil\n'+source+f'\nfinish(); assert(math.abs({variable}-116)<0.01)'),
        ('empty-context','ctx=""\n'+source+f'\nfinish(); assert(math.abs({variable}-116)<0.01)'),
        ('unit-delta','wheel=1\n'+source+f'\nfinish(); assert(math.abs({variable}-116)<0.01)'),
        ('unit-negative','wheel=-1\n'+source+f'\nfinish(); assert(math.abs({variable}-100/1.16)<0.6)'),
        ('manual-run','fresh=false; ctx=""; mode=-1; wheel=-1\n'+source+'\nfinish(); assert(writes==0 and messages==0)'),
        ('down','wheel=-120\n'+source+f'\nfinish(); assert(math.abs({variable}-100/1.16)<0.6)'),
        ('no-wheel','ctx="key:V:65"\n'+source+'\nfinish(); assert(writes==0 and messages==0)'),
        ('wrong-section','section=32060\n'+source+'\nfinish(); assert(writes==0)'),
        ('switch-project',source+'\nactive="other"; finish(); assert(writes==0)'),
        ('restart',source+'\nclock=0.04; local f=callback; callback=nil; f()\n'+source+f'\nfinish(); assert(math.abs({variable}-134.56)<0.6)'),
        ('reverse-cancel',source+'\nwheel=-120\n'+source+f'\nfinish(); assert(math.abs({variable}-100)<0.01)'),
    ]
    if axis=='Vertikal': checks.append(('locked','locked=1\n'+source+'\nfinish(); assert(writes==0)'))
    for name,script in checks:
        state=lib.luaL_newstate();lib.luaL_openlibs(state)
        code=(mock+'\n'+ '\n'.join('do\n'+part+'\nend' for part in [script]) ).encode()
        # Each script is scoped separately so repeated local declarations and return remain legal.
        # Restart scenarios require separate do blocks around each actual source invocation.
        wrapped=script.replace(source,'do\n'+source+'\nend')
        code=(mock+'\n'+wrapped).encode()
        error=lib.luaL_loadstring(state,code) or lib.lua_pcallk(state,0,0,0,0,None)
        if error: raise RuntimeError(f'{axis}/{name}: '+lib.lua_tolstring(state,-1,None).decode())
        lib.lua_close(state);count+=1
print(f'{count} Lua 5.4 mock checks passed; no real REAPER test.')
