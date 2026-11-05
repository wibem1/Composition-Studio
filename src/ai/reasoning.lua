return function(REASONING_LABELS)
local function reasoning_parameters(pv,md,choice)
 if choice=="auto" then return "","provider_default" end
 local effort=REASONING_LABELS[choice] and choice or "medium"
 if pv=="openai" then
  local value='"reasoning":{"effort":"'..effort..'"}'
  return ","..value,value
 elseif pv=="anthropic" then
  local value='"output_config":{"effort":"'..effort..'"}'
  return ","..value,value
 elseif md:match("^gemini%-2%.5") then
  local budget=({low=2048,medium=8192,high=24576})[effort]
  local value='"generationConfig":{"thinkingConfig":{"thinkingBudget":'..budget..'}}'
  return ","..value,value
 else
  local value='"generationConfig":{"thinkingConfig":{"thinkingLevel":"'..effort..'"}}'
  return ","..value,value
 end
end
-- End thinking control.
-- BEGIN MODULE EXPORTS
return {reasoning_parameters=reasoning_parameters}
end
