"""Native request fixtures; no paid API calls. Python + lupa/Lua 5.4."""
from pathlib import Path
import json, runpy
h=runpy.run_path(str(Path(__file__).with_name("test_cost_accounting.py")))
env=h["env"]
Path(h["scratch"].name).mkdir(exist_ok=True)
models=[("openai","gpt-5.6-sol"),("anthropic","claude-sonnet-5"),("anthropic","claude-fable-5"),("anthropic","claude-opus-5"),("google","gemini-3.8-flash"),("google","gemini-3.1-pro-preview"),("google","gemini-2.5-pro")]
for pv,md in models:
 for choice in ["low","medium","high","auto"]:
  r,a,_=env()
  assert a.reasoning()=="medium"
  a.set_reasoning(choice)
  assert r.globals().saved["ReasoningEffortV1"]==choice
  restored,ra,_=env({"ReasoningEffortV1":choice})
  assert ra.reasoning()==choice
  r.globals().provider=pv; r.globals().model=md
  call,error=a.command("TEST PROMPT","TEST KEY")
  assert error is None
  body=json.loads(Path(call.rq).read_text())
  assert a.diagnostics.reasoning_mode==choice
  assert call.reasoning_mode==choice
  if choice=="auto":
   assert not any(k in body for k in ["reasoning","output_config","generationConfig"])
   assert call.reasoning_requested=="provider_default"
  elif pv=="openai": assert body["reasoning"]=={"effort":choice}
  elif pv=="anthropic": assert body["output_config"]=={"effort":choice}
  elif md.startswith("gemini-2.5"):
   assert body["generationConfig"]["thinkingConfig"]=={"thinkingBudget":{"low":2048,"medium":8192,"high":24576}[choice]}
  else: assert body["generationConfig"]["thinkingConfig"]=={"thinkingLevel":choice}
  r.globals().busy=True; a.set_reasoning("auto" if choice!="auto" else "low")
  assert a.reasoning()==choice
  Path(call.rq).unlink()
for invalid in ["", "default", "junk"]:
 r,a,_=env({"ReasoningEffortV1":invalid}); assert a.reasoning()=="medium"
 a.set_reasoning("junk"); assert a.reasoning()=="medium"
print("PASS: 28 provider/mode request fixtures, default, restart persistence, busy lock, invalid settings and diagnostics")
