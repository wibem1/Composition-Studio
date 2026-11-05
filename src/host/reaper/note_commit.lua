-- Restrained KI in-place changes: exactly one result per selected MIDI note.
-- Timing, length, channel, note count, CC, metadata and unselected notes remain unchanged.
local function apply_notation_patch(r)
 local items=workflow_adapter.bindings(r)
 local byGuid,expected,edits,seen={},{},{},{}
 for _,it in ipairs(items) do byGuid[it.guid]=it end
 local total=0
 for _,scope in ipairs(r.notation_selection or {}) do
  if expected[scope.guid] then return nil,"Doppeltes Quell-Item." end
  expected[scope.guid]={}
  for _,ref in ipairs(scope.notes or {}) do
   if expected[scope.guid][ref.index] then return nil,"Doppelte Quellnote." end
   expected[scope.guid][ref.index]=ref
   total=total+1
  end
 end
 if total==0 then return nil,"Keine ausgewählten Noten." end
 for line in (r.payload or ""):gmatch("[^\r\n]+") do
  local guid,index,pitch,velocity=line:match("^CSNOTE|([^|]+)|(%d+)|(%d+)|(%d+)$")
  if not guid then return nil,"KI-Antwort enthält eine unzulässige Zeile." end
  index,pitch,velocity=tonumber(index),tonumber(pitch),tonumber(velocity)
  if not expected[guid] or not expected[guid][index] or
     pitch>127 or velocity<1 or velocity>127 or seen[guid..":"..index] then
   return nil,"KI-Antwort hat fremde/doppelte Noten oder ungültige Werte."
  end
  seen[guid..":"..index]=true
  edits[#edits+1]={guid=guid,index=index,pitch=pitch,velocity=velocity}
 end
 if #edits~=total then return nil,"KI-Antwort ist unvollständig." end
 local byTake,indexByTake={},{}
 for _,change in ipairs(edits) do
  local it=byGuid[change.guid]
  local ref=expected[change.guid][change.index]
  if not it or not it.take or not reaper.TakeIsMIDI(it.take) then return nil,"Quell-Item fehlt." end
  local _,count=reaper.MIDI_CountEvts(it.take)
  if change.index>=(count or 0) then return nil,"Notenindex ist nicht mehr gültig." end
  local ok,sel,mut,s,e,ch,p,v=reaper.MIDI_GetNote(it.take,change.index)
  if not ok or mut or s~=ref.start_ppq or e~=ref.end_ppq or
     ch~=ref.channel or p~=ref.pitch or v~=ref.velocity then
   return nil,"Originalnote verändert. Bitte Auftrag erneut ausführen."
  end
  change.take=it.take;change.sel=sel;change.s=s;change.e=e;change.ch=ch;change.previous=p
  byTake[it.take]=byTake[it.take] or {}
  byTake[it.take][#byTake[it.take]+1]=change
  indexByTake[it.take]=indexByTake[it.take] or {}
  indexByTake[it.take][change.index]=true
 end
 -- No new overlapping same-pitch/same-channel MIDI pairs in modified notes.
 for take,changes in pairs(byTake) do
  local others={}
  local _,count=reaper.MIDI_CountEvts(take)
  for i=0,(count or 0)-1 do
   if not indexByTake[take][i] then
    local ok,_,mut,s,e,ch,p=reaper.MIDI_GetNote(take,i)
    if ok and not mut then others[#others+1]={s=s,e=e,ch=ch,pitch=p} end
   end
  end
  for i,n in ipairs(changes) do
   if n.pitch~=n.previous then
    for _,other in ipairs(others) do
     if n.ch==other.ch and n.pitch==other.pitch and n.s<other.e and other.s<n.e then
      return nil,"Gleichzeitige identische MIDI-Tonhöhen würden kollidieren."
     end
    end
    for j,other in ipairs(changes) do
     if i~=j and n.ch==other.ch and n.pitch==other.pitch and n.s<other.e and other.s<n.e then
      return nil,"Gleichzeitige identische MIDI-Tonhöhen würden kollidieren."
     end
    end
   end
  end
 end
 reaper.Undo_BeginBlock2(0)
 local ok,err=xpcall(function()
  for _,n in ipairs(edits) do
   assert(reaper.MIDI_SetNote(n.take,n.index,n.sel,false,n.s,n.e,n.ch,n.pitch,n.velocity,true)~=false,
    "MIDI_SetNote fehlgeschlagen.")
  end
  for take in pairs(byTake) do reaper.MIDI_Sort(take) end
 end,debug.traceback)
 if not ok then
  reaper.Undo_EndBlock2(0,"Composition Studio – KI-Notenänderung fehlgeschlagen",-1)
  reaper.Undo_DoUndo2(0)
  return nil,err
 end
 reaper.UpdateArrange()
 reaper.Undo_EndBlock2(0,"Composition Studio – markierte Noten KI-Überarbeitung",-1)
 return true
end

-- Approval-only transposition of captured note indices; untouched notes remain intact.
local function apply_notation_transpose(r)
 local shift=tonumber((r.payload or ""):match("^TRANSPOSE_NOTATION|([%+%-]?%d+)$"))
 if not shift or shift~=math.floor(shift) or shift==0 or math.abs(shift)>24 then return nil,"Ungültige Halbton-Transposition." end
 local items=workflow_adapter.bindings(r)
 local lookup={};for _,it in ipairs(items) do lookup[it.guid]=it end
 local edits={}
 for _,scope in ipairs(r.notation_selection or {}) do
  local it=lookup[scope.guid]
  if not it or not it.take or not reaper.TakeIsMIDI(it.take) then return nil,"Quell-Item nicht mehr vorhanden." end
  local _,count=reaper.MIDI_CountEvts(it.take)
  for _,ref in ipairs(scope.notes or {}) do
   if type(ref.index)~="number" or ref.index<0 or ref.index>=(count or 0) then return nil,"Notenindex nicht mehr gültig." end
   local ok,sel,mut,s,e,ch,p,v=reaper.MIDI_GetNote(it.take,ref.index)
   if not ok or mut or s~=ref.start_ppq or e~=ref.end_ppq or ch~=ref.channel or p~=ref.pitch or v~=ref.velocity then
    return nil,"Die markierten Noten wurden verändert. Auftrag neu erstellen."
   end
   if p+shift<0 or p+shift>127 then return nil,"Tonhöhe außerhalb MIDI-Bereich." end
   edits[#edits+1]={take=it.take,index=ref.index,sel=sel,s=s,e=e,ch=ch,p=p+shift,v=v}
  end
 end
 if #edits==0 then return nil,"Keine markierten Noten gesichert." end
 reaper.Undo_BeginBlock2(0)
 local ok,err=xpcall(function()
  local takes={}
  for _,n in ipairs(edits) do
   assert(reaper.MIDI_SetNote(n.take,n.index,n.sel,false,n.s,n.e,n.ch,n.p,n.v,true)~=false,"MIDI_SetNote fehlgeschlagen")
   takes[n.take]=true
  end
  for take in pairs(takes) do reaper.MIDI_Sort(take) end
 end,debug.traceback)
 if not ok then
  reaper.Undo_EndBlock2(0,"Composition Studio – fehlgeschlagene Transposition",-1)
  reaper.Undo_DoUndo2(0)
  return nil,err
 end
 reaper.UpdateArrange()
 reaper.Undo_EndBlock2(0,"Composition Studio – markierte Noten transponieren",-1)
 return true
end

