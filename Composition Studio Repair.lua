-- @description Composition Studio: vorherige Version nach fehlgeschlagenem Update wiederherstellen
-- @version 1.0.0
local function read(path)
 local f=io.open(path,"rb");if not f then return nil end
 local s=f:read("*a");f:close();return s
end
local function message(s) reaper.ShowMessageBox(s,"Composition Studio – Wiederherstellung",0) end
local target=reaper.GetExtState("CompositionStudio","ActiveScriptPath")
if not target or target=="" then message("Der registrierte Skriptpfad fehlt. Bitte die Datei Composition Studio.lua.backup im Skriptordner sichern.");return end
local original=read(target..".backup")
local failed=read(target)
if not original or not original:find('local SCRIPT_NAME="Composition Studio"',1,true) or not load(original,"@Composition Studio backup","t") then
 message("Keine gültige Updatesicherung gefunden: "..target..".backup");return
end
if failed and failed:match("%-%- @version%s+([%w%.%-]+)")~="1.1.0" then
 message("Diese Reparatur ist nur für die fehlerhafte Version 1.1.0 bestimmt. Keine Datei wurde verändert.");return
end
local staged=target..".repair-pending"
local f=io.open(staged,"wb")
if not f then message("Die Sicherung konnte nicht vorbereitet werden. Zielordner: "..target);return end
local written=f:write(original);local closed=f:close()
if not written or not closed or read(staged)~=original then os.remove(staged);message("Die Sicherung konnte nicht geprüft werden.");return end
local preserved=target..".failed-1.1.0"
if read(preserved) then os.remove(staged);message("Es existiert bereits eine Reparatursicherung: "..preserved..". Keine Datei wurde verändert.");return end
if failed and not os.rename(target,preserved) then os.remove(staged);message("Die installierte Datei konnte nicht gesichert werden.");return end
if not os.rename(staged,target) then
 if failed then os.rename(preserved,target) end
 message("Wiederherstellung fehlgeschlagen. Sicherung: "..target..".backup");return
end
reaper.SetExtState("CompositionStudio","WindowOpen","0",true)
message("Vorherige Version wiederhergestellt. Bitte Composition Studio erneut öffnen und im Studio-Menü das Update auf 1.1.1 installieren.")
