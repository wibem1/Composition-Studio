"""Execute the shipped Lua UI against real Dear ImGui, without a REAPER/audio host.
Requires: pip install lupa imgui-bundle
The binding mirrors ReaImGui's automatic End/EndChild on a false Begin.
"""
from pathlib import Path
import sys
from lupa.lua54 import LuaRuntime
from imgui_bundle import imgui

source=(Path(sys.argv[1]) if len(sys.argv)>1 else Path(__file__).resolve().parents[1]/'Composition Studio.lua').read_text()
ui=source[source.index('local function wrap_text(s,limit)'):]

def case(width,height,font_size,state):
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
    update_status=string.rep("Ein langer Hinweis zur letzten Aktion. ",30)
    workflow_core={version="1",readable=function(s)return s end}
    local result={stage="composition",state="ready",created="2026-10-19 16:00",raw_response="Music"}
    workflow_adapter={models={poll=dummy,refresh=dummy},records={result},labels={composition="Überarbeitung"},states={ready="Vorschlag"},transition_bars=0,apply=dummy,review=dummy}
    if STATE=="history" then for i=2,100 do workflow_adapter.records[i]=result end end
    if STATE~="empty" then workflow_adapter.pending=result;workflow_adapter.analysis=result end
    MODELS={openai={},anthropic={},google={}}
    costs={order={},total={},amount=function()return "0,35 €" end}
    poll_update=dummy;poll_job=dummy;finish_save_panel=dummy
    selected_items=function()return {} end;selected_tracks=function()return {} end
    model_label=function()return string.rep("Sehr langer Modellname mit UTF-8 äöü ",8) end
    push_font=function()reaper.ImGui_PushFont(ctx,nil,font_size);return true end
    pop_font=function()reaper.ImGui_PopFont(ctx)end
    ''')
    api=lua.globals().reaper
    rectangles={};scroll=[]
    def record(name):
        a=imgui.get_item_rect_min();b=imgui.get_item_rect_max()
        rectangles[name]=(a.x,a.y,b.x,b.y)
    def begin(_,name,is_open):
        imgui.set_next_window_pos((0,0))
        shown,opened=imgui.begin(name,is_open)
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
        return pressed
    def multiline(_,name,text,w,h,flags):
        changed,text=imgui.input_text_multiline(name,text,(w,h),flags)
        record(name)
        return changed,text
    funcs={
        'SetNextWindowSize':lambda *args:imgui.set_next_window_size((width,height)),
        'SetNextWindowSizeConstraints':lambda _,a,b,c,d:imgui.set_next_window_size_constraints((a,b),(c,d)),
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
    api.SetExtState=lambda *_:None
    for frame in range(3):
        imgui.new_frame()
        if frame==0:lua.execute(ui+'\nTEST_LOOP=loop')
        else:lua.globals().TEST_LOOP()
        imgui.render()
    for name in ('##request','Senden','Verlauf','Chat leeren','Schließen'):
        x,y,right,bottom=rectangles[name]
        assert x>=0 and y>=0 and right<=width-7 and bottom<=height-7,(width,height,font_size,state,name,rectangles[name])
    assert scroll[-1]==(0,0),(width,height,font_size,state,'outer window scrolls',scroll[-1])
    imgui.destroy_context(context)

for size in [(360,480),(360,620),(480,620),(800,900)]:
    for font in (10,14,20,26):
        for state in ('empty','proposal','history'):case(*size,font,state)
print('PASS 48 real Dear ImGui layouts: fonts 10–26, small/large windows, long UTF-8 models/status, proposal and history; footer visible without outer scrolling')
