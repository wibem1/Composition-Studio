-- Native Notation Studio: Offline clef choice and safe REAPER SCORE chunk utilities.
-- Extracted from the existing project implementation; no AI, API, or MIDI edits.
local function finite(n) return type(n)=="number" and n==n and math.abs(n)<math.huge end
local function track_clef_chunk(chunk,wanted,force)
 assert(type(chunk)=="string" and #chunk<4*1024*1024,"Track-State fehlt oder ist zu gross.")
 local depth,root,found,current=0,false,nil,0
 local pos=1
 local top,scoreFields,scoreExtra={},nil,""
 while pos<=#chunk do
  local stop=chunk:find("\n",pos,true) or #chunk+1
  local line=chunk:sub(pos,stop-1):gsub("\r$","")
  local text=line:match("^%s*(.-)%s*$")
  if depth==1 then top[#top+1]={first=pos,last=math.min(stop,#chunk),text=text} end
  if depth==1 and text:match("^SCORE%s") then
   assert(not found,"Mehrdeutige SCORE-Zeilen im Track.")
   local prefix,first,gap,clef,rest=line:match("^(%s*SCORE%s+)(%S+)(%s+)(%S+)(.*)$")
   local a,b,extra
   if rest then a,b,extra=rest:match("^%s+(%S+)%s+(%S+)(.*)$") end
   current=tonumber(clef)
   assert(first and tonumber(first) and tonumber(first)%1==0 and current and current%1==0 and current>=0 and current<=12
    and finite(tonumber(a)) and finite(tonumber(b)),"Unbekanntes SCORE-Format.")
   scoreFields={tonumber(first),current,tonumber(a),tonumber(b)};scoreExtra=extra or ""
   found={first=pos+#prefix+#first+#gap,last=pos+#prefix+#first+#gap+#clef-1}
  end
  if text:sub(1,1)=="<" then
   if depth==0 then assert(not root and (text=="<TRACK" or text:match("^<TRACK%s")),"Kein eindeutiger Track-State.");root=true end
   depth=depth+1
  elseif text==">" then depth=depth-1;assert(depth>=0,"Beschaedigter Track-State.")
  elseif depth==0 then assert(text=="","Daten ausserhalb des Track-State.") end
  pos=stop+1
 end
 assert(root and depth==0,"Unvollstaendiger Track-State.")
 local info={top=top,fields=scoreFields or {0,0,0,0},extra=scoreExtra}
 if wanted==nil or (wanted==current and not (force and not found)) then return chunk,current,info end
 assert(wanted%1==0 and wanted>=0 and wanted<=12,"Ungueltiger Schluessel.")
 if found then return chunk:sub(1,found.first-1)..wanted..chunk:sub(found.last+1),current,info end
 local lineEnd=assert(chunk:find("\n",1,true),"Track-Kopf ohne Zeilenende.")
 local nl=chunk:sub(lineEnd-1,lineEnd)=="\r\n" and "\r\n" or "\n"
 return chunk:sub(1,lineEnd).."SCORE 0 "..wanted.." 0 0"..nl..chunk:sub(lineEnd+1),current,info
end
-- REAPER 7.84 moves SCORE into its canonical position and may add the
-- default LANEREC line. Permit only those observed normalizations; compare
-- every SCORE value and all remaining track bytes, including nested chunks.
local function track_equivalent(expected,actual)
 local _,_,a=track_clef_chunk(expected)
 local _,_,b=track_clef_chunk(actual)
 for i=1,4 do if a.fields[i]~=b.fields[i] then return false end end
 if a.extra~=b.extra then return false end
 local function stripped(chunk,info)
  local result,pos={},1
  for _,line in ipairs(info.top) do
   if line.text:match("^SCORE%s") or line.text=="LANEREC -1 -1 -1 0" then
    result[#result+1]=chunk:sub(pos,line.first-1);pos=line.last+1
   end
  end
  result[#result+1]=chunk:sub(pos)
  return table.concat(result)
 end
 return stripped(expected,a)==stripped(actual,b)
end
local steps={0,0,1,1,2,3,3,4,4,5,5,6}
local function diatonic(p) return math.floor(p/12)*7+steps[p%12+1] end
local staff={{37,45},{25,33},{31,39},{29,37}} -- E4/F5, G2/A3, F3/G4, D3/E4
local function choose_clef(notes,current)
 if current>=5 then return current end -- preserve octave/percussion/chart conventions
 local costs={0,0,0,0}
 local active,drums,low,high={},0,127,0
 for _,n in ipairs(notes) do
  if not n.muted then
   if n.channel==9 then drums=drums+1 else
    active[#active+1]=n;low=math.min(low,n.pitch);high=math.max(high,n.pitch)
    local p=diatonic(n.pitch)
    local weight=math.max(0.25,math.min(2,n.duration_qn))
    for clef,range in ipairs(staff) do
     local distance=math.max(range[1]-p,p-range[2],0)
     local ledger=math.floor(distance/2)
     costs[clef]=costs[clef]+weight*ledger*ledger
    end
   end
  end
 end
 if #active==0 then return drums>0 and 10 or current end
 -- Retain an existing piano staff only for clear simultaneous broad chords.
 -- A single line, even with a large range, never creates a piano staff.
 if current==0 and low<55 and high>67 then
  for _,n in ipairs(active) do
   local chord,lo,hi=0,127,0
   for _,other in ipairs(active) do
    if math.abs(n.start_qn-other.start_qn)<0.08 and math.min(n.duration_qn,other.duration_qn)>0.125 then
     chord=chord+1;lo=math.min(lo,other.pitch);hi=math.max(hi,other.pitch)
    end
   end
   if chord>=3 and lo<55 and hi>67 then return 0 end
  end
 end
 local best=costs[2]<costs[1] and 2 or 1
 if current==1 or current==2 then
  if costs[current]<=costs[best]+0.5 then return current end
 elseif current==3 or current==4 then
  if costs[current]<=costs[best]*1.1+0.5 then return current end
 end
 return best
end

return {track_clef_chunk=track_clef_chunk,track_equivalent=track_equivalent,choose_clef=choose_clef}
