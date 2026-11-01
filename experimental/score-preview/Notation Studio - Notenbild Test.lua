-- @description Notation Studio - Notenbild Test (READ ONLY)
-- @version 0.2.2-test
-- @author Composition Studio
-- @about Preview only: selected REAPER MIDI items, no edits and no API costs.
-- This isolated test does not replace the released Notation Studio.
local r=reaper
if type(r.ImGui_CreateContext)~='function' then
  r.ShowMessageBox('Bitte ReaImGui installieren bzw. aktivieren.','Notenbild-Test',0)
  return
end
local source=(debug.getinfo(1,'S').source or ''):gsub('^@','')
local dir=source:match('^(.*[/\\])') or ''
local ok,core=pcall(dofile,dir..'score_preview_core.lua')
if not ok then
  r.ShowMessageBox('score_preview_core.lua muss im selben Ordner liegen.\n'..tostring(core),'Notenbild-Test',0)
  return
end
local function color(hex) return hex end
local BLACK=color(0x20242CFF)
local INK=color(0x14283EFF)
local SLATE=color(0x8093A7FF)
local WHITE=color(0xFFFFFFFF)
local CYAN=color(0x1173B7FF)
local SOFT=color(0xD5EAF8FF)
local function collect()
  local items={}
  local function add_take(take,item)
    if not take or not r.TakeIsMIDI(take) then return end
    local _,name=r.GetSetMediaItemTakeInfo_String(take,'P_NAME','',false)
    local track=item and r.GetMediaItem_Track(item)
    if track and r.GetTrackName then local _,nm=r.GetTrackName(track); if nm and nm~='' then name=nm end end
    local count=select(2,r.MIDI_CountEvts(take)) or 0
    local notes={}
    for j=0,count-1 do
      local yes,_,muted,sp,ep,chan,pitch=r.MIDI_GetNote(take,j)
      if yes and not muted then
        notes[#notes+1]={pitch=pitch,channel=chan,
          start_qn=r.MIDI_GetProjQNFromPPQPos(take,sp),
          end_qn=r.MIDI_GetProjQNFromPPQPos(take,ep)}
      end
    end
    local start=0
    if item then
      start=r.TimeMap2_timeToQN(0,r.GetMediaItemInfo_Value(item,'D_POSITION'))
    end
    items[#items+1]={name=name or ('MIDI '..(#items+1)),start_qn=start,notes=notes,
      clef=(#items==0) and 'treble' or 'bass'}
  end
  local n=r.CountSelectedMediaItems(0)
  if n>0 then
    for i=0,n-1 do
      local item=r.GetSelectedMediaItem(0,i)
      add_take(r.GetActiveTake(item),item)
    end
  else
    local editor=r.MIDIEditor_GetActive()
    local take=editor and r.MIDIEditor_GetTake(editor)
    if take then add_take(take,r.GetMediaItemTake_Item(take)) end
  end
  return items
end
local ctx=r.ImGui_CreateContext('Notation Studio - Notenbild Test')
local open=true
local grid=0.25
local numerator,denominator=4,4
local first_bar=0
local page_bars=2
local zoom=1
local status=''
local model=nil
local function refresh()
  local items=collect()
  if #items==0 then model=nil;status='Keine MIDI-Items ausgewählt. Im Arrangement bis zu drei MIDI-Items markieren.';return end
  model=core.build(items,{num=numerator,den=denominator,grid=grid})
  first_bar=math.min(first_bar,math.max(0,model.bars-1))
  status=string.format('%d MIDI-Items · %d Noten · %d Takte · Leseansicht',#model.tracks,model.original_events,model.bars)
end
local function line(dl,x1,y1,x2,y2,col,thickness)
  r.ImGui_DrawList_AddLine(dl,x1,y1,x2,y2,col,thickness or 1)
end
local function text(dl,x,y,str,col)
  r.ImGui_DrawList_AddText(dl,x,y,col or INK,tostring(str))
end
local function notehead(dl,x,y,filled)
  if type(r.ImGui_DrawList_AddEllipseFilled)=='function' then
    r.ImGui_DrawList_AddEllipseFilled(dl,x,y,7.2,4.8,INK,-0.25,20)
    if not filled then r.ImGui_DrawList_AddEllipseFilled(dl,x,y,4.9,2.7,WHITE,-0.25,20) end
  else
    r.ImGui_DrawList_AddCircleFilled(dl,x,y,5.4,INK,16)
    if not filled then r.ImGui_DrawList_AddCircleFilled(dl,x,y,2.6,WHITE,16) end
  end
end
local function draw_staff(dl,x,y,width,track,model,bar_start,bars,scale)
  local step=5.5*scale
  local linegap=step*2
  local clef=track.clef
  local reference=(clef=='treble') and 30 or 18  -- E4 or G2 bottom line
  local bottom=y+linegap*4
  local score_left=x+80*scale
  local total_width=width-(92*scale)
  local bar_width=total_width/bars
  text(dl,x+9*scale,y+5*scale,track.name,INK)
  text(dl,score_left-30*scale,y+20*scale,clef=='treble' and 'G' or 'F',CYAN)
  for k=0,4 do
    local sy=y+linegap*k
    line(dl,score_left,sy,score_left+total_width,sy,BLACK,1.1)
  end
  local max_x=score_left+total_width
  for b=0,bars do
    local xpos=score_left+b*bar_width
    line(dl,xpos,y,xpos,bottom,SLATE,1.0)
    if b<bars then text(dl,xpos+8,y-20,bar_start+b+1,SLATE) end
  end
  for b=0,bars-1 do
    local index=bar_start+b
    local bs=index*model.bar
    local onset=core.bar_notes(track,index,model.bar)
    if #onset==0 then
      text(dl,score_left+b*bar_width+bar_width/2-7,y+linegap*1.4,'R',SLATE)
    end
    for _,n in ipairs(onset) do
      local t=(n.start-bs)/model.bar
      local nx=score_left+b*bar_width+math.max(14,math.min(bar_width-12,t*bar_width))
      local pstep,acc=core.spell(n.pitch)
      local ny=bottom-(pstep-reference)*step
      if ny<y-57*scale then ny=y-57*scale elseif ny>bottom+65*scale then ny=bottom+65*scale end
      -- Ledger lines outside the stave.
      local steps_out=pstep-reference
      if steps_out<0 then
        for st=-2,steps_out,-2 do
          line(dl,nx-12*scale,bottom-st*step,nx+12*scale,bottom-st*step,BLACK,1.1)
        end
      elseif steps_out>8 then
        for st=10,steps_out,2 do
          line(dl,nx-12*scale,bottom-st*step,nx+12*scale,bottom-st*step,BLACK,1.1)
        end
      end
      -- Pitch spelling only (no full accidental memory in this prototype).
      if acc~='' then text(dl,nx-24*scale,ny-11*scale,acc,CYAN) end
      local d=n.duration
      local filled=d<2
      notehead(dl,nx,ny,filled)
      if d<4 then
        local up=(pstep-reference)<4
        local stemx=nx+(up and 7 or -7)*scale
        local tip=ny+(up and -31 or 31)*scale
        line(dl,stemx,ny,stemx,tip,INK,1.55)
        if d<=0.5 then
          line(dl,stemx,tip,stemx+(up and 9 or -9)*scale,tip+((up and 11 or -11)*scale),INK,1.9)
        end
      end
      if d==0.375 or d==0.75 or d==1.5 or d==3 then
        r.ImGui_DrawList_AddCircleFilled(dl,nx+13*scale,ny,1.8*scale,INK,8)
      end
      -- Subtle grey line indicates actual held duration, not a formal tie.
      local ex=math.min(max_x,nx+((n.original_duration/model.bar)*bar_width))
      if ex>nx+14 then line(dl,nx+10*scale,ny+8*scale,ex,ny+8*scale,SOFT,2) end
    end
  end
end
refresh()
local function loop()
  if not open then return end
  local visible
  visible,open=r.ImGui_Begin(ctx,'Notation Studio · Notenbild 0.2.2 TEST###score_preview',open)
  if visible then
    r.ImGui_Text(ctx,'NOTENBILD-VORSCHAU · Nur Anzeige, keine MIDI-Aenderungen')
    if r.ImGui_Button(ctx,'MIDI-Auswahl neu einlesen') then refresh() end
    r.ImGui_SameLine(ctx)
    if r.ImGui_Button(ctx,'Vorherige Takte') then first_bar=math.max(0,first_bar-page_bars) end
    r.ImGui_SameLine(ctx)
    if r.ImGui_Button(ctx,'Naechste Takte') and model then first_bar=math.min(math.max(0,model.bars-1),first_bar+page_bars) end
    r.ImGui_SameLine(ctx)
    if r.ImGui_Button(ctx,'Zoom +') then zoom=math.min(1.7,zoom+0.15) end
    r.ImGui_SameLine(ctx)
    if r.ImGui_Button(ctx,'Zoom -') then zoom=math.max(0.8,zoom-0.15) end
    if r.ImGui_Button(ctx,'4/4') then numerator,denominator=4,4;refresh() end
    r.ImGui_SameLine(ctx)
    if r.ImGui_Button(ctx,'3/4') then numerator,denominator=3,4;refresh() end
    r.ImGui_SameLine(ctx)
    if r.ImGui_Button(ctx,'Raster 1/16') then grid=0.25;refresh() end
    r.ImGui_SameLine(ctx)
    if r.ImGui_Button(ctx,'Raster 1/32') then grid=0.125;refresh() end
    r.ImGui_Text(ctx,'Anzeige: '..numerator..'/'..denominator..' · Raster '..(grid==0.25 and '1/16' or '1/32')..' · '..status)
    r.ImGui_Text(ctx,'Hinweis: Noten/Notenlaengen sind grafisch vereinfacht. Keine korrekte Stimmen-, Balken-, Pausen- oder Bindebogen-Engraving.')
    if model then
      local w=math.max(880,970*zoom)
      local height=(#model.tracks*145+70)*zoom
      -- Use the main window's draw list as the canvas. Avoid BeginChild/
      -- EndChild entirely: the ReaImGui child stack failed in the real
      -- REAPER Windows test. ImGui_Dummy reserves space and the main
      -- window provides scrollbars for taller scores.
      local sx,sy=r.ImGui_GetCursorScreenPos(ctx)
      local dl=r.ImGui_GetWindowDrawList(ctx)
      r.ImGui_DrawList_AddRectFilled(dl,sx,sy,sx+w,sy+height,WHITE,3)
      text(dl,sx+24,sy+14,'Notation Studio  |  Entwurf  |  '..numerator..'/'..denominator,INK)
      local actual=math.min(page_bars,math.max(1,model.bars-first_bar))
      for i,track in ipairs(model.tracks) do
        draw_staff(dl,sx+20,sy+72*zoom+(i-1)*145*zoom,w-40,track,model,first_bar,actual,zoom)
      end
      r.ImGui_Dummy(ctx,w,height)
    else
      r.ImGui_Text(ctx,status)
    end
  end
  r.ImGui_End(ctx)
  if open then r.defer(loop) end
end
r.defer(loop)
