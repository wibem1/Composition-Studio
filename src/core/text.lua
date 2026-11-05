local function trim(s) return (s or ""):gsub("^%s+",""):gsub("%s+$","") end
local function safe_work_title(t)
 t=trim(t):gsub("[\r\n]"," "):gsub("[/\\:]","-"):gsub("%s+"," "):gsub("^%.*",""):gsub("%.*$","")
 if #t>80 then t=t:sub(1,80):gsub("%s+$","") end
 return t
end
local function title_from_draft(draft,request)
 local t=tostring(draft or ""):match("^[Tt][Ii][Tt][Ee][Ll]%s*:%s*([^\n\r]+)") or tostring(draft or ""):match("^[Ww][Ee][Rr][Kk][Tt][Ii][Tt][Ee][Ll]%s*:%s*([^\n\r]+)")
 t=safe_work_title(t or "")
 return t
end
-- BEGIN MODULE EXPORTS
return {trim=trim,safe_work_title=safe_work_title,title_from_draft=title_from_draft}
