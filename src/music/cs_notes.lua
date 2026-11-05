local function parse_notes(text) local notes={}; for t in (text or ""):gmatch("[^;]+") do local a,b,c,d,e=t:match("^%s*([%d%.%-]+),([%d%.%-]+),(%d+),(%d+),(%d+)%s*$"); a,b,c,d,e=tonumber(a),tonumber(b),tonumber(c),tonumber(d),tonumber(e); if not(a and b and c and d and e) or a<0 or b<=0 or c>127 or d<1 or d>127 or e>15 then return nil end; notes[#notes+1]={start_qn=a,duration_qn=b,pitch=c,velocity=d,channel=e} end; return #notes>0 and notes or nil end
-- BEGIN MODULE EXPORTS
return {parse_notes=parse_notes}
