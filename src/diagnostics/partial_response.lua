-- Preserve only provider-visible text, never thinking blocks or a second usable proposal.
function costs.capture_partial(pv,raw)
 diag_set("api_response_bytes",type(raw)=="string" and tostring(#raw) or "0")
 if type(raw)~="string" or raw=="" then diag_set("api_partial_status","Keine Antwortdaten verfügbar.");return end
 if #raw>2000000 then diag_set("api_partial_status","Antwort größer als 2 MB; sichere Textauswertung ausgelassen.");return end
 local ok,object=pcall(decode_engine_json,raw)
 if not ok or type(object)~="table" then diag_set("api_partial_status","Antwort-JSON unvollständig oder ungültig; kein sicher extrahierter Text.");return end
 local pieces={}
 if pv=="google" then
  local candidate=type(object.candidates)=="table" and object.candidates[1]
  local content=type(candidate)=="table" and candidate.content
  for _,part in ipairs(type(content)=="table" and type(content.parts)=="table" and content.parts or {}) do
   if type(part)=="table" and (part.thought==nil or part.thought==false) and type(part.text)=="string" then pieces[#pieces+1]=part.text end
  end
 elseif pv=="openai" then
  for _,item in ipairs(type(object.output)=="table" and object.output or {}) do
   if type(item)=="table" and item.type=="message" then
    for _,part in ipairs(type(item.content)=="table" and item.content or {}) do
     if type(part)=="table" and part.type=="output_text" and type(part.text)=="string" then pieces[#pieces+1]=part.text end
    end
   end
  end
 elseif pv=="anthropic" then
  for _,part in ipairs(type(object.content)=="table" and object.content or {}) do
   if type(part)=="table" and part.type=="text" and type(part.text)=="string" then pieces[#pieces+1]=part.text end
  end
 end
 local text=table.concat(pieces,"\n");local at=math.min(#text,262144)
 -- Do not cut a UTF-8 codepoint in the diagnostic JSON.
 while at>0 do local b=text:byte(at+1);if not b or b<128 or b>191 then break end;at=at-1 end
 diag_set("api_partial_answer_bytes",tostring(#text))
 diag_set("api_partial_retained_bytes",tostring(at))
 diag_set("api_partial_truncated",at<#text and "true" or "false")
 diag_set("api_partial_answer",text:sub(1,at))
 diag_set("api_partial_status",#text>0 and "Unvollständige sichtbare Antwort, nur Diagnose; nicht zur MIDI-Übernahme freigegeben." or "Kein sichtbarer Antworttext in der Anbieterantwort.")
end
