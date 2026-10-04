-- @description Notation Clef Probe
-- @version 0.4.0
-- @author Klangwerke
-- @about Minimal snapshot tool: writes current REAPER notation events (type 15) of the active MIDI take to a timestamped text file. No memory, no comparison, no project modification.

local SCRIPT_NAME="Notation Clef Probe"

local function esc(s)
  s=tostring(s or "")
  return s:gsub("\\","\\\\"):gsub("\r","\\r"):gsub("\n","\\n"):gsub("\t","\\t")
end

local function active_take()
  local ed=reaper.MIDIEditor_GetActive()
  if not ed then return nil,"Kein aktiver MIDI-Editor." end
  local tk=reaper.MIDIEditor_GetTake(ed)
  if not tk or not reaper.TakeIsMIDI(tk) then
    return nil,"Kein aktiver MIDI-Take im MIDI-Editor."
  end
  return tk
end

local function take_guid(tk)
  local ok,g=reaper.GetSetMediaItemTakeInfo_String(tk,"GUID","",false)
  return ok and g or ""
end

local function track_name(tk)
  local item=reaper.GetMediaItemTake_Item(tk)
  local tr=item and reaper.GetMediaItem_Track(item) or nil
  if not tr then return "" end
  local ok,n=reaper.GetTrackName(tr,"")
  return ok and n or ""
end

local function collect_type15(tk)
  local out={}
  local _,_,_,text_count=reaper.MIDI_CountEvts(tk)
  local n=0
  for i=0,(text_count or 0)-1 do
    local ok,sel,mut,ppq,typ,msg=reaper.MIDI_GetTextSysexEvt(tk,i)
    if ok and typ==15 then
      n=n+1
      out[#out+1]=string.format(
        "EVENT %d index=%d ppq=%.9f sel=%s mut=%s msg=%s",
        n,i,ppq or 0,tostring(sel),tostring(mut),esc(msg)
      )
    end
  end
  return out,n
end

local tk,err=active_take()
if not tk then
  reaper.ShowMessageBox(err,SCRIPT_NAME,0)
  return
end

local events,count=collect_type15(tk)
local stamp=os.date("%Y%m%d-%H%M%S")
local path=reaper.GetResourcePath().."/Notation-Clef-SNAPSHOT-"..stamp..".txt"

local f=io.open(path,"wb")
if not f then
  reaper.ShowMessageBox("Datei konnte nicht geschrieben werden:\n"..path,SCRIPT_NAME,0)
  return
end

f:write("REAPER "..tostring(reaper.GetAppVersion()).."\n")
f:write("take_guid="..take_guid(tk).."\n")
f:write("track_name="..track_name(tk).."\n")
f:write("type15_count="..tostring(count).."\n\n")
if count==0 then
  f:write("<KEINE TYPE-15-NOTATION-EVENTS>\n")
else
  f:write(table.concat(events,"\n"))
  f:write("\n")
end
f:close()

reaper.ShowMessageBox(
  "Snapshot gespeichert:\n\n"..path..
  "\n\nJetzt kannst du den Schlüssel ändern und das Skript erneut starten. Es entsteht einfach eine zweite, unabhängige Datei.",
  SCRIPT_NAME,0
)
