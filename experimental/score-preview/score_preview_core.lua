-- Notation Studio: independent read-only score preview model (2026).
local M = {}
local EPS=1e-8
-- Pitch class spelling in G minor (2 flats): C C# D Eb E F F# G G# A Bb B.
local pc_step={0,0,1,2,2,3,3,4,4,5,6,6}
local pc_alter={0,1,0,-1,0,0,1,0,1,0,-1,0}
local pc_acc={"","#","","b","","","#","","#","","b",""}
function M.spell(p)
  local pc=p%12
  local octave=math.floor(p/12)-1
  local step=pc_step[pc+1]
  return (octave*7+step),pc_acc[pc+1]
end
-- Return only the accidentals that must be printed. G minor has Bb and Eb
-- in the key signature; local alterations are tracked within each measure.
-- The state key includes octave so repeated tones share the same accidental.
function M.notated_accidental(pitch, measure_state)
  local step=M.spell(pitch)
  local letter=step%7
  local base=(letter==2 or letter==6) and -1 or 0
  local alter=pc_alter[pitch%12+1]
  local old=measure_state[step]
  if old==nil then old=base end
  if old==alter then return nil end
  measure_state[step]=alter
  if alter==1 then return "#" end
  if alter==-1 then return "b" end
  return "n"
end

-- Display-only chord grouping by the quantized rhythmic onset. Different
-- original lengths stay attached to their note records; no MIDI is modified.
function M.group_onsets(notes)
  local groups,previous={},nil
  for _,n in ipairs(notes) do
    if previous==nil or math.abs(previous-n.start)>EPS then
      groups[#groups+1]={start=n.start,notes={}}
      previous=n.start
    end
    groups[#groups].notes[#groups[#groups].notes+1]=n
  end
  return groups
end
function M.round(value, grid)
  if not grid or grid<=0 then return value end
  return math.floor(value/grid+0.5)*grid
end
function M.duration(value)
  if not value or value<=0 then return 0.25 end
  local candidates={0.125,0.1875,0.25,0.375,0.5,0.75,1,1.5,2,3,4}
  local best,dist=candidates[1],math.huge
  for _,v in ipairs(candidates) do
    local d=math.abs(value-v)
    if d<dist then best,dist=v,d end
  end
  return best
end
function M.build(items,opts)
  opts=opts or {}
  local num=opts.num or 4
  local den=opts.den or 4
  assert(num>=1 and den>=1,'invalid meter')
  local bar=num*4/den
  local qstart=math.huge
  for _,item in ipairs(items or {}) do qstart=math.min(qstart,item.start_qn or 0) end
  if qstart==math.huge then qstart=0 end
  local tracks={}
  local longest=0
  for i,item in ipairs(items or {}) do
    local notes={}
    local max_end=0
    for _,n in ipairs(item.notes or {}) do
      local start=(n.start_qn or 0)-qstart
      local dur=(n.end_qn or 0)-(n.start_qn or 0)
      if dur>0 then
        local display_start=M.round(start,opts.grid or 0.25)
        local display_duration=M.duration(dur)
        notes[#notes+1]={pitch=n.pitch,channel=n.channel or 0,original_start=start,
          original_duration=dur,start=math.max(0,display_start),duration=display_duration}
        max_end=math.max(max_end,start+dur)
      end
    end
    table.sort(notes,function(a,b)
      if a.start~=b.start then return a.start<b.start end
      return a.pitch<b.pitch
    end)
    local clef=(item.clef or ((i==1) and 'treble' or 'bass'))
    tracks[#tracks+1]={name=item.name or ('Spur '..i),clef=clef,notes=notes}
    longest=math.max(longest,max_end)
  end
  return {tracks=tracks,start_qn=qstart,bar=bar,num=num,den=den,
    bars=math.max(1,math.ceil((longest-EPS)/bar)),grid=opts.grid or 0.25,
    original_events=(function() local n=0 for _,x in ipairs(items or {}) do n=n+#(x.notes or {}) end return n end)()}
end
function M.bar_notes(track,bar_index,bar_length)
  local out={}
  local bs=bar_index*bar_length
  local be=bs+bar_length
  for _,n in ipairs(track.notes) do
    if n.start>=bs-EPS and n.start<be-EPS then out[#out+1]=n end
  end
  return out
end
return M
