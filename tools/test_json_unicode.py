"""Use the production decoder together with its real lexical predecessor."""
from pathlib import Path
from lupa.lua54 import LuaRuntime

source = (Path(__file__).resolve().parents[1] / 'Composition Studio.lua').read_text()
helper = source[source.index('local function utf8(cp)'):source.index('local function read_json_string')]
decoder = source[source.index('local function decode_engine_json(src)'):source.index('local function engine_translate_json(answer)')]
api = LuaRuntime(unpack_returned_tuples=True).execute(
    helper + '\n' + decoder + '\nreturn function(s) return pcall(decode_engine_json,s) end')
for escaped, expected in [(r'\u00e4', 'ä'), (r'\uD834\uDD1E', '𝄞'), (r'\u0061', 'a'), ('ä', 'ä')]:
    ok, value = api('{"title":"' + escaped + '"}')
    assert ok and value.title == expected, (escaped, value)
for escaped in (r'\uD834', r'\uDD1E', r'\uZZZZ'):
    ok, error = api('{"title":"' + escaped + '"}')
    assert not ok and 'JSON Zeichen' in error, error
print('PASS JSON Unicode in production lexical scope: literals, escapes, surrogate pairs, malformed escapes')
