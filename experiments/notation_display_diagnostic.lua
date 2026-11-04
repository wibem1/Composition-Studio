-- @description Composition Studio - Inspect selected note display offsets (READ ONLY)
-- @version 0.1.0-test
-- Does not change MIDI or notation metadata. Run with the MIDI editor open.
local r = reaper
local editor = r.MIDIEditor_GetActive()
if not editor then
  r.ShowConsoleMsg("Notation diagnosis: no active MIDI editor.\n")
  return
end
local function inspect(take, index)
  if not take or not r.TakeIsMIDI(take) then return 0 end
  local _, noteCount, _, textCount = r.MIDI_CountEvts(take)
  local selected = {}
  local count = 0
  for n = 0, noteCount-1 do
    local ok, isSelected, _, startPPQ, endPPQ, channel, pitch = r.MIDI_GetNote(take,n)
    if ok and isSelected then
      local key = string.format("%.8f:%d:%d",startPPQ,channel,pitch)
      selected[key] = selected[key] or {}
      table.insert(selected[key], {startPPQ=startPPQ,endPPQ=endPPQ,channel=channel,pitch=pitch})
      count=count+1
    end
  end
  if count==0 then return 0 end
  local annotations={}
  for n=0,textCount-1 do
    local ok,_,_,ppq,typ,msg = r.MIDI_GetTextSysexEvt(take,n)
    if ok and typ==15 then
      local channel,pitch = msg:match("^NOTE (%d+) (%d+)")
      if channel then
        local key=string.format("%.8f:%d:%d",ppq,tonumber(channel),tonumber(pitch))
        if selected[key] then
          annotations[key]=annotations[key] or {}
          table.insert(annotations[key],msg)
        end
      end
    end
  end
  r.ShowConsoleMsg(string.format("Take %d: %d selected notes\n",index,count))
  for key,notes in pairs(selected) do
    local tags=annotations[key] or {}
    for _,note in ipairs(notes) do
      r.ShowConsoleMsg(string.format("  pitch=%d channel=%d startPPQ=%.4f endPPQ=%.4f lengthPPQ=%.4f\n",note.pitch,note.channel,note.startPPQ,note.endPPQ,note.endPPQ-note.startPPQ))
    end
    if #tags==0 then
      r.ShowConsoleMsg("    notation: no explicit NOTE event (native display defaults)\n")
    else
      for _,msg in ipairs(tags) do
        local pos=msg:match("%f[%w]disp_pos%s+([%+%-]?[%d%.]+)")
        local len=msg:match("%f[%w]disp_len%s+([%+%-]?[%d%.]+)")
        r.ShowConsoleMsg("    disp_pos="..tostring(pos or "<unset>").." disp_len="..tostring(len or "<unset>").."\n")
      end
      if #notes>1 then r.ShowConsoleMsg("    WARNING: duplicate note identity; cannot assign metadata unambiguously.\n") end
    end
  end
  return count
end
r.ClearConsole()
r.ShowConsoleMsg("Notation display-offset diagnosis (read-only)\n")
local total=0
local i=0
while true do
  local take=r.MIDIEditor_EnumTakes(editor,i,true)
  if not take then break end
  total=total+inspect(take,i)
  i=i+1
end
r.ShowConsoleMsg(string.format("Selected notes inspected: %d\n",total))
