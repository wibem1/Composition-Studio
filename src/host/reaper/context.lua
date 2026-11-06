local function item_guid(item) local ok,g=reaper.GetSetMediaItemInfo_String(item,"GUID","",false); return ok and g or "" end
local function track_guid(track) return reaper.GetTrackGUID(track) or "" end
local function selected_tracks() local a={}; for i=0,reaper.CountSelectedTracks(0)-1 do local tr=reaper.GetSelectedTrack(0,i); local _,n=reaper.GetTrackName(tr); a[#a+1]={track=tr,guid=track_guid(tr),name=n~="" and n or "Unbenannte Spur",index=math.floor(reaper.GetMediaTrackInfo_Value(tr,"IP_TRACKNUMBER"))} end; return a end
-- MIDIEditor_GetActive returns the FOCUSED MIDI editor. Cache that handle
-- during the deferred UI loop, before Composition Studio takes keyboard focus.
-- Revalidate its active take before using the previously focused editor.
local last_notation_editor=nil
local function focused_or_last_notation_editor()
 local focused=reaper.MIDIEditor_GetActive and reaper.MIDIEditor_GetActive()
 if focused then
  last_notation_editor=focused
  return focused
 end
 if not last_notation_editor or not reaper.MIDIEditor_GetTake then return nil end
 local ok,take=pcall(reaper.MIDIEditor_GetTake,last_notation_editor)
 if ok and take and (not reaper.ValidatePtr2 or reaper.ValidatePtr2(0,take,"MediaItem_Take*")) then
  return last_notation_editor
 end
 last_notation_editor=nil
 return nil
end

-- REAPER notation and piano roll expose the same selected MIDI notes.
-- Use only editable takes; read-only and never touch unselected notes.
local function notation_selection_items(with_notes)
 local ed=focused_or_last_notation_editor()
 if not ed then return {},0 end
 local takes={}
 if reaper.MIDIEditor_EnumTakes then
  for i=0,2047 do local tk=reaper.MIDIEditor_EnumTakes(ed,i,true); if not tk then break end; takes[#takes+1]=tk end
 else local tk=reaper.MIDIEditor_GetTake(ed); if tk then takes[1]=tk end end
 local rows,found,count={},{},0
 for _,tk in ipairs(takes) do
  if reaper.TakeIsMIDI(tk) and (not reaper.ValidatePtr2 or reaper.ValidatePtr2(0,tk,"MediaItem_Take*")) then
   local item=reaper.GetMediaItemTake_Item(tk)
   local track=item and reaper.GetMediaItem_Track(item)
   if track then
    -- Native enumeration avoids scanning every MIDI note on each Studio UI frame.
    local nextIndex=-1
    local _,fallbackCount
    if not reaper.MIDI_EnumSelNotes then _,fallbackCount=reaper.MIDI_CountEvts(tk) end
    while true do
     local i
     if reaper.MIDI_EnumSelNotes then
      i=reaper.MIDI_EnumSelNotes(tk,nextIndex)
      if not i or i<0 then break end
     else
      i=nextIndex+1
      if i>=(fallbackCount or 0) then break end
     end
     nextIndex=i
     local ok,sel,mut,s,e,ch,p,v=reaper.MIDI_GetNote(tk,i)
     if ok and sel and not mut then
      local guid=item_guid(item)
      local row=found[guid]
      if not row then
       local _,tn=reaper.GetTrackName(track)
       local _,kn=reaper.GetSetMediaItemTakeInfo_String(tk,"P_NAME","",false)
       local pos=reaper.GetMediaItemInfo_Value(item,"D_POSITION")
       local len=reaper.GetMediaItemInfo_Value(item,"D_LENGTH")
       row={item=item,take=tk,track=track,guid=guid,track_guid=track_guid(track),
        track_name=tn~="" and tn or "Unbenannte Spur",take_name=kn~="" and kn or "Unbenanntes MIDI-Item",
        start_qn=reaper.TimeMap2_timeToQN(0,pos),end_qn=reaper.TimeMap2_timeToQN(0,pos+len),
        notes={},selection_source={}}
       rows[#rows+1]=row;found[guid]=row
      end
      if with_notes then
       local sq=reaper.TimeMap2_timeToQN(0,reaper.MIDI_GetProjTimeFromPPQPos(tk,s))
       local eq=reaper.TimeMap2_timeToQN(0,reaper.MIDI_GetProjTimeFromPPQPos(tk,e))
       row.notes[#row.notes+1]={start_qn=sq,duration_qn=eq-sq,pitch=p,velocity=v,channel=ch}
      end
      row.selection_source[#row.selection_source+1]={index=i,start_ppq=s,end_ppq=e,channel=ch,pitch=p,velocity=v}
      count=count+1
     end
    end
   end
  end
 end
 return rows,count
end

-- Score workspace: all VISIBLE MIDI takes are context, not an edit selection.
-- Unlike notation_selection_items(), this does not authorize in-place writes.
local function notation_visible_items(with_notes)
 local ed=focused_or_last_notation_editor()
 if not ed then return nil,"Kein geöffneter REAPER-MIDI-Editor für die Partitur gefunden." end
 local takes={}
 if reaper.MIDIEditor_EnumTakes then
  for i=0,2047 do
   local tk=reaper.MIDIEditor_EnumTakes(ed,i,false)
   if not tk then break end
   takes[#takes+1]=tk
  end
 else
  local tk=reaper.MIDIEditor_GetTake(ed)
  if tk then takes[1]=tk end
 end
 local result,seen,events={},{},0
 for _,tk in ipairs(takes) do
  if reaper.TakeIsMIDI(tk) and (not reaper.ValidatePtr2 or reaper.ValidatePtr2(0,tk,"MediaItem_Take*")) then
   local item=reaper.GetMediaItemTake_Item(tk)
   local track=item and reaper.GetMediaItem_Track(item)
   if track then
    local guid=item_guid(item)
    if guid=="" then return nil,"Ein sichtbares MIDI-Item hat keine gültige GUID." end
    if not seen[guid] then
     seen[guid]=true
     local _,tn=reaper.GetTrackName(track)
     local _,kn=reaper.GetSetMediaItemTakeInfo_String(tk,"P_NAME","",false)
     local pos=reaper.GetMediaItemInfo_Value(item,"D_POSITION")
     local len=reaper.GetMediaItemInfo_Value(item,"D_LENGTH")
     local row={item=item,take=tk,track=track,guid=guid,track_guid=track_guid(track),
      track_name=tn~="" and tn or "Unbenannte Spur",take_name=kn~="" and kn or "Unbenanntes MIDI-Item",
      start_qn=reaper.TimeMap2_timeToQN(0,pos),end_qn=reaper.TimeMap2_timeToQN(0,pos+len),
      notes={},score_context=true}
     if with_notes then
      local ok,nc=reaper.MIDI_CountEvts(tk)
      if not ok then return nil,"MIDI-Noten der sichtbaren Partitur konnten nicht gelesen werden." end
      events=events+(nc or 0)
      -- Fail closed instead of silently truncating musical context or
      -- sending unbounded amounts of music to a paid AI provider.
      if events>2500 then return nil,"Sichtbare Partitur umfasst mehr als 2500 MIDI-Noten. Bitte einen kleineren Bereich auswählen." end
      for n=0,(nc or 0)-1 do
       local valid,_,muted,s,e,ch,p,v=reaper.MIDI_GetNote(tk,n)
       if valid and not muted then
        local sq=reaper.TimeMap2_timeToQN(0,reaper.MIDI_GetProjTimeFromPPQPos(tk,s))
        local eq=reaper.TimeMap2_timeToQN(0,reaper.MIDI_GetProjTimeFromPPQPos(tk,e))
        row.notes[#row.notes+1]={start_qn=sq,duration_qn=eq-sq,pitch=p,velocity=v,channel=ch}
       end
      end
     end
     result[#result+1]=row
    end
   end
  end
 end
 if #result==0 then return nil,"Keine sichtbaren MIDI-Items im Noteneditor gefunden." end
 return result,nil
end

-- A selected phrase is the ONLY edit target. Nearby visible voices, in
-- notation OR piano roll, are separate READ-ONLY harmonic/contrapuntal context.
-- Bound the excerpt before calling any paid AI model.
local function editor_reference_excerpt(selection)
 local first,last=math.huge,-math.huge
 for _,it in ipairs(selection or {}) do
  for _,n in ipairs(it.notes or {}) do
   local start=n.start_qn or 0
   first=math.min(first,start)
   last=math.max(last,start+(n.duration_qn or 0))
  end
 end
 if first==math.huge then return "" end
 local visible,problem=notation_visible_items(true)
 if not visible then
  return "REFERENZSTIMMEN: nicht verfügbar ("..tostring(problem).."); keine Annahmen über ungehörte Stimmen."
 end
 local lo,hi=first-2,last+2
 local lines={
  "REFERENZSTIMMEN NUR ZUR HARMONISCHEN/KONTRAPUNKTISCHEN ORIENTIERUNG;",
  "diese Töne sind NICHT zur Bearbeitung freigegeben. Originale außer der expliziten Notenauswahl nicht verändern.",
  string.format("REFERENZFENSTER QN %.4f..%.4f",lo,hi),
 }
 local total,limit=0,160
 for _,it in ipairs(visible) do
  local entries={}
  for _,n in ipairs(it.notes or {}) do
   local st=n.start_qn or 0
   local ending=st+(n.duration_qn or 0)
   if st<hi and ending>lo then
    total=total+1
    if total<=limit then
     entries[#entries+1]=string.format("REF %.5f %.5f %d %d %d",
      st,n.duration_qn or 0,n.pitch or 0,n.velocity or 0,n.channel or 0)
    end
   end
  end
  if #entries>0 then
   lines[#lines+1]="REFERENZSPUR "..tostring(it.track_name).." item="..tostring(it.guid)
   for _,line in ipairs(entries) do lines[#lines+1]=line end
  end
 end
 if total>limit then
  lines[#lines+1]="REFERENZDATEN gekürzt auf "..limit.." von "..total..
    " Noten; die vollständige Begleitung ist nicht enthalten."
 end
 if total==0 then lines[#lines+1]="Keine weiteren Noten innerhalb des Referenzfensters." end
 return table.concat(lines,"\n")
end

local function score_request_intent(lower)
 lower=lower or ""
 return lower:find("partitur",1,true) or lower:find("notenansicht",1,true)
  or lower:find("notensicht",1,true) or lower:find("noteneditor",1,true)
  or lower:find("pianoroll",1,true) or lower:find("piano-roll",1,true)
  or lower:find("piano roll",1,true) or lower:find("midi-editor",1,true)
  or lower:find("midi editor",1,true) or lower:find("sichtbaren noten",1,true)
  or lower:find("angezeigten noten",1,true)
end

local function score_context_tracks(items)
 local out,seen={},{}
 for _,it in ipairs(items or {}) do
  if it.track and not seen[it.track_guid] then
   seen[it.track_guid]=true
   out[#out+1]={track=it.track,guid=it.track_guid,name=it.track_name,
    index=math.floor(reaper.GetMediaTrackInfo_Value(it.track,"IP_TRACKNUMBER"))}
  end
 end
 return out
end

local function selected_items(with_notes,scope) if scope~="items" then local rows,n=notation_selection_items(with_notes); if n>0 then return rows end end; local a={}; for i=0,reaper.CountSelectedMediaItems(0)-1 do local item=reaper.GetSelectedMediaItem(0,i); local take=item and reaper.GetActiveTake(item); if take and reaper.TakeIsMIDI(take) then local tr=reaper.GetMediaItem_Track(item); local _,tn=reaper.GetTrackName(tr); local _,kn=reaper.GetSetMediaItemTakeInfo_String(take,"P_NAME","",false); local pos=reaper.GetMediaItemInfo_Value(item,"D_POSITION"); local len=reaper.GetMediaItemInfo_Value(item,"D_LENGTH"); local it={item=item,take=take,track=tr,guid=item_guid(item),track_guid=track_guid(tr),track_name=tn~="" and tn or "Unbenannte Spur",take_name=kn~="" and kn or "Unbenanntes MIDI-Item",start_qn=reaper.TimeMap2_timeToQN(0,pos),end_qn=reaper.TimeMap2_timeToQN(0,pos+len),notes={}}; if with_notes then local _,ncount=reaper.MIDI_CountEvts(take); for n=0,(ncount or 0)-1 do local ok,_,muted,s,e,ch,p,v=reaper.MIDI_GetNote(take,n); if ok and not muted then local st=reaper.MIDI_GetProjTimeFromPPQPos(take,s); local et=reaper.MIDI_GetProjTimeFromPPQPos(take,e); local sq=reaper.TimeMap2_timeToQN(0,st); local eq=reaper.TimeMap2_timeToQN(0,et); it.notes[#it.notes+1]={start_qn=sq,duration_qn=eq-sq,pitch=p,velocity=v,channel=ch} end end end; a[#a+1]=it end end; return a end

local function track_context_items(tracks) local a={}; local seen={}; for _,t in ipairs(tracks) do for i=0,reaper.CountTrackMediaItems(t.track)-1 do local item=reaper.GetTrackMediaItem(t.track,i); local take=item and reaper.GetActiveTake(item); if take and reaper.TakeIsMIDI(take) then local g=item_guid(item); if not seen[g] then seen[g]=true; local _,kn=reaper.GetSetMediaItemTakeInfo_String(take,"P_NAME","",false); local pos=reaper.GetMediaItemInfo_Value(item,"D_POSITION"); local len=reaper.GetMediaItemInfo_Value(item,"D_LENGTH"); local it={item=item,take=take,track=t.track,guid=g,track_guid=t.guid,track_name=t.name,take_name=kn~="" and kn or "Unbenanntes MIDI-Item",start_qn=reaper.TimeMap2_timeToQN(0,pos),end_qn=reaper.TimeMap2_timeToQN(0,pos+len),notes={}}; local _,nc=reaper.MIDI_CountEvts(take); for n=0,(nc or 0)-1 do local ok,_,muted,s,e,ch,p,v=reaper.MIDI_GetNote(take,n); if ok and not muted then local st=reaper.MIDI_GetProjTimeFromPPQPos(take,s); local et=reaper.MIDI_GetProjTimeFromPPQPos(take,e); local sq=reaper.TimeMap2_timeToQN(0,st); local eq=reaper.TimeMap2_timeToQN(0,et); it.notes[#it.notes+1]={start_qn=sq,duration_qn=eq-sq,pitch=p,velocity=v,channel=ch} end end; a[#a+1]=it end end end end; return a end
local function time_selection_context() local s,e=reaper.GetSet_LoopTimeRange(false,false,0,0,false); if not s or not e or e<=s then return "TIME_SELECTION none" end; local sq=reaper.TimeMap2_timeToQN(0,s); local eq=reaper.TimeMap2_timeToQN(0,e); local _,sm,sb=reaper.TimeMap2_timeToBeats(0,s); local _,em,eb=reaper.TimeMap2_timeToBeats(0,e); return string.format("TIME_SELECTION startQN=%.3f endQN=%.3f startBar=%d startBeat=%.3f endBar=%d endBeat=%.3f",sq,eq,(sm or 0)+1,(sb or 0)+1,(em or 0)+1,(eb or 0)+1) end
local function compact_context(items,tracks,ignore_time) tracks=tracks or selected_tracks(); local l={string.format("Tempo %.2f BPM; selected MIDI items=%d; selected tracks=%d",reaper.Master_GetTempo(),#items,#tracks)}; l[#l+1]=ignore_time and "TIME_SELECTION ignored for free new composition" or time_selection_context(); for i,t in ipairs(tracks) do l[#l+1]=string.format("TRACK %d id=%s name=%s index=%d",i,t.guid,t.name,t.index) end; for i,it in ipairs(items) do l[#l+1]=string.format("ITEM %d id=%s trackId=%s track=%s take=%s rangeQN=%.3f..%.3f",i,it.guid,it.track_guid,it.track_name,it.take_name,it.start_qn,it.end_qn); if it.selection_source then l[#l+1]="NOTATION_SELECTION: "..#it.selection_source.." selected notes" end; if it.score_context then l[#l+1]="SCORE_CONTEXT: sichtbares MIDI-Item; musikalischer Kontext, keine Freigabe zum direkten Überschreiben" end end; return table.concat(l,"\n") end
local function music_context(items,tracks,ignore_time) -- BEGIN COMPACT MUSIC INPUT
 local scoped=false;for _,it in ipairs(items) do if it.score_context or #(it.selection_source or {})>0 then scoped=true end end
 if not scoped then return compact_context(items,tracks,ignore_time).."\n"..music_model.compact.input(items) end
-- END COMPACT MUSIC INPUT
local l={compact_context(items,tracks,ignore_time)}; for _,it in ipairs(items) do if it.selection_source then l[#l+1]="NOTATION_SELECTION "..it.guid.." count="..#it.selection_source..". Only selected notes are the edit context; keep unselected notes unchanged." end end; for _,it in ipairs(items) do for _,n in ipairs(it.notes) do l[#l+1]=string.format("N %s %.5f %.5f %d %d %d",it.guid,n.start_qn,n.duration_qn,n.pitch,n.velocity,n.channel) end end; return table.concat(l,"\n") end
local function recent_dialog() local l={}; for i=math.max(1,#history-7),#history do l[#l+1]=history[i].role..": "..history[i].text end; return table.concat(l,"\n") end

