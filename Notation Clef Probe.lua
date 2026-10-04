-- @description Notation Clef Probe
-- @version 0.2.0
-- @author Klangwerke
-- @about Two-step diagnostic probe for REAPER default-clef storage. Does not modify the project.

local SCRIPT_NAME="Notation Clef Probe"
local EXT="NotationClefProbe"
local BASELINE_KEY="Baseline"
local BASELINE_DESC_KEY="BaselineDesc"

local function esc(s)
 s=tostring(s or "")
 return s:gsub("\\","\\\\"):gsub("\r","\\r"):gsub("\n","\\n"):gsub("\t","\\t")
end

local function guid_take(take)
 local ok,g=reaper.GetSetMediaItemTakeInfo_String(take,"GUID","",false)
 return ok and g or ""
end

local function guid_item(item)
 local ok,g=reaper.GetSetMediaItemInfo_String(item,"GUID","",false)
 return ok and g or ""
end

local function track_name(track)
 local ok,n=reaper.GetTrackName(track,"")
 return ok and n or ""
end

local function collect()
 local ed=reaper.MIDIEditor_GetActive()
 if not ed then return nil,"Kein aktiver MIDI-Editor." end

 local takes={}
 if type(reaper.MIDIEditor_EnumTakes)=="function" then
  local i=0
  while true do
   local tk=reaper.MIDIEditor_EnumTakes(ed,i,true)
   if not tk then break end
   if reaper.ValidatePtr2(0,tk,"MediaItem_Take*") and reaper.TakeIsMIDI(tk) then takes[#takes+1]=tk end
   i=i+1
  end
 else
  local tk=reaper.MIDIEditor_GetTake(ed)
  if tk and reaper.TakeIsMIDI(tk) then takes[1]=tk end
 end

 if #takes==0 then return nil,"Kein MIDI-Take im aktiven Editor." end

 local out={}
 out[#out+1]="reaper_version="..tostring(reaper.GetAppVersion())

 for ti,tk in ipairs(takes) do
  local item=reaper.GetMediaItemTake_Item(tk)
  local tr=item and reaper.GetMediaItem_Track(item) or nil
  out[#out+1]=string.format("===== TAKE %d =====",ti)
  out[#out+1]="take_guid="..guid_take(tk)
  out[#out+1]="item_guid="..guid_item(item)
  out[#out+1]="track_name="..track_name(tr)

  local _,_,_,text_count=reaper.MIDI_CountEvts(tk)
  out[#out+1]="--- TEXT/SYSEX ---"
  for i=0,(text_count or 0)-1 do
   local ok,sel,mut,ppq,typ,msg=reaper.MIDI_GetTextSysexEvt(tk,i)
   if ok then
    out[#out+1]=string.format("TEXT %d sel=%s mut=%s ppq=%.9f type=%d msg=%s",
      i,tostring(sel),tostring(mut),ppq or 0,typ or -1,esc(msg))
   end
  end

  out[#out+1]="--- ITEM CHUNK ---"
  local ok_item,item_chunk=reaper.GetItemStateChunk(item,"",false)
  out[#out+1]=ok_item and item_chunk or "<item chunk failed>"

  out[#out+1]="--- TRACK CHUNK ---"
  if tr then
   local ok_track,track_chunk=reaper.GetTrackStateChunk(tr,"",false)
   out[#out+1]=ok_track and track_chunk or "<track chunk failed>"
  end
 end

 return table.concat(out,"\n"),nil
end

local function diff_lines(a,b)
 local A,B={},{}
 for line in tostring(a or ""):gmatch("[^\n]+") do A[line]=(A[line] or 0)+1 end
 for line in tostring(b or ""):gmatch("[^\n]+") do B[line]=(B[line] or 0)+1 end
 local out={"=== NUR VORHER ==="}
 for line,n in pairs(A) do
  local d=n-(B[line] or 0)
  for _=1,math.max(0,d) do out[#out+1]=line end
 end
 out[#out+1]=""
 out[#out+1]="=== NUR NACHHER ==="
 for line,n in pairs(B) do
  local d=n-(A[line] or 0)
  for _=1,math.max(0,d) do out[#out+1]=line end
 end
 return table.concat(out,"\n")
end

local snap,err=collect()
if not snap then
 reaper.ShowMessageBox(err,SCRIPT_NAME,0)
 return
end

local baseline=reaper.GetExtState(EXT,BASELINE_KEY)

if baseline=="" then
 reaper.SetExtState(EXT,BASELINE_KEY,snap,false)
 reaper.SetExtState(EXT,BASELINE_DESC_KEY,os.date("%Y-%m-%d %H:%M:%S"),false)
 reaper.ShowMessageBox(
  "Ausgangszustand gespeichert.\n\nJetzt bitte NICHT 'Change clef' unter Measure settings verwenden, sondern:\n\nTrack settings → Default clef → Treble\n\nDanach dieses Probe-Skript ein zweites Mal starten.",
  SCRIPT_NAME,0)
 return
end

local diff=diff_lines(baseline,snap)
local path=reaper.GetResourcePath().."/Notation-Clef-Probe-DIFF-"..os.date("%Y%m%d-%H%M%S")..".txt"
local file=io.open(path,"wb")
if not file then
 reaper.ShowMessageBox("Diff-Datei konnte nicht geschrieben werden:\n"..path,SCRIPT_NAME,0)
 return
end
file:write(diff)
file:close()

reaper.DeleteExtState(EXT,BASELINE_KEY,false)
reaper.DeleteExtState(EXT,BASELINE_DESC_KEY,false)

reaper.ShowMessageBox(
 "Vergleich gespeichert:\n\n"..path.."\n\nDer gespeicherte Ausgangszustand wurde zurückgesetzt.\nBitte schick mir diese DIFF-Datei.",
 SCRIPT_NAME,0)
