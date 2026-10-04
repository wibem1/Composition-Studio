-- @description Notation Clef Probe
-- @version 0.5.0
-- @author Klangwerke
-- @about One-window probe for REAPER Default Clef. Start once, save A, change clef, save B. No ExtState, no automatic comparison, no project modification.

local SCRIPT_NAME="Notation Clef Probe"
local VERSION="0.5.0"

if type(reaper.ImGui_CreateContext)~="function" then
  reaper.ShowMessageBox("Dieses Skript benötigt ReaImGui.",SCRIPT_NAME,0)
  return
end

local ctx=reaper.ImGui_CreateContext(SCRIPT_NAME)
local open=true
local status="1. Treble+Bass einstellen und „Snapshot A“ klicken."

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

local function snapshot(label)
  local tk,err=active_take()
  if not tk then status=err; return end

  local events,count=collect_type15(tk)
  local stamp=os.date("%Y%m%d-%H%M%S")
  local path=reaper.GetResourcePath().."/Notation-Clef-"..label.."-"..stamp..".txt"

  local f=io.open(path,"wb")
  if not f then
    status="Datei konnte nicht geschrieben werden:\n"..path
    return
  end

  f:write("label="..label.."\n")
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

  if label=="A" then
    status="Snapshot A gespeichert.\n\nJetzt in REAPER: Track settings → Default clef → Treble.\nDanach „Snapshot B“ klicken."
  else
    status="Snapshot B gespeichert.\n\nFertig. Bitte die beiden Dateien „Notation-Clef-A-…txt“ und „Notation-Clef-B-…txt“ schicken."
  end
end

local function draw()
  reaper.ImGui_SetNextWindowSize(ctx,520,250,reaper.ImGui_Cond_FirstUseEver())
  local visible
  visible,open=reaper.ImGui_Begin(ctx,SCRIPT_NAME.." v"..VERSION,open)
  if visible then
    reaper.ImGui_TextWrapped(ctx,"Das Skript bleibt geöffnet. Du startest es nur einmal.")
    reaper.ImGui_Separator(ctx)
    if reaper.ImGui_Button(ctx,"1. Snapshot A (Treble+Bass)",-1,40) then
      snapshot("A")
    end
    if reaper.ImGui_Button(ctx,"2. Snapshot B (Treble)",-1,40) then
      snapshot("B")
    end
    reaper.ImGui_Separator(ctx)
    reaper.ImGui_TextWrapped(ctx,status)
    reaper.ImGui_End(ctx)
  end
end

local function loop()
  if not open then return end
  draw()
  reaper.defer(loop)
end

loop()
