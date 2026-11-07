-- @description Native Notation Studio - Notenansicht optimieren (offline)
-- @version 0.1.0-test
-- @author Klangwerke
-- @about No API, no MIDI note writing. Display quantization, clefs, bounded horizontal/vertical zoom.
-- Automatic clef choice uses checked SCORE edits, undo and source verification. Vertical zoom is heuristic.
local R=reaper
local function require_action(section,names)
 for i=0,19999 do
  local id,label=R.kbd_enumerateActions(section,i)
  if not id or id==0 then break end
  label=(label or ''):lower():gsub('^%s+',''):gsub('%s+$','')
  for _,name in ipairs(names) do if label==name then return id end end
 end
 error('REAPER-Aktion nicht gefunden: '..table.concat(names,' / '))
end
-- Pure offline helpers: original project clef decision and SCORE validation.
-- Native Notation Studio: Offline clef choice and safe REAPER SCORE chunk utilities.
-- Extracted from the existing project implementation; no AI, API, or MIDI edits.
local function finite(n) return type(n)=="number" and n==n and math.abs(n)<math.huge end
local function track_clef_chunk(chunk,wanted,force)
 assert(type(chunk)=="string" and #chunk<4*1024*1024,"Track-State fehlt oder ist zu gross.")
 local depth,root,found,current=0,false,nil,0
 local pos=1
 local top,scoreFields,scoreExtra={},nil,""
 while pos<=#chunk do
  local stop=chunk:find("\n",pos,true) or #chunk+1
  local line=chunk:sub(pos,stop-1):gsub("\r$","")
  local text=line:match("^%s*(.-)%s*$")
  if depth==1 then top[#top+1]={first=pos,last=math.min(stop,#chunk),text=text} end
  if depth==1 and text:match("^SCORE%s") then
   assert(not found,"Mehrdeutige SCORE-Zeilen im Track.")
   local prefix,first,gap,clef,rest=line:match("^(%s*SCORE%s+)(%S+)(%s+)(%S+)(.*)$")
   local a,b,extra
   if rest then a,b,extra=rest:match("^%s+(%S+)%s+(%S+)(.*)$") end
   current=tonumber(clef)
   assert(first and tonumber(first) and tonumber(first)%1==0 and current and current%1==0 and current>=0 and current<=12
    and finite(tonumber(a)) and finite(tonumber(b)),"Unbekanntes SCORE-Format.")
   scoreFields={tonumber(first),current,tonumber(a),tonumber(b)};scoreExtra=extra or ""
   found={first=pos+#prefix+#first+#gap,last=pos+#prefix+#first+#gap+#clef-1}
  end
  if text:sub(1,1)=="<" then
   if depth==0 then assert(not root and (text=="<TRACK" or text:match("^<TRACK%s")),"Kein eindeutiger Track-State.");root=true end
   depth=depth+1
  elseif text==">" then depth=depth-1;assert(depth>=0,"Beschaedigter Track-State.")
  elseif depth==0 then assert(text=="","Daten ausserhalb des Track-State.") end
  pos=stop+1
 end
 assert(root and depth==0,"Unvollstaendiger Track-State.")
 local info={top=top,fields=scoreFields or {0,0,0,0},extra=scoreExtra}
 if wanted==nil or (wanted==current and not (force and not found)) then return chunk,current,info end
 assert(wanted%1==0 and wanted>=0 and wanted<=12,"Ungueltiger Schluessel.")
 if found then return chunk:sub(1,found.first-1)..wanted..chunk:sub(found.last+1),current,info end
 local lineEnd=assert(chunk:find("\n",1,true),"Track-Kopf ohne Zeilenende.")
 local nl=chunk:sub(lineEnd-1,lineEnd)=="\r\n" and "\r\n" or "\n"
 return chunk:sub(1,lineEnd).."SCORE 0 "..wanted.." 0 0"..nl..chunk:sub(lineEnd+1),current,info
end
-- REAPER 7.84 moves SCORE into its canonical position and may add the
-- default LANEREC line. Permit only those observed normalizations; compare
-- every SCORE value and all remaining track bytes, including nested chunks.
local function track_equivalent(expected,actual)
 local _,_,a=track_clef_chunk(expected)
 local _,_,b=track_clef_chunk(actual)
 for i=1,4 do if a.fields[i]~=b.fields[i] then return false end end
 if a.extra~=b.extra then return false end
 local function stripped(chunk,info)
  local result,pos={},1
  for _,line in ipairs(info.top) do
   if line.text:match("^SCORE%s") or line.text=="LANEREC -1 -1 -1 0" then
    result[#result+1]=chunk:sub(pos,line.first-1);pos=line.last+1
   end
  end
  result[#result+1]=chunk:sub(pos)
  return table.concat(result)
 end
 return stripped(expected,a)==stripped(actual,b)
end
local steps={0,0,1,1,2,3,3,4,4,5,5,6}
local function diatonic(p) return math.floor(p/12)*7+steps[p%12+1] end
local staff={{37,45},{25,33},{31,39},{29,37}} -- E4/F5, G2/A3, F3/G4, D3/E4
local function choose_clef(notes,current)
 if current>=5 then return current end -- preserve octave/percussion/chart conventions
 local costs={0,0,0,0}
 local active,drums,low,high={},0,127,0
 for _,n in ipairs(notes) do
  if not n.muted then
   if n.channel==9 then drums=drums+1 else
    active[#active+1]=n;low=math.min(low,n.pitch);high=math.max(high,n.pitch)
    local p=diatonic(n.pitch)
    local weight=math.max(0.25,math.min(2,n.duration_qn))
    for clef,range in ipairs(staff) do
     local distance=math.max(range[1]-p,p-range[2],0)
     local ledger=math.floor(distance/2)
     costs[clef]=costs[clef]+weight*ledger*ledger
    end
   end
  end
 end
 if #active==0 then return drums>0 and 10 or current end
 -- Retain an existing piano staff only for clear simultaneous broad chords.
 -- A single line, even with a large range, never creates a piano staff.
 if current==0 and low<55 and high>67 then
  for _,n in ipairs(active) do
   local chord,lo,hi=0,127,0
   for _,other in ipairs(active) do
    if math.abs(n.start_qn-other.start_qn)<0.08 and math.min(n.duration_qn,other.duration_qn)>0.125 then
     chord=chord+1;lo=math.min(lo,other.pitch);hi=math.max(hi,other.pitch)
    end
   end
   if chord>=3 and lo<55 and hi>67 then return 0 end
  end
 end
 local best=costs[2]<costs[1] and 2 or 1
 if current==1 or current==2 then
  if costs[current]<=costs[best]+0.5 then return current end
 elseif current==3 or current==4 then
  if costs[current]<=costs[best]*1.1+0.5 then return current end
 end
 return best
end


local function midi_inventory(track)
 local result={}
 for i=0,R.CountTrackMediaItems(track)-1 do
  local item=R.GetTrackMediaItem(track,i)
  for j=0,R.CountTakes(item)-1 do
   local take=R.GetTake(item,j)
   if R.TakeIsMIDI(take) then
    local ok,guid=R.GetSetMediaItemTakeInfo_String(take,"GUID","",false)
    assert(ok and guid and guid~="","Track MIDI GUID fehlt.")
    local read,raw=R.MIDI_GetAllEvts(take)
    assert(read and type(raw)=="string","Track MIDI konnte nicht gelesen werden.")
    assert(result[guid]==nil,"Doppelte Take GUID.")
    result[guid]=raw
   end
  end
 end
 return result
end
local function same_inventory(a,b)
 for id,raw in pairs(a) do if b[id]~=raw then return false end end
 for id in pairs(b) do if a[id]==nil then return false end end
 return true
end
local function prepare_clef_targets(takes)
 local byTrack,targets={},{}
 for _,take in ipairs(takes) do
  local item=assert(R.GetMediaItemTake_Item(take),"Item fehlt.")
  local track=assert(R.GetMediaItem_Track(item),"Track fehlt.")
  local entry=byTrack[track]
  if not entry then
   local ok,chunk=R.GetTrackStateChunk(track,"",false)
   assert(ok and type(chunk)=="string","Track-Zustand nicht lesbar.")
   local _,current=track_clef_chunk(chunk)
   entry={track=track,before=chunk,current=current,notes={},midi=midi_inventory(track)}
   byTrack[track]=entry
   targets[#targets+1]=entry
  end
  local ok,n=R.MIDI_CountEvts(take)
  assert(ok and type(n)=="number" and n>=0,"Notenanzahl nicht lesbar.")
  for i=0,n-1 do
   local yes,_,muted,startTick,endTick,channel,pitch=R.MIDI_GetNote(take,i)
   assert(yes and endTick>startTick,"MIDI-Note nicht lesbar.")
   local startQN=R.MIDI_GetProjQNFromPPQPos(take,startTick)
   local endQN=R.MIDI_GetProjQNFromPPQPos(take,endTick)
   entry.notes[#entry.notes+1]={muted=muted,channel=channel,pitch=pitch,
    start_qn=startQN,duration_qn=endQN-startQN}
  end
 end
 for _,entry in ipairs(targets) do
  entry.wanted=choose_clef(entry.notes,entry.current)
  if entry.wanted~=entry.current then
   entry.patched=track_clef_chunk(entry.before,entry.wanted)
  end
 end
 return targets
end
local function commit_clefs(targets,project)
 local changed={}
 for _,entry in ipairs(targets) do if entry.patched then changed[#changed+1]=entry end end
 if #changed==0 then return end
 for _,entry in ipairs(targets) do
  local ok,current=R.GetTrackStateChunk(entry.track,"",false)
  assert(ok and current==entry.before,"Track wurde zwischenzeitlich veraendert.")
  assert(same_inventory(entry.midi,midi_inventory(entry.track)),"MIDI wurde zwischenzeitlich veraendert.")
 end
 R.Undo_BeginBlock2(project)
 local attempted=0
 local ok,why=pcall(function()
  for i,entry in ipairs(changed) do
   attempted=i
   assert(R.SetTrackStateChunk(entry.track,entry.patched,false),"Notenschluessel konnte nicht gesetzt werden.")
   local read,actual=R.GetTrackStateChunk(entry.track,"",false)
   assert(read and track_equivalent(entry.patched,actual),"Schluessel-Ruecklesepruefung fehlgeschlagen.")
   assert(same_inventory(entry.midi,midi_inventory(entry.track)),"MIDI-Daten nach Schluesselwechsel veraendert.")
  end
 end)
 if not ok then
  local errors={}
  for i=attempted,1,-1 do
   local entry=changed[i]
   local restored=pcall(function()
    local original=track_clef_chunk(entry.before,entry.current,true)
    assert(R.SetTrackStateChunk(entry.track,original,false))
    local read,actual=R.GetTrackStateChunk(entry.track,"",false)
    assert(read and track_equivalent(original,actual))
    assert(same_inventory(entry.midi,midi_inventory(entry.track)))
   end)
   if not restored then errors[#errors+1]=tostring(i) end
  end
  if #errors>0 then why=tostring(why)..
   "\nRuecknahme unvollstaendig bei Track(s) "..table.concat(errors,",")..". Bitte REAPER Undo pruefen." end
 end
 R.Undo_EndBlock2(project,ok and "Native Notation Studio: Notenschluessel" or
  "Native Notation Studio: Ruecknahme",1)
 assert(ok,why)
end

-- REAPER does not expose notation staff height as a stable numeric setting.
-- Apply a SMALL, bounded number of native vertical zoom commands, never a
-- repeated 24-step reset. Remember the applied delta for this editor session.
local function vertical_zoom(editor,section,takes)
 local zoomIn=require_action(section,{'view: zoom in vertically'})
 local zoomOut=require_action(section,{'view: zoom out vertically'})
 local height=nil
 if R.JS_Window_GetClientSize then
  local ok,_,h=pcall(R.JS_Window_GetClientSize,editor)
  if ok and finite(h) and h>=300 and h<=12000 then height=h end
 end
 -- Without reliable dimensions, preserve the user-selected vertical zoom.
 if not height then return false end
 local tracks={}
 for _,take in ipairs(takes) do
  local item=R.GetMediaItemTake_Item(take)
  if item then tracks[R.GetMediaItem_Track(item)]=true end
 end
 local count=0
 for _ in pairs(tracks) do count=count+1 end
 count=math.max(count,1)
 -- Space per staff determines whether a moderate enlargement is appropriate.
 -- Existing UI layout cannot be measured; this deliberately favors small steps.
 local perTrack=(height-160)/count
 local target=perTrack>=280 and 4 or perTrack>=190 and 3 or perTrack>=135 and 2 or perTrack>=100 and 1 or 0
 local key='VerticalZoom_'..tostring(editor):gsub('[^%w]','')..'_'..tostring(R.EnumProjects(-1,''))
 local previous=tonumber(R.GetExtState('NativeNotationStudioOffline',key)) or 0
 if previous<0 or previous>4 or previous%1~=0 then previous=0 end
 local delta=target-previous
 if delta==0 then return true end
 local action=delta>0 and zoomIn or zoomOut
 for i=1,math.abs(delta) do
  R.MIDIEditor_OnCommand(editor,action)
 end
 R.SetExtState('NativeNotationStudioOffline',key,tostring(target),false)
 return true
end

local function run()
 local project=R.EnumProjects(-1,'')
 local editor=assert(R.MIDIEditor_GetActive(),'Bitte den REAPER-MIDI-/Notationseditor oeffnen.')
 assert(R.MIDIEditor_GetMode(editor)~=-1,'MIDI-Editor ist geschlossen.')
 local takes,seen={},{}
 local firstQN=nil
 for i=0,65535 do
  local take=R.MIDIEditor_EnumTakes(editor,i,false)
  if not take then break end
  if not seen[take] and R.TakeIsMIDI(take) then
   seen[take]=true;takes[#takes+1]=take
   local item=assert(R.GetMediaItemTake_Item(take))
   local itemQN=R.TimeMap2_timeToQN(project,R.GetMediaItemInfo_Value(item,'D_POSITION'))
   if not firstQN or itemQN<firstQN then firstQN=itemQN end
  end
 end
 assert(#takes>0,'Keine sichtbaren MIDI-Takes gefunden.')
 local section=assert(R.SectionFromUniqueID(32060),'MIDI-Aktionsbereich nicht verfuegbar.')
 -- Resolve actions before changing anything. Do not call MIDI-data quantization.
 local notation=require_action(section,{'view: mode: musical notation','view: mode: notation','mode: notation'})
 -- Conservative, easily readable baseline. Unlike 1/64, 1/16 as the minimum
 -- prevents rendering tiny ornaments/expressive fragments as packed 64ths.
 local quant=require_action(section,{'notation: set display quantization to 1/8'})
 local minimum=require_action(section,{'notation: set minimum display quantization note length to 1/16'})
 local proportional=require_action(section,{'notation: proportional (musical) note spacing'})
 -- Resolve vertical zoom actions before making any view or track changes.
 local verticalIn=require_action(section,{'view: zoom in vertically'})
 local verticalOut=require_action(section,{'view: zoom out vertically'})
 -- Optional REAPER-native setting: reduce unnecessary ties in the score.
 -- Never toggle if the action state cannot be read reliably.
 local minimizeTies=nil
 for i=0,19999 do
  local id,label=R.kbd_enumerateActions(section,i)
  if not id or id==0 then break end
  if (label or ''):lower()=='notation: minimize ties for all notes by default' then
   minimizeTies=id;break
  end
 end
 local old=R.MIDIEditor_GetSetting_int(editor,'pixels_per_timebase_unit')
 assert(type(old)=='number' and old>=0,'Horizontaler Zoom nicht lesbar.')
 local timebase=R.MIDIEditor_GetSetting_int(editor,'timebase_unit')
 assert(timebase==0 or timebase==1,'Zeitbasis des Editors nicht unterstuetzt.')
 local _,startQN,endQN=R.TimeMap_QNToMeasures(project,firstQN or 0)
 assert(type(startQN)=='number' and type(endQN)=='number' and endQN>startQN,'Taktlaenge nicht lesbar.')
 -- Never guess a window width: a wrong guess made the previous Windows
 -- zoom results unreliable. JS_ReaScriptAPI is optional; without it, keep
 -- the user's existing horizontal zoom.
 local desired=nil
 if R.JS_Window_GetClientSize then
  local ok,width=pcall(R.JS_Window_GetClientSize,editor)
  if ok and type(width)=='number' and width>=500 and width<20000 then
   local pxPerQN=(width-240)/(4*(endQN-startQN))
   if timebase==0 then
    local bpm=R.TimeMap2_GetDividedBpmAtTime(project,R.GetCursorPositionEx(project))
    assert(type(bpm)=='number' and bpm>0,'Tempo fuer horizontale Skalierung fehlt.')
    pxPerQN=pxPerQN*bpm/60
   end
   local value=math.floor(pxPerQN*1024+0.5)
   assert(value>0 and value<2147483647,'Ungueltiger horizontaler Zoom.')
   desired=value
  end
 end
 R.MIDIEditor_OnCommand(editor,notation)
 R.MIDIEditor_OnCommand(editor,quant)
 R.MIDIEditor_OnCommand(editor,minimum)
 if R.GetToggleCommandStateEx(32060,proportional)==0 then
  R.MIDIEditor_OnCommand(editor,proportional)
 end
 if minimizeTies and R.GetToggleCommandStateEx(32060,minimizeTies)==0 then
  R.MIDIEditor_OnCommand(editor,minimizeTies)
 end
 if desired and desired~=old then
  if not R.MIDIEditor_SetSetting_int(editor,'pixels_per_timebase_unit',desired) or
   R.MIDIEditor_GetSetting_int(editor,'pixels_per_timebase_unit')~=desired then
   R.MIDIEditor_SetSetting_int(editor,'pixels_per_timebase_unit',old)
   error('Horizontaler Zoom konnte nicht gesetzt werden.')
  end
 end
 -- Prepare after view commands: those commands may change TRACK SCORE state.
 local clefTargets=prepare_clef_targets(takes)
 -- The clef is a track-level notation setting; MIDI events remain byte-identical.
 commit_clefs(clefTargets,project)
 -- After the final staff configuration, enlarge the displayed notation.
 vertical_zoom(editor,section,takes)
end
local ok,why=xpcall(run,debug.traceback)
if not ok then R.ShowMessageBox(tostring(why),'Native Notation Studio - Offline',0) end
