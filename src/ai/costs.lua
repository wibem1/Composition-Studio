-- Local token-cost estimates, never provider invoices. Rates checked 2026-10-09.
local costs={}
do
 local function fields(raw)
  raw=trim(raw); local out={}
  if raw:sub(1,1)~="{" or raw:sub(-1)~="}" then return out end
  local i=2
  while i<#raw do
   while raw:sub(i,i):match("[%s,]") do i=i+1 end
   if raw:sub(i,i)~='"' then break end
   local key=read_json_string(raw,i); i=i+1
   while i<=#raw do local c=raw:sub(i,i); if c=="\\" then i=i+2 elseif c=='"' then i=i+1; break else i=i+1 end end
   while raw:sub(i,i):match("%s") do i=i+1 end
   if raw:sub(i,i)~=":" then break end
   i=i+1; while raw:sub(i,i):match("%s") do i=i+1 end
   local first,depth,quoted=i,0,false
   while i<=#raw do
    local c=raw:sub(i,i)
    if quoted then if c=="\\" then i=i+1 elseif c=='"' then quoted=false end
    elseif c=='"' then quoted=true
    elseif c=="{" or c=="[" then depth=depth+1
    elseif c=="}" or c=="]" then if depth==0 then break end; depth=depth-1
    elseif c=="," and depth==0 then break end
    i=i+1
   end
   if quoted or depth~=0 then return {} end
   out[key]=trim(raw:sub(first,i-1))
   if raw:sub(i,i)=="}" then break end
  end
  return out
 end
 function costs.usage(pv,raw)
  local top=fields(raw); local u=fields(top[pv=="google" and "usageMetadata" or "usage"])
  local bad=false
  local function count(obj,key,required)
   local v=obj[key]
   if (not v or v=="null") and not required then return 0 end
   local n=v and v:match("^%d+$") and tonumber(v)
   if not n or n>9007199254740991 then bad=true; return 0 end
   return n
  end
  local n={input=0,output=0,cached=0,write5=0,write1=0}
  if pv=="google" then
   n.input=count(u,"promptTokenCount",true)
   n.output=count(u,"candidatesTokenCount",true)+count(u,"thoughtsTokenCount")
   n.cached=count(u,"cachedContentTokenCount")
  else
   n.input=count(u,"input_tokens",true); n.output=count(u,"output_tokens",true)
   if pv=="openai" then
    local details=fields(u.input_tokens_details)
    n.cached=count(details,"cached_tokens"); n.write5=count(details,"cache_write_tokens")
   elseif pv=="anthropic" then
    n.cached=count(u,"cache_read_input_tokens")
    local writes=count(u,"cache_creation_input_tokens")
    local cache=fields(u.cache_creation)
    n.write1=count(cache,"ephemeral_1h_input_tokens")
    n.write5=cache.ephemeral_5m_input_tokens and count(cache,"ephemeral_5m_input_tokens") or writes-n.write1
    if n.write5+n.write1~=writes then bad=true end
    n.input=n.input+n.cached+writes
   else bad=true end
  end
  if n.cached+n.write5+n.write1>n.input or n.write5<0 then bad=true end
  return not bad and n or nil
 end
 -- input, output, cached reads, 5m writes, 1h writes; USD per million tokens.
 local rates={
  ["openai/gpt-5.6-sol"]={4,20,0.4,5,5,limit=272000,expires="2026-11-21"},
  ["openai/gpt-5.6-terra"]={2,12,0.2,2.5,2.5,limit=272000},
  ["openai/gpt-5.6-luna"]={0.2,1.2,0.02,0.25,0.25,limit=272000},
  ["anthropic/claude-fable-5"]={10,50,1,12.5,20},
  ["anthropic/claude-sonnet-5"]={2,10,0.2,2.5,4},
  ["anthropic/claude-opus-5"]={5,25,0.5,6.25,10},
  ["google/gemini-4-argon"]={2,10,0.1,0,0,expires="2026-11-30"},
  ["google/gemini-3.8-flash"]={0.75,3.75,0.075,0,0,expires="2026-12-31"},
 }
 local function rate_values(raw)
  if type(raw)~="string" or select(2,raw:gsub(",",""))~=4 then return nil end
  local a={}
  for v in (raw or ""):gmatch("[^,]+") do
   local n=tonumber((trim(v))); if not n or n<0 or n==math.huge or n~=n then return nil end
   a[#a+1]=n
  end
  return #a==5 and a or nil
 end
 function costs.rate(pv,id)
  local custom=rate_values(reaper.GetExtState(EXT_SECTION,"CostRateV1:"..pv.."/"..id))
  if custom then return custom end
  local r=rates[pv.."/"..id]
  if not r or r.expires and os.date("%Y-%m-%d")>r.expires then
   if pv=="google" and id=="gemini-4-argon" then return {4,20,0.2,0,0} end
   if pv=="google" and id=="gemini-3.8-flash" then return {1.5,7.5,0.15,0,0} end
   return nil
  end
  return r
 end
 function costs.price(n,r)
  if not n or not r then return nil end
  local scale=r.limit and n.input>r.limit and 2 or 1
  return ((n.input-n.cached-n.write5-n.write1)*r[1]*scale+n.cached*r[3]*scale+
   n.write5*r[4]*scale+n.write1*r[5]*scale+n.output*r[2]*(scale==2 and 1.5 or 1))/1000000
 end
 local keys={"calls","input","output","usd","unknown"}
 local function summary(raw)
  local a=rate_values(raw)
  return {calls=a and a[1] or 0,input=a and a[2] or 0,output=a and a[3] or 0,usd=a and a[4] or 0,unknown=a and a[5] or 0}
 end
 costs.total=summary(reaper.GetExtState(EXT_SECTION,"CostTotalV1"))
 costs.order=summary(reaper.GetExtState(EXT_SECTION,"CostOrderV1"))
 costs.since=reaper.GetExtState(EXT_SECTION,"CostSinceV1")
 if costs.since=="" then costs.since=os.date("%Y-%m-%d"); reaper.SetExtState(EXT_SECTION,"CostSinceV1",costs.since,true) end
 local function persist()
  for key,s in pairs({CostTotalV1=costs.total,CostOrderV1=costs.order}) do
   local values={}; for _,k in ipairs(keys) do values[#values+1]=string.format("%.12g",s[k]) end
   reaper.SetExtState(EXT_SECTION,key,table.concat(values,","),true)
  end
 end
 function costs.begin() costs.order=summary(""); persist() end
 local function clear_call_diagnostics()
  for _,field in ipairs({"usage_input_tokens","usage_output_tokens","usage_cached_tokens","usage_cache_write_5m_tokens","usage_cache_write_1h_tokens","usage_reasoning_tokens","usage_estimated_usd"}) do diag_set(field,"") end
 end
 function costs.start(a)
  clear_call_diagnostics()
  diag_set("usage_cost_status","Aufruf läuft; Verbrauch noch nicht bekannt")
  a.cost_order=costs.order; a.cost_rate=costs.rate(a.provider,a.model)
  for _,s in ipairs({costs.total,a.cost_order}) do s.calls=s.calls+1; s.unknown=s.unknown+1 end
  persist()
 end
 function costs.record(a,raw)
  if a.cost_recorded then return end; a.cost_recorded=true
  local n=costs.usage(a.provider,raw); local usd=costs.price(n,a.cost_rate)
  clear_call_diagnostics()
  -- Diagnose shows real provider usage, not an estimate from response length.
  -- Anthropic reports thinking within output_tokens, not as a separate usage field.
  if n then
   diag_set("usage_input_tokens",tostring(n.input))
   diag_set("usage_output_tokens",tostring(n.output))
   diag_set("usage_cached_tokens",tostring(n.cached))
   diag_set("usage_cache_write_5m_tokens",tostring(n.write5))
   diag_set("usage_cache_write_1h_tokens",tostring(n.write1))
   diag_set("usage_reasoning_tokens",a.provider=="anthropic" and "nicht separat ausgewiesen (in Ausgabe enthalten)" or "nicht separat ausgewiesen")
  else
   diag_set("usage_cost_status","Verbrauchsdaten fehlen oder sind ungültig")
  end
  if usd then
   diag_set("usage_estimated_usd",string.format("%.6f",usd))
   diag_set("usage_cost_status","USD-Schätzung aus API-Verbrauch und hinterlegtem Tarif")
  elseif n then
   diag_set("usage_cost_status","Verbrauch bekannt, aber kein gültiger Preis hinterlegt")
  end
  for _,s in ipairs({costs.total,a.cost_order}) do
   if n then s.input=s.input+n.input; s.output=s.output+n.output end
   if usd then s.usd=s.usd+usd; s.unknown=math.max(0,s.unknown-1) end
  end
  persist()
 end
 function costs.text(s)
  return string.format("~ %.4f USD · %d Aufrufe · %d ein / %d aus",s.usd,s.calls,s.input,s.output)..
   (s.unknown>0 and (" · "..s.unknown.." ohne vollständige Kostenangabe") or "")
 end
 function costs.amount(s)
  return string.format("~ %.4f USD · %d Aufrufe",s.usd,s.calls)..(s.unknown>0 and " · unvollständig" or "")
 end
 function costs.edit_rate()
  if busy then update_status="Preise bitte nach Abschluss des Auftrags ändern."; return end
  local r=costs.rate(provider,model); local values={}
  for i=1,5 do values[i]=r and tostring(r[i]) or "" end
  local ok,raw=reaper.GetUserInputs("Kosten – "..model.." (USD je 1 Mio. Token)",5,
   "Eingabe:,Ausgabe inkl. Denken:,Cache lesen:,Cache schreiben 5m:,Cache schreiben 1h:,extrawidth=250",table.concat(values,","))
  if not ok then return end
  if not rate_values(raw) then update_status="Preise nicht gespeichert: fünf nichtnegative Zahlen mit Dezimalpunkt eingeben."; return end
  reaper.SetExtState(EXT_SECTION,"CostRateV1:"..provider.."/"..model,raw,true)
  update_status="Eigene Preise für "..model.." gespeichert. Bisherige Kosten bleiben unverändert."
 end
 function costs.show()
  local r=costs.rate(provider,model)
  local tariff=r and string.format("Aktuelles Modell %s: Eingabe %.4g / Ausgabe %.4g / Cache %.4g USD je 1 Mio. Token.",model,r[1],r[2],r[3]) or
   ("Für "..model.." fehlt ein bestätigter Preis. Im Menü »Kostenpreise einstellen« hinterlegen.")
  reaper.ShowMessageBox("Letzter / laufender Auftrag:\n"..costs.text(costs.order).."\n\nGesamt seit "..costs.since..":\n"..costs.text(costs.total)..
   "\n\n"..tariff.."\n\nSchätzungen für Aufrufe aus Composition Studio, keine Anbieterrechnung. Standardtarife: Stand 09.10.2026; eigene Preise im Menü. Google-Free-Tier kann mit Preisen 0 eingestellt werden. Fehlende Verbrauchsdaten bleiben als unvollständig markiert. Frühere Aufrufe vor dieser Version sind nicht enthalten.",SCRIPT_NAME.." – Kosten",0)
 end
end
-- End cost accounting.
