-- Pure version comparison; keep legacy update ordering unchanged.
local function version_parts(v)
 local a,b,c=tostring(v or ""):match("^(%d+)%.(%d+)%.(%d+)$")
 if a then return tonumber(a),tonumber(b),tonumber(c) end
 local x,y,t=tostring(v or ""):match("^(%d+)%.(%d+)%-test(%d+)$")
 if x then return tonumber(x),tonumber(y),tonumber(t) end
 return nil,nil,nil
end

local function version_is_newer(remote,localv)
 local a,b,c=version_parts(remote)
 local x,y,z=version_parts(localv)
 if not (a and x) then return false end
 if a~=x then return a>x end
 if b~=y then return b>y end
 return c>z
end

return {parts=version_parts, is_newer=version_is_newer}
