"""Run a Lua test with the system Lua 5.4 shared library, without pip dependencies."""
import ctypes
import ctypes.util
import sys

library = ctypes.util.find_library('lua5.4')
if not library:
    raise SystemExit('Lua 5.4 shared library missing; install Lua 5.4 or use lua5.4 test.lua')
lua = ctypes.CDLL(library)
lua.luaL_newstate.restype = ctypes.c_void_p
lua.luaL_openlibs.argtypes = [ctypes.c_void_p]
lua.luaL_loadfilex.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_char_p]
lua.lua_pcallk.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_longlong, ctypes.c_void_p]
lua.lua_tolstring.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_void_p]
lua.lua_tolstring.restype = ctypes.c_char_p
lua.lua_close.argtypes = [ctypes.c_void_p]
state = lua.luaL_newstate()
if not state:
    raise SystemExit('Cannot allocate Lua state')
try:
    lua.luaL_openlibs(state)
    code = lua.luaL_loadfilex(state, sys.argv[1].encode(), None)
    if not code:
        code = lua.lua_pcallk(state, 0, -1, 0, 0, None)
    if code:
        print(lua.lua_tolstring(state, -1, None).decode(errors='replace'), file=sys.stderr)
finally:
    lua.lua_close(state)
sys.exit(bool(code))
