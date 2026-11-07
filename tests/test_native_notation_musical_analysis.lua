-- Offline, read-only regression for Native-Notation-Musical-Analysis.lua.
local M=dofile('Native-Notation-Musical-Analysis.lua')
local function bar(qn)
 local m=math.floor(qn/4)+1
 return m,(m-1)*4,m*4
end
local groups=M.analyze({
 {take_id=1,start_qn=0,duration_qn=.4,pitch=60},
 {take_id=1,start_qn=.025,duration_qn=.38,pitch=64},
 {take_id=1,start_qn=.5,duration_qn=.48,pitch=67},
 {take_id=2,start_qn=0,duration_qn=1,pitch=48},
 {take_id=1,start_qn=4,duration_qn=.25,pitch=72},
},bar)
assert(#groups==3)
assert(groups[1].measure==1 and groups[1].take_id==1)
assert(#groups[1].attacks==2)
assert(groups[1].attacks[1].note_count==2)
assert(groups[1].notes[2].start_qn==.025)
assert(groups[1].grid_candidates[1].aligned==2)
assert(groups[2].take_id==2)
assert(groups[3].measure==2)
local description=M.describe(groups)
assert(description:find('Take 1 Takt 1',1,true))
assert(description:find('60,64',1,true))
local ok=pcall(M.analyze,{{start_qn=0,duration_qn=-1,pitch=60}},bar)
assert(not ok)
local silent=M.analyze({{start_qn=0,duration_qn=1,pitch=64,muted=true}},bar)
assert(#silent[1].attacks==0)
print('musical analysis: 10 checks passed')
