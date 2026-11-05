return function(trim,parse_notes,program_for_name)
local function plan_composition(text,items,tracks,force_single_piano) local src,targets={},{ }; for _,it in ipairs(items) do src[it.guid]=it end; for _,t in ipairs(tracks or {}) do targets[t.guid]=t.track end; local jobs={}; local musical_map={}; local controls={}; for line in text:gmatch("[^\r\n]+") do line=trim(line); local mt,q,bpm=line:match("^CSMETA|(tempo)|([^|]+)|([^|]+)$"); local ms,mq,num,den=line:match("^CSMETA|(timesig)|([^|]+)|([^|]+)|([^|]+)$"); if mt then q,bpm=tonumber(q),tonumber(bpm); if not q or not bpm or q<0 or bpm<=0 then return nil,"Ungültige Tempoangabe." end; musical_map[#musical_map+1]={kind="tempo",qn=q,bpm=bpm} elseif ms then mq,num,den=tonumber(mq),tonumber(num),tonumber(den); if not mq or not num or not den or mq<0 or num<1 or den<1 then return nil,"Ungültige Taktartangabe." end; musical_map[#musical_map+1]={kind="timesig",qn=mq,num=math.floor(num),den=math.floor(den)} elseif line:match("^CSCTRL|") then local name,cq,ch,kind,rest=line:match("^CSCTRL|([^|]+)|([^|]+)|([^|]+)|([^|]+)|(.+)$"); cq,ch=tonumber(cq),tonumber(ch); if not name or not cq or not ch or cq<0 or ch<0 or ch>15 then return nil,"Ungültiges Ausdrucksereignis." end; if kind=="cc" then local cc,val=rest:match("^(%d+)|(%d+)$"); cc,val=tonumber(cc),tonumber(val); if not cc or not val or cc>127 or val>127 then return nil,"Ungültiges CC-Ausdrucksereignis." end; controls[#controls+1]={name=trim(name),qn=cq,ch=ch,kind="cc",a=cc,b=val} elseif kind=="program" then local pg=tonumber(rest); if not pg or pg<0 or pg>127 then return nil,"Ungültiger Program Change." end; controls[#controls+1]={name=trim(name),qn=cq,ch=ch,kind="program",a=math.floor(pg)} else return nil,"Unbekanntes Ausdrucksereignis." end else local k,g,rest=line:match("^CS|([^|]+)|([^|]+)|?(.*)$"); if not k then return nil,"Unerwartete Kompositionsantwort." end; if k=="unchanged" then if not src[g] then return nil,"Unbekannte Quelle." end elseif k=="revised" or k=="target" or k=="track" or k=="new" then local name,pg,nt=rest:match("^([^|]+)|(%d+)|(.+)$"); local notes=parse_notes(nt); local program=tonumber(pg); if not name or not notes or not program or program<0 or program>127 then return nil,"Ungültige Kompositionsdaten." end; if (k=="revised" or k=="target") and not src[g] then return nil,"Unbekannte Quelle." end; if k=="track" and not targets[g] then return nil,"Unbekannte Zielspur." end; if k=="new" and g~="-" then return nil,"Ungültige neue Spur." end; local merged=nil; for _,j in ipairs(jobs) do if j.kind==k and j.guid==g and j.name==trim(name) then merged=j; break end end; if merged then for _,note in ipairs(notes) do merged.notes[#merged.notes+1]=note end else jobs[#jobs+1]={kind=k,guid=g,name=trim(name),program=program_for_name(name,program),notes=notes} end else return nil,"Unbekannter Ergebnistyp." end end end;
 if force_single_piano then
  -- The original AI names have no authority to determine REAPER track identity.
  local all={}
  for _,j in ipairs(jobs) do
   if j.kind~="new" then return nil,"Klavier-Zusammenführung enthält eine Bearbeitungsaktion." end
   for _,note in ipairs(j.notes) do all[#all+1]=note end
  end
  if #all==0 then return nil,"Keine Klaviernoten vorhanden." end
  table.sort(all,function(a,b) if a.start_qn~=b.start_qn then return a.start_qn<b.start_qn end return a.pitch<b.pitch end)
  jobs={{kind="new",guid="-",name="Klavier",program=0,notes=all}}
  for _,ctl in ipairs(controls) do ctl.name="Klavier" end
 end
 local named={}; for _,j in ipairs(jobs) do named[j.name]=(named[j.name] or 0)+1 end
 for _,c in ipairs(controls) do if named[c.name]~=1 then return nil,"Ausdrucksereignis ohne eindeutige Zielstimme: "..c.name end end
 return jobs,musical_map,controls,src,targets
end

-- BEGIN MODULE EXPORTS
return {plan_composition=plan_composition}
end
