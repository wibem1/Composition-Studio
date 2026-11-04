"""Safety gate for semantic MIDI notation plans. Does not edit MIDI or REAPER."""
from collections import Counter

ROLES = {"melody", "bass", "accompaniment", "inner_voice", "bass_or_accompaniment", "unknown"}
CONFIDENCE = {"confirmed", "provisional", "uncertain", "provisional_reference"}

def validate_plan(plan, original_notes, tolerance=0.000002):
    """Original notes must come from an independently parsed MIDI inventory."""
    if not isinstance(plan, dict) or not isinstance(plan.get("notes"), list):
        return ["Plan requires notes array"]
    errors = []
    expected = {n["id"]: n for n in original_notes}
    if len(expected) != len(original_notes):
        return ["Duplicate IDs in original inventory"]
    found = Counter(n.get("id") for n in plan["notes"])
    if set(found) != set(expected):
        errors.append("Plan note IDs differ from MIDI inventory")
    if any(count != 1 for count in found.values()):
        errors.append("Duplicate plan IDs")
    if len(plan["notes"]) != len(original_notes):
        errors.append("Note count differs")
    for note in plan["notes"]:
        ident = note.get("id")
        if ident not in expected:
            continue
        source = expected[ident]
        original = note.get("original") or {}
        performance = source.get("original", source)
        if note.get("pitch_midi") != source.get("pitch_midi"):
            errors.append(f"{ident}: pitch changed")
        for field in ("start_qn", "end_qn", "velocity", "channel"):
            a, b = original.get(field), performance.get(field)
            if not isinstance(a, (int, float)) or not isinstance(b, (int, float)) or abs(a-b) > tolerance:
                errors.append(f"{ident}: performance field {field} differs")
        if note.get("role", "unknown") not in ROLES:
            errors.append(f"{ident}: unknown role")
        notation = note.get("notation") or {}
        if notation.get("confidence", "uncertain") not in CONFIDENCE:
            errors.append(f"{ident}: invalid confidence")
        duration = notation.get("duration_qn")
        if duration is not None and (not isinstance(duration, (int, float)) or duration <= 0):
            errors.append(f"{ident}: invalid displayed duration")
    return errors

def safe_actions(plan):
    """No speculative display edits: only explicitly confirmed, justified annotations."""
    actions = []
    for note in plan["notes"]:
        notation = note.get("notation") or {}
        if notation.get("confidence") == "confirmed" and notation.get("grace") is True and note.get("evidence"):
            actions.append({"note_id": note["id"], "kind": "grace", "evidence": note["evidence"]})
    return actions
