-- @description Notation Studio – sichere Lesbarkeit: Testfassung starten
-- @about Starts a pinned preview in a separate file. Does NOT overwrite Notation Studio.lua.
-- @version 1.0

-- Public project commit, pinned so the test cannot silently change.
local COMMIT = "a916b2261b25cd3bbbbb53964ef81ecc402ea52e"
local EXPECTED_VERSION = "0.1.24-test.1"
local URL = "https://raw.githubusercontent.com/wibem1/Composition-Studio/" .. COMMIT .. "/Notation%20Studio.lua"

local function fail(message)
  reaper.ShowMessageBox(message, "Notation Studio – Testfassung", 0)
end
local function quote(value)
  return '"' .. tostring(value):gsub('"', '') .. '"'
end
local osname = reaper.GetOS()
local sep = osname:match("Win") and "\\" or "/"
local dir = reaper.GetResourcePath() .. sep .. "Scripts"
if reaper.RecursiveCreateDirectory then reaper.RecursiveCreateDirectory(dir, 0) end
local target = dir .. sep .. "Notation Studio Lesbarkeit Preview " .. COMMIT:sub(1, 8) .. ".lua"
local temporary = target .. ".part"

local function read(path)
  local f = io.open(path, "rb")
  if not f then return nil end
  local bytes = f:read("*a")
  f:close()
  return bytes
end
local source = read(target)
if not source then
  local binary
  if osname:match("Win") then
    binary = (os.getenv("SystemRoot") or "C:\\Windows") .. "\\System32\\curl.exe"
  else
    binary = "/usr/bin/curl"
  end
  local cmd = quote(binary) .. " --fail --silent --show-error --location --max-time 30 -o " .. quote(temporary) .. " " .. quote(URL)
  local result = reaper.ExecProcess(cmd, 36000)
  local exitcode = result and tonumber(result:match("^(%-?%d+)"))
  if exitcode ~= 0 then
    os.remove(temporary)
    return fail("Testfassung konnte nicht geladen werden. Internetverbindung bzw. curl prüfen.\n\n" .. tostring(result or "Kein Prozessergebnis"))
  end
  source = read(temporary)
end
if not source or #source < 20000 or not source:find("%-%- @description Notation Studio") or
   not source:find("%-%- @version " .. EXPECTED_VERSION:gsub("([%.%-])", "%%%1")) then
  os.remove(temporary)
  return fail("Geladene Datei hat nicht die erwartete Testversionskennung. Es wird nichts ausgeführt.")
end
local program, syntax_error = load(source, "@" .. target, "t")
if not program then
  os.remove(temporary)
  return fail("Lua-Syntaxprüfung fehlgeschlagen: " .. tostring(syntax_error))
end
if not read(target) then
  local ok = os.rename(temporary, target)
  if not ok then
    os.remove(temporary)
    return fail("Testfassung konnte nicht separat gespeichert werden: " .. target)
  end
end
-- Do not register or replace any installed REAPER action. Run this separate preview only.
local ok, err = pcall(program)
if not ok then return fail("Testfassung konnte nicht gestartet werden: " .. tostring(err)) end
