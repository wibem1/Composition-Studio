"""Execute the shipped Lua UI against real Dear ImGui, without a REAPER/audio host.
Requires: pip install lupa imgui-bundle
The binding mirrors ReaImGui's automatic End/EndChild on a false Begin.
"""
from pathlib import Path
import sys
from lupa.lua54 import LuaRuntime
from imgui_bundle import imgui

source=(Path(sys.argv[1]) if len(sys.argv)>1 else Path(__file__).resolve().parents[1]/'Composition Studio.lua').read_text(encoding='utf-8')
ui=source[source.index('local function wrap_text(s,limit)'):]

def case(width,height,font_size,state,mode,exercise_switch=False):
    context=imgui.create_context()
    io=imgui.get_io();io.display_size=(1600,1400);io.delta_time=1/60
    io.set_ini_filename("")
    io.backend_flags|=imgui.BackendFlags_.renderer_has_textures
    lua=LuaRuntime(unpack_returned_tuples=True)
    lua.globals().FONT_SIZE=font_size
    lua.globals().STATE=state
    lua.execute('''
    local dummy=function()end
    reaper={}
    ctx=0;VERSION="1.1.2";font_size=FONT_SIZE;open=true;restarting=false;input="";busy=false
    current_project=0;EXT_SECTION="test";WINDOW_STATE_KEY="WindowOpen";provider="openai";model="test"
    composition_mode="concept";reasoning_mode="auto";REASONING_LABELS={auto="Automatisch"}
    info_visible=false;history_mode=STATE=="history";chat_start=1
    history={{role="KI",text="Analyse und Komposition"}}
    update_job=STATE=="updating" and {} or nil
    update_status=string.rep("Ein langer Hinweis zur letzten Aktion. ",30)
    workflow_core={version="1",readable=function(s)return s end}
    local result={stage="composition",state="ready",created="2026-10-19 16:00",raw_response="Music"}
    workflow_adapter={models={poll=dummy,refresh=dummy},records={result},labels={composition="Überarbeitung"},states={ready="Vorschlag"},transition_bars=0,apply=dummy,review=dummy}
    if STATE=="history" then for i=2,100 do workflow_adapter.records[i]=result end end
    if STATE~="empty" then workflow_adapter.pending=result;workflow_adapter.analysis=result end
    MODELS={openai={},anthropic={},google={}}
    costs={order={},total={},amount=function()return "0,35 €" end}
    poll_update=dummy;poll_job=dummy;finish_save_panel=dummy
    focused_or_last_notation_editor=function()return nil end
    selected_items=function()return {} end;selected_tracks=function()return {} end
    model_label=function()return string.rep("Sehr langer Modellname mit UTF-8 äöü ",8) end
    push_font=function()reaper.ImGui_PushFont(ctx,nil,font_size);return true end
    pop_font=function()reaper.ImGui_PopFont(ctx)end
    ''')
    api=lua.globals().reaper
    rectangles={};scroll=[]
    settings={'InterfaceMode':mode}
    switch_requested=False
    window_ids=[]
    workspace_inputs=[]
    def record(name):
        a=imgui.get_item_rect_min();b=imgui.get_item_rect_max()
        rectangles[name]=(a.x,a.y,b.x,b.y)
    def begin(_,name,is_open,flags=0):
        imgui.set_next_window_pos((0,0))
        window_ids.append(name.split('###')[-1])
        shown,opened=imgui.begin(name,is_open,flags)
        if not shown:imgui.end()
        return shown,opened
    def end(_):
        scroll.append((imgui.get_scroll_max_x(),imgui.get_scroll_max_y()))
        imgui.end()
    def child(_,name,w,h,flags):
        shown=imgui.begin_child(name,(w,h),imgui.ChildFlags_.borders)
        if not shown:imgui.end_child()
        return shown
    def button(_,name,w=0,h=0):
        pressed=imgui.button(name,(w,h));record(name)
        return pressed or (switch_requested and name in ('Studioansicht','Kompaktansicht'))
    def multiline(_,name,text,w,h,flags):
        if name=='##request': workspace_inputs.append((window_ids[-1],text))
        changed,text=imgui.input_text_multiline(name,text,(w,h),flags)
        record(name)
        return changed,text
    funcs={
        'SetNextWindowSize':lambda *args:imgui.set_next_window_size((width,height)),
        'SetNextWindowSizeConstraints':lambda _,a,b,c,d:imgui.set_next_window_size_constraints((a,b),(c,d)),
        'GetMainViewport':lambda _:imgui.get_main_viewport(),
        'Viewport_GetWorkPos':lambda viewport:tuple(viewport.work_pos),
        'Viewport_GetWorkSize':lambda viewport:tuple(viewport.work_size),
        'SetNextWindowPos':lambda _,x,y:imgui.set_next_window_pos((x,y)),
        'GetWindowPos':lambda _:tuple(imgui.get_window_pos()),
        'GetWindowSize':lambda _:tuple(imgui.get_window_size()),
        'IsMouseDown':lambda _,button:imgui.is_mouse_down(button),
        'PushStyleColor':lambda _,index,color:imgui.push_style_color(index,imgui.ImVec4(
            (color>>24)/255, ((color>>16)&255)/255, ((color>>8)&255)/255, (color&255)/255)),
        'PopStyleColor':lambda _,count:imgui.pop_style_color(count),
        'WindowFlags_NoDocking':lambda:imgui.WindowFlags_.no_docking,
        'WindowFlags_NoMove':lambda:imgui.WindowFlags_.no_move,
        'WindowFlags_NoResize':lambda:imgui.WindowFlags_.no_resize,
        'Col_WindowBg':lambda:imgui.Col_.window_bg,
        'Col_Text':lambda:imgui.Col_.text,
        'Begin':begin,'End':end,'BeginChild':child,'EndChild':lambda _:imgui.end_child(),
        'GetContentRegionAvail':lambda _:tuple(imgui.get_content_region_avail()),
        'GetStyleVar':lambda *_:tuple(imgui.get_style().item_spacing),
        'GetFrameHeight':lambda _:imgui.get_frame_height(),
        'CalcTextSize':lambda _,text:tuple(imgui.calc_text_size(text)),
        'PushFont':lambda _,font,size:imgui.push_font(None,size),'PopFont':lambda _:imgui.pop_font(),
        'Text':lambda _,text:imgui.text_unformatted(text),'TextWrapped':lambda _,text:imgui.text_wrapped(text),
        'Button':button,'InputTextMultiline':multiline,
        'SameLine':lambda _,offset=0,spacing=-1:imgui.same_line(offset,spacing),
        'Separator':lambda _:imgui.separator(),'Spacing':lambda _:imgui.spacing(),
        'BeginPopup':lambda *_:False,'BeginPopupContextItem':lambda *_:False,
        'Cond_FirstUseEver':lambda:imgui.Cond_.first_use_ever,
        'StyleVar_ItemSpacing':lambda:imgui.StyleVar_.item_spacing,
        'ChildFlags_Borders':lambda:1,
        'InputTextFlags_ReadOnly':lambda:imgui.InputTextFlags_.read_only,
        'InputTextFlags_NoHorizontalScroll':lambda:imgui.InputTextFlags_.no_horizontal_scroll,
    }
    for name,fn in funcs.items():api['ImGui_'+name]=fn
    api.EnumProjects=lambda *_:0
    api.defer=lambda *_:None
    api.GetExtState=lambda _,key:settings.get(key,'')
    api.SetExtState=lambda _,key,value,persist:settings.__setitem__(key,value)
    if exercise_switch: lua.globals().input='Ungesendeter gemeinsamer Auftrag'
    for frame in range(5 if exercise_switch else 3):
        switch_requested=exercise_switch and frame in (1,3)
        imgui.new_frame()
        if frame==0:lua.execute(ui+'\nTEST_LOOP=loop')
        else:lua.globals().TEST_LOOP()
        imgui.render()
    if exercise_switch:
        assert window_ids == ['CompositionStudioMain']*2 + ['CompositionStudioWorkspace']*2 + ['CompositionStudioMain']
        assert workspace_inputs == [(window,'Ungesendeter gemeinsamer Auftrag') for window in window_ids]
        assert lua.globals().workflow_adapter.pending.raw_response=='Music'
        assert len(lua.globals().history)==1 and lua.globals().model=='test'
        assert settings['InterfaceMode']=='compact' and settings['StudioWindowBoundsV1']=='0 0 800 900'
    controls=('##request','Senden','Verlauf','Chat leeren','Schließen') + (('Änderungen anwenden',) if state!='empty' else ())
    for name in controls:
        x,y,right,bottom=rectangles[name]
        assert x>=0 and y>=0 and right<=width-7 and bottom<=height-7,(width,height,font_size,state,name,rectangles[name])
    assert scroll[-1]==(0,0),(width,height,font_size,state,'outer window scrolls',scroll[-1])
    imgui.destroy_context(context)

