"""Exercise the production picker with real Dear ImGui and Lua 5.4.
No REAPER instance, network, API keys or user settings are used.
Requires lupa and imgui-bundle (same as test_layout.py).
"""
from pathlib import Path
from lupa.lua54 import LuaRuntime
from imgui_bundle import imgui

source = (Path(__file__).resolve().parents[1] / 'Composition Studio.lua').read_text(encoding='utf-8')
picker = source[source.index('local function fit_label('):source.index('local function draw_workflow_status(')]
selection = source[source.index('local function select_model('):source.index('\n', source.index('local function select_model('))]


def case(width, font):
    context = imgui.create_context()
    io = imgui.get_io()
    io.display_size = (1096, 656)
    io.delta_time = 1 / 60
    io.set_ini_filename('')
    io.backend_flags |= imgui.BackendFlags_.renderer_has_textures
    lua = LuaRuntime(unpack_returned_tuples=True)
    saved = {'APIKey': 'sentinel', 'history': 'sentinel', 'AIProvider': 'openai', 'AIModel': 'gpt-5.6-sol'}
    writes, refreshes, rects = [], [], {}
    lua.execute('''
        ctx=0; busy=false; provider='openai'; model='gpt-5.6-sol'
        EXT_SECTION='test'; PROVIDER_KEY='AIProvider'; MODEL_KEY='AIModel'
        reaper={}; workflow_adapter={models={filter='',message='86 verfügbare Modelle eingelesen.'}}
        MODELS={openai={},anthropic={{'Duplicate','claude-test'}},google={{'Duplicate','gemini-test'}}}
        for i=1,86 do MODELS.openai[i]={'Modell '..i..string.rep(' lang',20),'gpt-test-'..i} end
        workflow_adapter.models.featured={openai={MODELS.openai[1],MODELS.openai[2],MODELS.openai[3]},anthropic=MODELS.anthropic,google=MODELS.google}
        model_label=function() return model end
    ''')
    api = lua.globals().reaper

    def record(label):
        a, b = imgui.get_item_rect_min(), imgui.get_item_rect_max()
        rects[label] = (a.x, a.y, b.x, b.y)

    def button(_, label, w):
        result = imgui.button(label, (w, 0))
        record(label.split('###')[-1] if '###provider_' in label else 'all' if label in ('Alle verfügbaren Modelle','Nur Hauptmodelle') else 'button')
        return result

    def begin_popup(_, label):
        shown = imgui.begin_popup(label)
        if shown:
            pos, size = imgui.get_window_pos(), imgui.get_window_size()
            rects['popup'] = (pos.x, pos.y, pos.x + size.x, pos.y + size.y)
        return shown

    def menu(_, label, shortcut, selected, enabled):
        result = imgui.menu_item(label, shortcut or '', selected, enabled)[0]
        record(label.split('###')[-1])
        return result

    def child(_, label, w, h, flags):
        shown = imgui.begin_child(label, (w, h), imgui.ChildFlags_.borders)
        if not shown:
            imgui.end_child()
        return shown

    def write(_, key, value, persistent):
        assert persistent
        writes.append(key)
        saved[key] = value

    funcs = {
        'Button': button, 'OpenPopup': lambda _, label: imgui.open_popup(label),
        'BeginPopup': begin_popup, 'EndPopup': lambda _: imgui.end_popup(),
        'SetNextWindowSizeConstraints': lambda _, a,b,c,d: imgui.set_next_window_size_constraints((a,b),(c,d)),
        'TextWrapped': lambda _, text: imgui.text_wrapped(text),
        'Text': lambda _, text: imgui.text_unformatted(text),
        'MenuItem': menu, 'InputText': lambda _, label, value: imgui.input_text(label, value),
        'BeginChild': child, 'EndChild': lambda _: imgui.end_child(),
        'ChildFlags_Borders': lambda: 1,
        'GetFrameHeight': lambda _: imgui.get_frame_height(),
        'GetContentRegionAvail': lambda _: tuple(imgui.get_content_region_avail()),
        'CalcTextSize': lambda _, text: tuple(imgui.calc_text_size(text)),
    }
    for name, fn in funcs.items():
        api['ImGui_' + name] = fn
    api.SetExtState = write
    lua.globals().workflow_adapter.models.refresh = lambda *args: refreshes.append(args)
    lua.execute(selection + '\n' + picker + '\nDRAW=draw_model_picker')

    def frame():
        rects.clear()
        imgui.new_frame()
        imgui.set_next_window_pos((1096-width, 40))
        imgui.set_next_window_size((width, 600))
        imgui.begin('Dock fixture')
        imgui.push_font(None, font)
        lua.globals().DRAW(width-16)
        imgui.pop_font()
        imgui.end()
        imgui.render()

    def click(rect):
        x1, y1, x2, y2 = rect
        io.add_mouse_pos_event((x1+x2)/2, (y1+y2)/2)
        frame()
        io.add_mouse_button_event(0, True)
        frame()
        io.add_mouse_button_event(0, False)
        frame()
        frame()

    for _ in range(3): frame()
    click(rects['button'])
    assert 'popup' in rects
    assert refreshes == [] and writes == [], 'Opening must not fetch or change settings'
    assert 'model_openai/gpt-test-3' in rects and 'model_openai/gpt-test-86' not in rects, 'Default list must stay short'
    a,b,c,d = rects['popup']
    assert 0 <= a < c <= 1096 and 0 <= b < d <= 656, rects['popup']
    assert d-b < 600 and c-a <= 480, rects['popup']
    # Filter an item from the bottom of a large catalog into view.
    click(rects['all'])
    lua.globals().workflow_adapter.models.filter = 'gpt-test-86'
    frame(); frame()
    click(rects['model_openai/gpt-test-86'])
    assert saved['AIModel'] == 'gpt-test-86' and saved['AIProvider'] == 'openai'
    assert writes == ['AIProvider', 'AIModel']
    # Identical display names across providers must select their own IDs.
    for pv, target in [('anthropic', 'claude-test'), ('google', 'gemini-test')]:
        click(rects['button'])
        if pv == 'anthropic':
            assert 'model_openai/gpt-test-86' in rects
            assert saved['AIModel'] == 'gpt-test-86', 'Saved non-featured model must remain available'
        frame(); frame()
        a,b,c,d = rects['popup']
        for p in ('openai', 'anthropic', 'google'):
            x1,y1,x2,y2 = rects['provider_'+p]
            assert a <= x1 < x2 <= c and b <= y1 < y2 <= d, (p, rects)
        before = dict(saved)
        click(rects['provider_'+pv])
        assert saved == before, 'Browsing a provider must not change the saved selection'
        lua.globals().workflow_adapter.models.filter = 'Duplicate'
        frame(); frame()
        click(rects[f'model_{pv}/{target}'])
        assert saved['AIProvider'] == pv and saved['AIModel'] == target
    # Busy jobs do not allow another selection; missing current model isn't reset.
    lua.globals().busy = True
    previous = dict(saved)
    click(rects['button'])
    assert saved == previous and refreshes == []
    assert saved['APIKey'] == 'sentinel' and saved['history'] == 'sentinel'
    imgui.destroy_context(context)


