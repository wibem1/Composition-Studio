local music_model={schema="Composition-Music-1",song_schema="Composition-Song-1",max_source_notes=2500,max_result_notes=20000}
local function music_number(value)
 return type(value)=="number" and value==value and value~=math.huge and value~=-math.huge
end
local function music_list(value,name,limit)
 assert(type(value)=="table",name..": Liste fehlt.")
 local count=0
 for key in pairs(value) do
  assert(type(key)=="number" and key%1==0 and key>=1 and key<=#value,name..": ungültige Liste.")
  count=count+1
 end
 assert(count==#value and count<=limit,name..": technische Größenbegrenzung überschritten.")
 return value
end
function music_model.capture(items,tempo,num,den)
 assert(music_number(tempo) and tempo>=20 and tempo<=400,"Tempo außerhalb des unterstützten JSON-Bereichs (20–400 BPM).")
 assert(music_number(num) and num%1==0 and num>=1 and num<=32 and music_number(den) and den%1==0 and den>=1 and den<=64,"Taktart nicht unterstützt.")
 local snapshot={schema=music_model.schema,representation="performance",tempo=tempo,time_signature={num,den},parts={},note_count=0}
 local parts,seen_items={},{ }; local first,last=math.huge,-math.huge
 for _,item in ipairs(items) do
  assert(type(item.guid)=="string" and item.guid~="","Quell-Item ohne Identität.")
  assert(not seen_items[item.guid],"Doppeltes Quell-Item im Musikkontext.");seen_items[item.guid]=true
  local id=(type(item.track_guid)=="string" and item.track_guid~="" and item.track_guid) or item.guid
  if not parts[id] then
   assert(#snapshot.parts<32,"Mehr als 32 Quellspuren; bitte einen kleineren Bereich auswählen.")
   parts[id]={id=id,name=item.track_name or "Instrument",events={}}
   snapshot.parts[#snapshot.parts+1]=parts[id]
  end
  for ordinal,note in ipairs(item.notes or {}) do
   snapshot.note_count=snapshot.note_count+1
   assert(snapshot.note_count<=music_model.max_source_notes,"Mehr als 2500 Quellnoten; bitte einen kleineren Bereich auswählen.")
   assert(music_number(note.start_qn) and music_number(note.duration_qn) and note.duration_qn>0,"Ungültige Quellzeiten.")
   assert(music_number(note.pitch) and note.pitch%1==0 and note.pitch>=0 and note.pitch<=127,"Ungültige Quelltonhöhe.")
   assert(music_number(note.velocity) and note.velocity%1==0 and note.velocity>=1 and note.velocity<=127,"Ungültige Quellvelocity.")
   assert(music_number(note.channel) and note.channel%1==0 and note.channel>=0 and note.channel<=15,"Ungültiger Quellkanal.")
   local event={id=item.guid..":"..ordinal,source_item=item.guid,source_ordinal=ordinal,
    at=note.start_qn,duration=note.duration_qn,pitch=note.pitch,velocity=note.velocity,channel=note.channel}
   parts[id].events[#parts[id].events+1]=event
   first=math.min(first,event.at); last=math.max(last,event.at+event.duration)
  end
 end
 assert(snapshot.note_count>0,"Keine MIDI-Noten als Ausgangsmaterial vorhanden.")
 snapshot.bounds={start_qn=first,end_qn=last}
 return snapshot
end
function music_model.validate_song(song,snapshot)
 assert(type(snapshot)=="table" and snapshot.schema==music_model.schema,"Gesicherter Musikkontext fehlt.")
 assert(type(song)=="table" and song.schema==music_model.song_schema,"Song-Antwort benötigt Composition-Song-1.")
 assert(music_number(song.bpm) and math.abs(song.bpm-snapshot.tempo)<0.000001,"Der Song darf das Projekttempo nicht ändern.")
 assert(type(song.timeSignature)=="table" and song.timeSignature[1]==snapshot.time_signature[1] and song.timeSignature[2]==snapshot.time_signature[2],"Der Song darf die Projekttaktart nicht ändern.")
 assert(song.tempoEvents==nil or #music_list(song.tempoEvents,"Tempoereignisse",0)==0,"Die vorhandene Tempokarte bleibt erhalten.")
 assert(type(song.title)=="string" and #song.title>0 and #song.title<=120,"Songtitel fehlt oder ist zu lang.")
 local tracks=music_list(song.tracks,"Spuren",32)
 assert(#tracks>0,"Song ohne Spuren.")
 local names,count,last={ },0,0
 for _,track in ipairs(tracks) do
  assert(type(track)=="table" and type(track.name)=="string" and #track.name>0 and #track.name<=120,"Ungültiger Spurname.")
  assert(not track.name:find("[|\r\n]") and track.name==track.name:match("^%s*(.-)%s*$") and not names[track.name],"Spurnamen müssen eindeutig und ohne Steuerzeichen sein.")
  names[track.name]=true
  assert(track.role==nil or type(track.role)=="string" and #track.role<=300,"Ungültige musikalische Rollenbeschreibung.")
  local notes=music_list(track.notes,"Noten",music_model.max_result_notes)
  assert(#notes>0,"Leere Songspuren können nicht übernommen werden; bitte im Ergebnis weglassen.")
  for _,note in ipairs(notes) do
   count=count+1
   assert(count<=music_model.max_result_notes,"Song hat mehr als 20000 Noten.")
   assert(type(note)=="table" and music_number(note[1]) and note[1]>=0 and music_number(note[2]) and note[2]>0,"Ungültige Songzeiten.")
   last=math.max(last,note[1]+note[2])
  end
 end
 assert(count>0,"Song enthält keine Noten.")
 local sections=music_list(song.sections,"Abschnitte",32)
 assert(#sections>0,"Song benötigt mindestens einen beschriebenen Abschnitt.")
 local ids,previous={},0
 for _,section in ipairs(sections) do
  assert(type(section)=="table" and type(section.id)=="string" and #section.id>0 and #section.id<=80 and not ids[section.id],"Abschnittskennungen fehlen oder sind doppelt.")
  assert(type(section.name)=="string" and #section.name>0 and #section.name<=120,"Abschnittsname fehlt.")
  assert(music_number(section.start_qn) and math.abs(section.start_qn-previous)<0.000001 and music_number(section.end_qn) and section.end_qn>section.start_qn and section.end_qn<=4096,"Abschnitte müssen den Song lückenlos ab QN 0 beschreiben (maximal 4096 QN).")
  assert(section.purpose==nil or type(section.purpose)=="string" and #section.purpose<=600,"Ungültige Abschnittsbeschreibung.")
  ids[section.id]=true;previous=section.end_qn
 end
 assert(last<=previous+0.000001,"Songnoten reichen über den beschriebenen Werkumfang hinaus.")
 local pedal=music_list(song.pedalEvents or {},"Pedalereignisse",20000)
 local controls=0
 for _,track in ipairs(tracks) do
  local pedal_at,pedal_value=-1,0
  for _,event in ipairs(pedal) do
   controls=controls+1
   assert(type(event)=="table" and music_number(event.at) and event.at>=0 and event.at<=previous,"Pedalereignis außerhalb des Songumfangs.")
   assert(music_number(event.value) and event.value%1==0 and event.value>=0 and event.value<=127,"Ungültiger Pedalwert.")
   if event.at>=pedal_at then pedal_at=event.at;pedal_value=event.value end
  end
  for _,event in ipairs(music_list(track.ccEvents or {},"Controllerereignisse",20000)) do
   controls=controls+1
   assert(type(event)=="table" and music_number(event.at) and event.at>=0 and event.at<=previous,"Controllerereignis außerhalb des Songumfangs.")
   assert(music_number(event.controller) and event.controller%1==0 and event.controller>=0 and event.controller<=127 and music_number(event.value) and event.value%1==0 and event.value>=0 and event.value<=127,"Ungültiger Controllerwert.")
   if event.controller==64 and event.at>=pedal_at then pedal_at=event.at;pedal_value=event.value end
  end
  assert(controls<=20000,"Zu viele Controllerereignisse im Song.")
  assert(music_number(pedal_value) and pedal_value>=0 and pedal_value<64,"Sustain-Pedal muss innerhalb des Songs wieder gelöst werden.")
  assert(track.pitchBend==nil or #music_list(track.pitchBend,"Pitch Bend",0)==0,"Pitch Bend ist im bestehenden Lua-JSON-Adapter nicht unterstützt.")
 end
 for _,relation in ipairs(music_list(song.relationships or {},"Beziehungen",64)) do
  assert(type(relation)=="table" and ids[relation.from] and ids[relation.to],"Formbeziehung verweist auf unbekannte Abschnitte.")
  assert(type(relation.description)=="string" and #relation.description<=600,"Ungültige Formbeziehung.")
 end
 return song
end
-- BEGIN MODULE EXPORTS
return {music_model=music_model}
