-- The official LilyPond compiler handles the musical semantics.
local LILYPOND_PATH_KEY="LilyPondExe"
local function lily_exe()
 local p=trim(reaper.GetExtState(EXT_SECTION,LILYPOND_PATH_KEY))
 if p~="" and reaper.file_exists(p) then return p end
 local home=os.getenv("USERPROFILE") or ""
 local expected=home.."/Downloads/lilypond-2.26.0-mingw-x86_64/lilypond-2.26.0/bin/lilypond.exe"
 if reaper.file_exists(expected) then
  reaper.SetExtState(EXT_SECTION,LILYPOND_PATH_KEY,expected,true)
  return expected
 end
 return nil
end
local function set_lily_exe()
 local old=reaper.GetExtState(EXT_SECTION,LILYPOND_PATH_KEY) or ""
 local ok,p=reaper.GetUserInputs("LilyPond",1,"Pfad zu lilypond.exe:",old)
 if not ok then return end
 p=trim(p):gsub('^"',''):gsub('"$','')
 if not reaper.file_exists(p) then update_status="LilyPond nicht gefunden: "..p; return end
 reaper.SetExtState(EXT_SECTION,LILYPOND_PATH_KEY,p,true)
 update_status="LilyPond-Pfad gespeichert."
end
local function midi_score(src)
 src=trim(src)
 local fence=string.rep(string.char(96),3)
 if src:sub(1,3)==fence then
  src=src:gsub("^[^\n]*\n",""):gsub("\n[^\n]*$","")
 end
 local beginning=src:find("\\score",1,true)
 if not beginning then return nil,"Kein LilyPond-score-Block vorhanden." end
 local opening=src:find("{",beginning+6,true)
 if not opening then return nil,"LilyPond-score-Block unvollständig." end
 local depth,closing=0,nil
 for i=opening,#src do
  local ch=src:sub(i,i)
  if ch=="{" then depth=depth+1 elseif ch=="}" then depth=depth-1; if depth==0 then closing=i; break end end
 end
 if not closing then return nil,"LilyPond: schließende score-Klammer fehlt." end
 if not src:sub(opening,closing):find("\\midi",1,true) then
  src=src:sub(1,closing-1).."\n\\midi { }\n"..src:sub(closing)
 end
 return src
end

-- A continuation is a new passage appended after the latest selected MIDI item.