for width in (280, 360, 480):
    for font in (14, 26):
        case(width, font)
print('PASS 6 real Dear ImGui picker interactions: 86 models, bounded dock popup, search, all providers, duplicate labels, persistence, busy guard, no automatic network')

# Actual refresh function: browsing another provider must fetch its catalog
# without changing the active model, keys, history or curated defaults.
r = LuaRuntime(unpack_returned_tuples=True)
refresh = source[source.index('function workflow_adapter.models.refresh('):source.index('function workflow_adapter.models.poll(')]
r.execute('''
provider='openai'; busy=false
MODELS={openai={},anthropic={},google={}}
KEY_NAMES={openai='key-openai',anthropic='key-anthropic',google='key-google'}
EXT_SECTION='test'; workflow_adapter={models={}}
keys={['key-openai']='OPENAI-FIXTURE',['key-anthropic']='ANTHROPIC-FIXTURE',['key-google']='GOOGLE-FIXTURE'}
reaper={GetExtState=function(_,k)return keys[k] or '' end}
function trim(s)return s end
function workflow_adapter.models.report(text,notify) last_message=text end
function workflow_adapter.models.page(j) last_job=j end
'''+refresh)
for pv in ('anthropic', 'google', 'openai'):
    r.globals().workflow_adapter.models.refresh(False, pv)
    assert r.globals().last_job.provider == pv
    assert r.globals().last_job.key == pv.upper()+'-FIXTURE'
    assert r.globals().provider == 'openai'
r.execute("keys['key-google']=''; last_job=nil")
r.globals().workflow_adapter.models.refresh(False, 'google')
assert r.globals().last_job is None and 'Google' in r.globals().last_message
assert r.globals().provider == 'openai'
print('PASS explicit catalog refresh targets the browsed provider; missing key preserves selection')

# Argon-specific regression: use the actual shipped Lua model registry and
# reasoning serialization, rather than the generic UI fixture's mock models.
from datetime import date
import re
registry = re.search(r'local MODELS=(\{[^\n]+\})\nlocal provider=', source)
assert registry, 'Production model registry not found'
arg = LuaRuntime(unpack_returned_tuples=True)
arg.execute('MODELS=' + registry.group(1))
assert arg.globals().MODELS.google[1][1] == 'Gemini 4 Argon'
assert arg.globals().MODELS.google[1][2] == 'gemini-4-argon'
assert arg.globals().MODELS.google[2][2] == 'gemini-3.8-flash'
reasoning = source[source.index('local function reasoning_parameters('):source.index('-- End thinking control.')]
arg.execute("REASONING_LABELS={low=true,medium=true,high=true,auto=true}\n" +
            reasoning + "\nCHECK_REASONING=reasoning_parameters")
for effort in ('low', 'medium', 'high'):
    body, requested = arg.globals().CHECK_REASONING('google', 'gemini-4-argon', effort)
    assert '"thinkingLevel":"' + effort + '"' in body, (effort, body)
    assert body == ',' + requested
assert arg.globals().CHECK_REASONING('google', 'gemini-4-argon', 'auto')[1] == 'provider_default'
rates = source[source.index(' local rates={'):source.index('  local function rate_values(')]
arg.execute(rates + '\nCHECK_RATE=rates["google/gemini-4-argon"]')
r = arg.globals().CHECK_RATE
assert (r[1],r[2],r[3],r.expires)==(2,10,0.1,'2026-11-30')
assert 'id=="gemini-4-argon" then return {4,20,0.2,0,0}' in source
assert 'local VERSION="1.1.10"' in source and '-- @version 1.1.10' in source
print('PASS real Google Argon model registry, model ID, reasoning levels and API cost estimates')
