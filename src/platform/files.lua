local function json_escape(s) return tostring(s or ""):gsub("\\","\\\\"):gsub('"','\\"'):gsub("\n","\\n"):gsub("\r","\\r"):gsub("\t","\\t") end
local function read_file(p) local f=io.open(p,"rb"); if not f then return nil end; local s=f:read("*a"); f:close(); return s end
local function write_file(p,s) local f=io.open(p,"wb"); if not f then return false end; f:write(s); f:close(); return true end
