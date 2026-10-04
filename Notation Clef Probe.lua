-- @description Notation Clef Probe
-- @version 0.3.0
-- @author Klangwerke
-- @about Minimal two-step probe: compares only REAPER notation events (type 15) before/after changing Track settings -> Default clef.

local SCRIPT_NAME="Notation Clef Probe"
local EXT="NotationClefProbe"
local KEY="BaselineType15"
local KEY_TAKE="BaselineTakeGUID"

local function esc(s)
 s=tostring(s or "")
 return s:gsub("\\","\\\\"):gsub("\r","\\r"):gsub("\n","\\n"):gsub("\t","\\t")
end

local function active_take()
 local ed=reaper.MIDIEditor_GetActive()
 if not ed then return nil,"Kein aktiver MIDI-Editor." end
 local tk=reaper.MIDIEditor_GetTake(ed)
 if not tk or not reaper.TakeIsMIDI(tk) then return nil,"Kein aktiver MIDI-Take im MIDI-Editor." end
 return tk
end

local function take_guid(tk)
 local ok,g=reaper.GetSetMediaItemTakeInfo_String(tk,"GUID","",false)
 return ok and g or ""
end

local function collect_type15(tk)
 local out={}
 local _,_,_,text_count=reaper.MIDI_CountEvts(tk)
 for i=0,(text_count or 0)-1 do
  local ok,sel,mut,ppq,typ,msg=reaper.MIDI_GetTextSysexEvt(tk,i)
  if ok and typ==15 then
   out[#out+1]=string.format("ppq=%.9f sel=%s mut=%s msg=%s",
    ppq or 0,tostring(sel),tostring(mut),esc(msg))
  end
 end
 table.sort(out)
 return table.concat(out,"\n")
end

local function multiset(s)
 local t={}
 for line in tostring(s or ""):gmatch("[^\n]+") do t[line]=(t[line] or 0)+1 end
 return t
end

local function diff(before,after)
 local A,B=multiset(before),multiset(after)
 local out={"=== NUR VORHER ==="}
 local n=0
 for line,c in pairs(A) do
  local d=c-(B[line] or 0)
  for _=1,math.max(0,d) do out[#out+1]=line; n=n+1 end
 end
 out[#out+1]=""
 out[#out+1]="=== NUR NACHHER ==="
 for line,c in pairs(B) do
  local d=c-(A[line] or 0)
  for _=1,math.max(0,d) do out[#out+1]=line; n=n+1 end
 end
 if n==0 then
  out[#out+1]="<KEINE ÄNDERUNG BEI TYPE-15-NOTATION-EVENTS>"
 end
 return table.concat(out,"\n"),n
end

local tk,err=active_take()
if not tk then
 reaper.ShowMessageBox(err,SCRIPT_NAME,0)
 return
end

local guid=take_guid(tk)
local now=collect_type15(tk)
local baseline=reaper.GetExtState(EXT,KEY)
local baseline_guid=reaper.GetExtState(EXT,KEY_TAKE)

if baseline=="" and baseline_guid=="" then
 reaper.SetExtState(EXT,KEY,now,true)
 reaper.SetExtState(EXT,KEY_TAKE,guid,true)
 reaper.ShowMessageBox(
  "1. Zustand gespeichert.\n\nJetzt im selben MIDI-Take:\nTrack settings → Default clef → Treble\n\nDanach dieses Skript noch einmal starten.\n\nEs werden ausschließlich REAPER-Notation-Events vom Typ 15 verglichen.",
  SCRIPT_NAME,0)
 return
end

if baseline_guid~=guid then
 reaper.ShowMessageBox(
  "Der aktive MIDI-Take ist nicht derselbe wie beim ersten Lauf.\n\nBitte wieder den ursprünglichen Take öffnen und das Skript erneut starten.",
  SCRIPT_NAME,0)
 return
end

local report,n=diff(baseline,now)
local path=reaper.GetResourcePath().."/Notation-Clef-Type15-DIFF-"..os.date("%Y%m%d-%H%M%S")..".txt"
local file=io.open(path,"wb")
if not file then
 reaper.ShowMessageBox("Datei konnte nicht geschrieben werden:\n"..path,SCRIPT_NAME,0)
 return
end
file:write("REAPER "..tostring(reaper.GetAppVersion()).."\n")
file:write("take_guid="..guid.."\n\n")
file:write(report)
file:close()

reaper.DeleteExtState(EXT,KEY,true)
reaper.DeleteExtState(EXT,KEY_TAKE,true)

local msg
if n==0 then
 msg="Vergleich abgeschlossen.\n\nDefault clef verändert KEIN Type-15-Notation-Event in diesem Take.\n\nDamit können wir die clef=...-Behauptung ausschließen.\n\nDatei:\n"..path
else
 msg="Vergleich abgeschlossen. Es gibt Unterschiede bei Type-15-Notation-Events.\n\nDatei:\n"..path.."\n\nBitte schick mir diese Datei."
end
reaper.ShowMessageBox(msg,SCRIPT_NAME,0)
