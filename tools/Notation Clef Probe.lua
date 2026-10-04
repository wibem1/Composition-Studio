-- @description Notation Clef Probe
-- @version 0.1.0
-- @author Klangwerke
-- @about Diagnostic probe for REAPER notation/default-clef storage. Does not modify the project.

local SCRIPT_NAME="Notation Clef Probe"

local function esc(s)
 s=tostring(s or "")
 return s:gsub("\\","\\\\"):gsub("\r","\\r"):gsub("\n","\\n"):gsub("\t","\\t")
end

local function hex(s,maxlen)
 s=tostring(s or "")
 local out={}
 local n=math.min(#s,maxlen or #s)
 for i=1,n do out[#out+1]=string.format("%02X",s:byte(i)) end
 if n<#s then out[#out+1]="..." end
 return table.concat(out," ")
end

local function guid_take(take)
 local ok,g=reaper.GetSetMediaItemTakeInfo_String(take,"GUID","",false)
 return ok and g or ""
end

local function guid_item(item)
 if type(reaper.BR_GetMediaItemGUID)=="function" then
  local ok,g=pcall(reaper.BR_GetMediaItemGUID,item)
  if ok and g then return g end
 end
 local ok,g=reaper.GetSetMediaItemInfo_String(item,"GUID","",false)
 return ok and g or ""
end

local function track_name(track)
 local ok,n=reaper.GetTrackName(track,"")
 return ok and n or ""
end

local function append(a,s) a[#a+1]=s end

local function dump_take(take,idx)
 local out={}
 local item=reaper.GetMediaItemTake_Item(take)
 local track=item and reaper.GetMediaItem_Track(item) or nil

 append(out,string.format("===== TAKE %d =====",idx))
 append(out,"take_guid="..guid_take(take))
 append(out,"item_guid="..guid_item(item))
 append(out,"track_name="..track_name(track))
 append(out,"take_is_midi="..tostring(reaper.TakeIsMIDI(take)))

 local ok_name,take_name=reaper.GetSetMediaItemTakeInfo_String(take,"P_NAME","",false)
 append(out,"take_name="..esc(ok_name and take_name or ""))

 local _,note_count,cc_count,text_count=reaper.MIDI_CountEvts(take)
 append(out,string.format("MIDI_CountEvts notes=%d cc=%d textsysex=%d",note_count or -1,cc_count or -1,text_count or -1))

 append(out,"--- TEXT/SYSEX EVENTS ---")
 for i=0,(text_count or 0)-1 do
  local ok,sel,mut,ppq,typ,msg=reaper.MIDI_GetTextSysexEvt(take,i)
  if ok then
   append(out,string.format(
    "TEXT %d sel=%s mut=%s ppq=%.9f type=%d msg=%s hex=%s",
    i,tostring(sel),tostring(mut),ppq or 0,typ or -1,esc(msg),hex(msg,256)
   ))
  end
 end

 append(out,"--- ITEM STATE CHUNK ---")
 local ok_item,item_chunk=reaper.GetItemStateChunk(item,"",false)
 append(out,ok_item and item_chunk or "<GetItemStateChunk failed>")

 append(out,"--- TRACK STATE CHUNK ---")
 if track then
  local ok_track,track_chunk=reaper.GetTrackStateChunk(track,"",false)
  append(out,ok_track and track_chunk or "<GetTrackStateChunk failed>")
 else
  append(out,"<no track>")
 end

 return table.concat(out,"\n")
end

local ed=reaper.MIDIEditor_GetActive()
if not ed then
 reaper.ShowMessageBox("Kein aktiver MIDI-Editor. Bitte den Notationseditor öffnen und dieses Skript von dort starten.",SCRIPT_NAME,0)
 return
end

local takes={}
if type(reaper.MIDIEditor_EnumTakes)=="function" then
 local i=0
 while true do
  local tk=reaper.MIDIEditor_EnumTakes(ed,i,true)
  if not tk then break end
  if reaper.ValidatePtr2(0,tk,"MediaItem_Take*") and reaper.TakeIsMIDI(tk) then
   takes[#takes+1]=tk
  end
  i=i+1
 end
else
 local tk=reaper.MIDIEditor_GetTake(ed)
 if tk and reaper.TakeIsMIDI(tk) then takes[1]=tk end
end

if #takes==0 then
 reaper.ShowMessageBox("Im aktiven MIDI-Editor wurde kein MIDI-Take gefunden.",SCRIPT_NAME,0)
 return
end

local lines={}
append(lines,"Notation Clef Probe v0.1.0")
append(lines,"timestamp="..os.date("%Y-%m-%d %H:%M:%S"))
append(lines,"reaper_version="..tostring(reaper.GetAppVersion()))
append(lines,"active_takes="..tostring(#takes))
append(lines,"")

for i,tk in ipairs(takes) do
 append(lines,dump_take(tk,i))
 append(lines,"")
end

local base=reaper.GetResourcePath().."/Notation-Clef-Probe-"..os.date("%Y%m%d-%H%M%S")..".txt"
local f=io.open(base,"wb")
if not f then
 reaper.ShowMessageBox("Diagnosedatei konnte nicht geschrieben werden:\n"..base,SCRIPT_NAME,0)
 return
end
f:write(table.concat(lines,"\n"))
f:close()

reaper.ShowMessageBox("Snapshot gespeichert:\n\n"..base.."\n\nJetzt Default Clef manuell ändern und das Skript ein zweites Mal starten.",SCRIPT_NAME,0)
