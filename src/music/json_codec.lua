-- Cross-platform Lua adapter for the shared Composition Engine JSON score schema.
-- No JavaScript runtime or extra installation required.
local function decode_engine_json(src)
 local s=tostring(src or ""):gsub("^%s+",""):gsub("%s+$","")
 if s:sub(1,3)==string.rep(string.char(96),3) then
  s=s:gsub("^[^\n]*\n",""):gsub("%s*"..string.rep(string.char(96),3).."%s*$","")
 end
 local i,n,depth=1,#s,0
 local function ws() while i<=n and s:sub(i,i):match("%s") do i=i+1 end end
 local function bad(m) error("JSON Zeichen "..i..": "..m,0) end
 local function quote()
  if s:sub(i,i)~='"' then bad("Text erwartet") end
  i=i+1;local out={}
  while i<=n do
   local ch=s:sub(i,i);i=i+1
   if ch=='"' then return table.concat(out) end
   if ch=="\\" then
    local x=s:sub(i,i);i=i+1
    local esc={['"']='"',["\\"]="\\",["/"]="/",b="\b",f="\f",n="\n",r="\r",t="\t"}
    if esc[x] then out[#out+1]=esc[x]
    elseif x=="u" then
     local hex=s:sub(i,i+3)
     if not hex:match("^%x%x%x%x$") then bad("Unicode-Escape") end
     local cp=tonumber(hex,16);i=i+4
     if cp>=0xD800 and cp<=0xDBFF and s:sub(i,i+1)=="\\u" then
      local lo=tonumber(s:sub(i+2,i+5),16)
      if lo and lo>=0xDC00 and lo<=0xDFFF then cp=0x10000+(cp-0xD800)*1024+lo-0xDC00;i=i+6 end
     end
     if cp>=0xD800 and cp<=0xDFFF then bad("Unicode-Surrogat") end
     out[#out+1]=_G.utf8.char(cp)
    else bad("Escape") end
   else
    if ch:byte()<32 then bad("Steuerzeichen") end
    out[#out+1]=ch
   end
  end
  bad("Text nicht abgeschlossen")
 end
 local parse
 parse=function()
  depth=depth+1;if depth>48 then bad("Verschachtelung") end;ws()
  local ch=s:sub(i,i);local out
  if ch=='"' then out=quote()
  elseif ch=="{" then
   i=i+1;out={};ws()
   if s:sub(i,i)=="}" then i=i+1 else
    while true do
     ws();local k=quote();ws()
     if s:sub(i,i)~=":" then bad("Doppelpunkt") end
     i=i+1;out[k]=parse();ws()
     local sep=s:sub(i,i);i=i+1
     if sep=="}" then break end
     if sep~="," then bad("Komma oder }") end
    end
   end
  elseif ch=="[" then
   i=i+1;out={};ws()
   if s:sub(i,i)=="]" then i=i+1 else
    while true do
     out[#out+1]=parse();ws()
     local sep=s:sub(i,i);i=i+1
     if sep=="]" then break end
     if sep~="," then bad("Komma oder ]") end
    end
   end
  elseif s:sub(i,i+3)=="true" then i=i+4;out=true
  elseif s:sub(i,i+4)=="false" then i=i+5;out=false
  elseif s:sub(i,i+3)=="null" then i=i+4;out=false
  else
   local token=s:sub(i):match("^-?%d+%.?%d*[eE]?[+%-]?%d*") or s:sub(i):match("^-?%.%d+[eE]?[+%-]?%d*")
   if not token or token=="" then bad("Wert") end
   out=tonumber(token);if not out then bad("Zahl") end;i=i+#token
  end
  depth=depth-1;return out
 end
 local value=parse();ws()
 if i<=n then bad("Zeichen nach JSON") end
 return value
end
-- BEGIN MODULE EXPORTS
return {decode_engine_json=decode_engine_json}
