local function first_program_changes_on_track(track)
 local pcs={}
 for i=0,reaper.CountTrackMediaItems(track)-1 do local item=reaper.GetTrackMediaItem(track,i); local take=item and reaper.GetActiveTake(item); if take and reaper.TakeIsMIDI(take) then local _,_,cc=reaper.MIDI_CountEvts(take); for n=0,(cc or 0)-1 do local ok,_,muted,ppq,chanmsg,ch,msg2=reaper.MIDI_GetCC(take,n); if ok and not muted and chanmsg==0xC0 then local tm=reaper.MIDI_GetProjTimeFromPPQPos(take,ppq); local c=(ch or 0)+1; if not pcs[c] or tm<pcs[c].time then pcs[c]={program=msg2,time=tm} end end end end end
 return pcs
end
local function find_halions(track) local out={}; for fx=0,reaper.TrackFX_GetCount(track)-1 do local ok,n=reaper.TrackFX_GetFXName(track,fx,""); if ok and (n or ""):lower():find("halion sonic",1,true) then out[#out+1]=fx end end; return out end
local function halion_program_param(track,fx,ch) local wanted="S"..ch.." Program Change"; for p=0,reaper.TrackFX_GetNumParams(track,fx)-1 do local ok,n=reaper.TrackFX_GetParamName(track,fx,p,""); if ok and n==wanted then return p end end end
local function source_tracks_for_halion(dest) local out,seen={},{}; if reaper.CountTrackMediaItems(dest)>0 then out[#out+1]=dest; seen[dest]=true end; for r=0,reaper.GetTrackNumSends(dest,-1)-1 do local src=reaper.GetTrackSendInfo_Value(dest,-1,r,"P_SRCTRACK"); if src and not seen[src] then out[#out+1]=src; seen[src]=true end end; return out end
local function initialize_halion_track(track) local fxs=find_halions(track); if #fxs==0 then return 0 end; local pcs={}; for _,src in ipairs(source_tracks_for_halion(track)) do local found=first_program_changes_on_track(src); for ch,v in pairs(found) do if not pcs[ch] or v.time<pcs[ch].time then pcs[ch]=v end end end; local changed=0; for _,fx in ipairs(fxs) do for ch=1,16 do local v=pcs[ch]; if v then local p=halion_program_param(track,fx,ch); if p then reaper.TrackFX_SetParamNormalized(track,fx,p,v.program/127.0); changed=changed+1 end end end end; return changed end
local function initialize_halion_project() local tracks,slots=0,0; for i=0,reaper.CountTracks(0)-1 do local tr=reaper.GetTrack(0,i); if #find_halions(tr)>0 then local n=initialize_halion_track(tr); if n>0 then tracks=tracks+1; slots=slots+n end end end; return tracks,slots end


