local function request_words(request)
 local r=tostring(request or ""):lower():gsub("Ä","ä"):gsub("Ö","ö"):gsub("Ü","ü")
 r=r:gsub("ä","ae"):gsub("ö","oe"):gsub("ü","ue"):gsub("ß","ss"):gsub("%s+"," ")
 for word,n in pairs({ein=1,einen=1,eine=1,zwei=2,drei=3,vier=4,fuenf=5,acht=8,sechzehn=16}) do
  r=r:gsub("%f[%a]"..word.."%f[%A]",tostring(n))
 end
 return r
end
local function continuation_bars(request)
 local r=request_words(request)
 if not (r:find("verlaenger",1,true) or r:find("fortsetz",1,true) or r:find("fort%s+um") or r:find("setze.-fort") or r:find("anhaeng",1,true) or r:find("haenge.-an") or r:find("%d+%s+weiteren?%s+takt")) then return nil end
 local n=tonumber(r:match("um%s+(%d+)%s+takt") or r:match("(%d+)%s+weiteren?%s+takt"))
 if not n then
  local counts={};for value in r:gmatch("(%d+)%s+takt") do counts[#counts+1]=tonumber(value) end
  if #counts==1 then n=counts[1] end
 end
 if n and n>=1 and n<=128 then return n end
 return nil
end
local function request_transition(request)
 local r=request_words(request)
 local count=tonumber(r:match("(%d+)%s+uebergangstakt") or r:match("(%d+)%s+schlusstakte?%s+als%s+uebergang") or r:match("(%d+)%s+takte?%s+als%s+uebergang"))
 if not count then
  for clause in r:gmatch("[^,;%.]+") do
   local n=clause:match("letzten%s+(%d+)%s+takt") or clause:match("(%d+)%s+schlusstakt")
   if n and (clause:find("gestalt",1,true) or clause:find("ueberarbeit",1,true) or clause:find("ersetz",1,true) or clause:find("aender",1,true)) then count=tonumber(n);break end
  end
 end
 local retain=r:find("schluss%s+erhalten") or r:find("schluss%s+unveraendert") or r:find("ohne%s+uebergang") or r:find("schluss.-nicht%s+veraender")
 if retain and count and count>0 then return nil,"Soll der Schluss erhalten bleiben oder neu gestaltet werden?" end
 if count then
  if count~=2 and count~=3 and count~=4 then return nil,"Für den Übergang bitte 2, 3 oder 4 Schlusstakte angeben." end
  return count
 end
 if not retain and (r:find("uebergang",1,true) or r:find("schluss.-neu%s+gestalt")) then
  return nil,"Wie viele Schlusstakte darf ich für den Übergang neu gestalten: 2, 3 oder 4?"
 end
 return 0
end
-- BEGIN MODULE EXPORTS
return {request_words=request_words,continuation_bars=continuation_bars,request_transition=request_transition}
