local function start_translation_chunk(data,key)
 local first_bar=data.chunk_first
 local last_bar=math.min(data.chunk_total,first_bar+6)
 local prompt=chunk_prompt(data.draft,first_bar,last_bar)
 diag_set("translation_prompt",prompt)
 update_status="Notenübertragung: Takte "..first_bar.."–"..last_bar.." von "..data.chunk_total
 return launch("translation_chunk",prompt,key,data)
end

