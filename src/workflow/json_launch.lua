local function launch_new_json(request,key,data)
 data=data or {request=request,full={},music_tracks={}}
 if composition_mode=="concept" then
  local p=concept_prompt(request)
  diag_set("composition_mode","Konzeption + Komposition")
  diag_set("concept_prompt",p)
  update_status="Musikalisches Grundgerüst wird entwickelt …"
  return launch("engine_concept",p,key,data)
 end
 diag_set("composition_mode","Direktes JSON")
 local p=engine_json_prompt(request)
 diag_set("composition_prompt",p)
 return launch("engine_json",p,key,data)
end
