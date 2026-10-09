local file=assert(io.open("Composition Studio.lua","rb"))
local source=file:read("*a");file:close()
local a=assert(source:find("-- Cross-platform Lua adapter",1,true))
local b=assert(source:find("local function lily_composition_prompt(request)",a,true))
local chunk=source:sub(a,b-1)
local compile,err=load(chunk.."\nreturn engine_translate_json","json-adapter")
assert(compile,err)
local translate=compile()
local good='{"title":"Probe","bpm":120,"timeSignature":[4,4],"tracks":[{"name":"Piano","program":0,"channel":0,"notes":[[0,1,60,90],[1,0.5,64,70]]}]}'
local output,problem=translate(good)
assert(output,problem)
assert(output:find("CSMETA|tempo|0|120",1,true))
assert(output:find("CS|new|-|Piano|0|",1,true))
assert(output:find("0.000000,1.000000,60,90,0",1,true))
assert(not translate('{"bpm":120,"tracks":['))
assert(not translate('{"bpm":120,"tracks":[{"notes":[[0,-1,60,80]]}]}'))
assert(not translate('{"bpm":120,"tracks":[{"notes":[[0,1,155,80]]}]}'))

-- Cost regression: a new user request must start with an empty per-order
-- counter even when the controller is bypassed for JSON composition.
local submit=assert(source:match("local function submit%(%)(.-)end\nlocal function wrap_text"))
assert(submit:find("costs.begin()",1,true),"Direct JSON composition must reset order costs")

-- Verify the experimental two-call workflow is connected to both new-composition entry paths.
assert(source:find('launch("engine_concept",p,key,data)',1,true))
assert(source:find('if stage=="engine_concept" then',1,true))
assert(source:find('launch("engine_json",prompt,key,data)',1,true))
assert(source:find('diag_set("concept_result",text)',1,true))
assert(source:find('launch_new_json(data.request,key,data)',1,true))
assert(source:find('launch_new_json(request,key,{request=request',1,true))
assert(source:find('composition_mode=="direct"',1,true))
print("Native Lua JSON adapter, cost reset and two-step composition wiring checks passed")
