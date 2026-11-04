-- Run from repository root: lua tests/test_semnotes.lua
-- Extract the exact production parser without executing the REAPER GUI.
local file=assert(io.open("Composition Studio.lua","rb"))
local source=file:read("*a");file:close()
local begin=assert(source:find("local function parse_semnotes(",1,true))
local finish=assert(source:find("local function analysis_prompt(",begin,true))
local chunk=source:sub(begin,finish-1).."\nreturn parse_semnotes"
local parser=assert(load(chunk,"semantic-parser","t",_ENV))()
local note={start_qn=0.125,duration_qn=0.5,pitch=69,velocity=90,channel=1}
local items={{guid="{TEST}",notes={note}}}
local function row(pitch,confidence,start)
 return table.concat({"SEMNOTE","{TEST}",start or "0.125000000","0.500000000",pitch or "69","90","1","Melodie","Achtelnote",confidence or "BESTAETIGT","Motivische Evidenz"},"|")
end
local function check(label,reply,notes,invalid,context)
 local good,bad=parser(reply,context or items)
 assert(#good==notes and #bad==invalid,label..": accepted="..#good.." rejected="..#bad)
 print("PASS "..label)
end
check("valid",row(),1,0)
check("duplicate",row().."\n"..row(),1,1)
check("wrong pitch",row("70"),0,1)
check("uncertain",row(nil,"UNSICHER"),1,0)
check("invalid numeric",row(nil,nil,"nan"),0,1)
check("ambiguous original",row(),0,1,{{guid="{TEST}",notes={note,note}}})
check("missing reason",row():gsub("Motivische Evidenz",""),0,1)
check("missing confidence",row(nil,""),0,1)
print("All semantic parser tests passed")
