"""Independent offline planning helper: malformed/nonfinite data fail closed.
This helper is not used by the live Lua analysis and never edits MIDI.
"""
from copy import deepcopy
from semantic_notation import validate_plan, safe_actions

original = [{'id':'n1', 'pitch_midi':60, 'start_qn':0, 'end_qn':0.5, 'velocity':90, 'channel':0}]
plan = {'notes':[{'id':'n1', 'pitch_midi':60, 'original':deepcopy(original[0]),
                 'role':'melody', 'notation':{'confidence':'uncertain','duration_qn':0.5}}]}
assert validate_plan(plan, original) == []
assert safe_actions(plan) == []
for value in (float('nan'), float('inf'), -float('inf'), True, '0'):
    bad = deepcopy(plan)
    bad['notes'][0]['original']['start_qn'] = value
    assert validate_plan(bad, original)
    bad = deepcopy(plan)
    bad['notes'][0]['notation']['duration_qn'] = value
    assert validate_plan(bad, original)
for value in (None, 1, {}, {'notes':[None]}, {'notes':[{'id':[]}]}):
    assert validate_plan(value, original)
for field, value in (('original', [1]), ('notation', [1]), ('pitch_midi', True)):
    bad = deepcopy(plan)
    bad['notes'][0][field] = value
    assert validate_plan(bad, original)
bad = deepcopy(plan)
bad['notes'].append(deepcopy(bad['notes'][0]))
assert validate_plan(bad, original)
assert validate_plan(plan, original * 2)
assert validate_plan(plan, original, float('nan'))
assert validate_plan(plan, original, -1)
assert original[0]['start_qn'] == 0 and plan['notes'][0]['notation']['confidence'] == 'uncertain'
print('PASS offline planning helper: exact inventory, duplicate/malformed/nonfinite rejection, uncertainty and no source mutation')
