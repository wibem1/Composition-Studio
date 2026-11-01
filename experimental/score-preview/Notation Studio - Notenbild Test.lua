-- @description Notation Studio - Notenbild Test (READ ONLY)
-- @version 0.2.3-test
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
  local score_left=x+148*scale
  local total_width=width-(160*scale)
  local bar_width=total_width/bars
  text(dl,x+9*scale,y-23*scale,track.name,INK)
  -- Stable G-minor key signature (Bb, Eb). Do not repeat the two flats
  -- before every occurrence of B or E.
  text(dl,score_left-77*scale,y+12*scale,clef=='treble' and 'G' or 'F',CYAN)
  local key_steps=clef=='treble' and {34,37} or {20,23}
  for i,diatonic in ipairs(key_steps) do
    local kx=score_left-(57-(i-1)*19)*scale
    local ky=bottom-(diatonic-reference)*step
    text(dl,kx,ky-11*scale,'b',INK)
  end
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
    local state={} -- accidentals last only inside the measure
    for _,chord in ipairs(core.group_onsets(onset)) do
      local t=(chord.start-bs)/model.bar
      local base_x=score_left+b*bar_width+math.max(14,math.min(bar_width-12,t*bar_width))
      local low_step,high_step=nil,nil
      local lowest_y,highest_y=nil,nil
      local shortest=math.huge
      local previous_step=nil
      for ni,n in ipairs(chord.notes) do
        local pstep=core.spell(n.pitch)
        local ny=bottom-(pstep-reference)*step
        ny=math.max(y-57*scale,math.min(bottom+65*scale,ny))
        -- Adjacent staff steps in chords require displaced noteheads.
        local shift=(previous_step and math.abs(pstep-previous_step)==1) and 10*scale or 0
        previous_step=pstep
        local nx=base_x+shift
        if pstep<reference then
          for st=-2,pstep-reference,-2 do
            line(dl,nx-12*scale,bottom-st*step,nx+12*scale,bottom-st*step,BLACK,1.1)
          end
        elseif pstep>reference+8 then
          for st=10,pstep-reference,2 do
            line(dl,nx-12*scale,bottom-st*step,nx+12*scale,bottom-st*step,BLACK,1.1)
          end
        end
        local accidental=core.notated_accidental(n.pitch,state)
        if accidental then
          text(dl,nx-(23+ni*7)*scale,ny-11*scale,accidental,CYAN)
        end
        notehead(dl,nx,ny,n.duration<2)
        if n.duration==0.375 or n.duration==0.75 or n.duration==1.5 or n.duration==3 then
          r.ImGui_DrawList_AddCircleFilled(dl,nx+13*scale,ny,1.8*scale,INK,8)
        end
        low_step=math.min(low_step or pstep,pstep)
        high_step=math.max(high_step or pstep,pstep)
        lowest_y=math.max(lowest_y or ny,ny)
        highest_y=math.min(highest_y or ny,ny)
        shortest=math.min(shortest,n.duration)
      end
      -- Shared stem for simultaneous pitches, instead of one stem per head.
      -- Different chord durations and independent voices are not resolved yet.
      if shortest<4 and #chord.notes>0 then
        local midpoint=(low_step+high_step)/2
        local up=midpoint-reference<4
        local stemx=base_x+(up and 7 or -7)*scale
        local anchory=up and highest_y or lowest_y
        local tip=anchory+(up and -31 or 31)*scale
        line(dl,stemx,anchory,stemx,tip,INK,1.55)
        if shortest<=0.5 then
          line(dl,stemx,tip,stemx+(up and 9 or -9)*scale,
            tip+(up and 11 or -11)*scale,INK,1.9)
        end
      end

    end
  end
end
refresh()
local function loop()
  if not open then return end
  local visible
  visible,open=r.ImGui_Begin(ctx,'Notation Studio · Notenbild 0.2.3 TEST###score_preview',open)
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
    r.ImGui_Text(ctx,'Tonart der Testanzeige: g-Moll (2 b). Akkorde vereinfacht, noch keine getrennte Stimmenfuehrung/Balken/Bindungen.')
    if model and #model.tracks==1 then
      r.ImGui_Text(ctx,'Nur 1 MIDI-Item: fuer die ganze Orgelpartitur bitte Manual I, Manual II und Pedal im Arrangement markieren.')
    end
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
