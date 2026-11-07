-- Pure Lua musical structure pre-analysis for Native Notation Studio.
-- Read only. Never changes source MIDI or claims the result is a score.
local M = {}
local function finite(n)
 return type(n)=="number" and n==n and math.abs(n)<math.huge
end
local function round(n, places)
 local m=10^(places or 3)
 return math.floor(n*m+0.5)/m
end
local function nearest_error(v, steps)
 return math.abs(v*steps-math.floor(v*steps+0.5))/steps
end
function M.analyze(notes, measure_of)
 assert(type(notes)=="table" and type(measure_of)=="function", "notes and measure_of required")
 local groups,order={},{}
 for _,n in ipairs(notes) do
  assert(finite(n.start_qn) and finite(n.duration_qn) and n.duration_qn>0 and
   finite(n.pitch) and n.pitch>=0 and n.pitch<=127 and n.pitch%1==0,
   "Invalid note in musical analysis")
  local measure,bar_start,bar_end=measure_of(n.start_qn)
  assert(type(measure)=="number" and measure%1==0 and finite(bar_start) and
   finite(bar_end) and bar_end>bar_start and n.start_qn>=bar_start-0.00001 and
   n.start_qn<bar_end+0.00001,"Invalid measure boundaries")
  local take=n.take_id or 1
  assert(type(take)=="number" and take%1==0 and take>0,"Invalid take ID")
  local key=tostring(take)..":"..tostring(measure)
  local group=groups[key]
  if not group then
   group={take_id=take,measure=measure,bar_start=bar_start,bar_end=bar_end,
    notes={},attacks={},pitch_low=127,pitch_high=0}
   groups[key]=group;order[#order+1]=group
  end
  group.notes[#group.notes+1]=n
  if not n.muted then
   group.pitch_low=math.min(group.pitch_low,n.pitch)
   group.pitch_high=math.max(group.pitch_high,n.pitch)
  end
 end
 table.sort(order,function(a,b)
  if a.measure==b.measure then return a.take_id<b.take_id end
  return a.measure<b.measure
 end)
 for _,group in ipairs(order) do
  table.sort(group.notes,function(a,b)
   if a.start_qn==b.start_qn then return a.pitch<b.pitch end
   return a.start_qn<b.start_qn
  end)
  -- A near-simultaneous attack can be arpeggiated; retain exact timing in source.
  local cluster=nil
  for _,n in ipairs(group.notes) do
   if not n.muted then
    if not cluster or n.start_qn-cluster.start_qn>0.06 then
     cluster={start_qn=n.start_qn,pitches={},note_count=0}
     group.attacks[#group.attacks+1]=cluster
    end
    cluster.note_count=cluster.note_count+1
    cluster.pitches[#cluster.pitches+1]=n.pitch
   end
  end
  group.grid_candidates={}
  for _,steps in ipairs({1,2,3,4,6,8}) do
   local total,near=0,0
   for _,attack in ipairs(group.attacks) do
    local error=nearest_error(attack.start_qn-group.bar_start,steps)
    total=total+error
    if error<=0.035 then near=near+1 end
   end
   if #group.attacks>0 then
    group.grid_candidates[#group.grid_candidates+1]={steps_per_qn=steps,
     mean_error_qn=round(total/#group.attacks,5),aligned=near,total=#group.attacks}
   end
  end
  table.sort(group.grid_candidates,function(a,b)
   if a.aligned~=b.aligned then return a.aligned>b.aligned end
   -- Prefer simpler grids at equal coverage; never turn hypotheses into edits.
   if math.abs(a.mean_error_qn-b.mean_error_qn)>0.00001 then
    return a.mean_error_qn<b.mean_error_qn
   end
   return a.steps_per_qn<b.steps_per_qn
  end)
 end
 return order
end
function M.describe(groups)
 local lines={"Taktstruktur (rein diagnostische Hypothesen; keine Quantisierung):"}
 for _,g in ipairs(groups) do
  local attacks={}
  for _,a in ipairs(g.attacks) do
   local pitch=table.concat(a.pitches,",")
   attacks[#attacks+1]=string.format("%.3f:[%s]",a.start_qn-g.bar_start,pitch)
  end
  local candidate=g.grid_candidates[1]
  local grid=candidate and string.format("Rasterhypothese %d/QN (%d/%d Anfaenge nahe Raster)",
   candidate.steps_per_qn,candidate.aligned,candidate.total) or "keine aktiven Anschlaege"
  local register=g.pitch_low<=g.pitch_high and string.format("%d-%d",g.pitch_low,g.pitch_high) or "leer"
  lines[#lines+1]=string.format("Take %d Takt %d (QN %.3f-%.3f): Register %s; Einsaetze %s; %s",
   g.take_id,g.measure,g.bar_start,g.bar_end,register,table.concat(attacks," "),grid)
 end
 return table.concat(lines,"\n")
end
return M