for size in [(360,480),(360,620),(480,620),(800,900)]:
    for font in (10,14,20,26):
        for state in ('empty','proposal','history','updating'):case(*size,font,state,'compact')
for size in [(460,480),(640,620),(960,760)]:
    for font in (10,14,20,26):
        for state in ('empty','proposal','history','updating'):case(*size,font,state,'studio')
case(800,900,14,'proposal','compact',exercise_switch=True)
print('PASS 112 real Dear ImGui layouts plus both mode switches; chat footer and Apply visible')

# Exercise persisted bounds and maximize/restore using the production window code
# with an offset REAPER work area and a fresh Lua session over the same settings.
window_code=ui[ui.index('local studio_window ='):ui.index('local function clipboard_set')]
settings={'InterfaceMode':'studio','StudioWindowBoundsV1':'-120 90 820 640'}
calls={}
writes=[]
dragging=False
def read_setting(_,key):
    return settings.get(key,'')
def write_setting(_,key,value,persist):
    assert persist
    settings[key]=value
    writes.append((key,value))
def load_window():
    runtime=LuaRuntime(unpack_returned_tuples=True)
    runtime.globals().ctx=1
    runtime.globals().EXT_SECTION='test'
    runtime.globals().VERSION='test'
    runtime.globals().open=True
    functions={
        'GetExtState':read_setting,'SetExtState':write_setting,
        'ImGui_GetMainViewport':lambda _:1,
        'ImGui_Viewport_GetWorkPos':lambda _: (20,30),
        'ImGui_Viewport_GetWorkSize':lambda _: (1200,800),
        'ImGui_SetNextWindowPos':lambda _,x,y:calls.update(pos=(x,y)),
        'ImGui_SetNextWindowSize':lambda _,w,h,*args:calls.update(size=(w,h)),
        'ImGui_SetNextWindowSizeConstraints':lambda *_:None,
        'ImGui_Cond_FirstUseEver':lambda:4,
        'ImGui_WindowFlags_NoDocking':lambda:1,
        'ImGui_WindowFlags_NoMove':lambda:2,
        'ImGui_WindowFlags_NoResize':lambda:4,
        'ImGui_GetWindowPos':lambda _: (-240,100),
        'ImGui_GetWindowSize':lambda _: (840,660),
        'ImGui_IsMouseDown':lambda *_:dragging,
    }
    runtime.globals().reaper=runtime.table_from(functions)
    return runtime.execute(window_code+'\nreturn studio_window')

window=load_window()
assert window.mode=='studio'
assert window.prepare()[1]==1 and calls=={'pos':(-120,90),'size':(820,640)}
dragging=True
window.remember_bounds()
assert not writes
dragging=False
window.remember_bounds()
window.remember_bounds()
assert writes==[('StudioWindowBoundsV1','-240 100 840 660')]
window.toggle_maximize()
assert window.prepare()[1]==7 and calls=={'pos':(20,30),'size':(1200,800)}
window.remember_bounds()
assert len(writes)==1
window.toggle_maximize()
assert window.prepare()[1]==1 and calls=={'pos':(-240,100),'size':(840,660)}
window=load_window()
assert window.mode=='studio' and not window.maximized
assert window.prepare()[1]==1 and calls=={'pos':(-240,100),'size':(840,660)}
settings['StudioWindowBoundsV1']='invalid'
calls.clear()
assert load_window().prepare()[1]==1 and calls=={'size':(960,760)}
print('PASS saved view and geometry, drag persistence, maximize and restore, invalid settings fallback')
