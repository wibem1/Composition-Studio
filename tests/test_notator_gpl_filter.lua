-- GPL-3.0 Notator module smoke tests (no real REAPER installation required).
-- Run from repository root with Lua 5.3+: lua tests/test_notator_gpl_filter.lua
-- Copyright (C) 2026 Composition-Studio contributors; SPDX-License-Identifier: GPL-3.0-only

local mock = {}
mock.MIDI_GetProjQNFromPPQPos = function(_, ppq) return ppq / 960 end
mock.TimeMap_QNToMeasures = function(_, qn)
  local bar = math.floor(qn / 4)
  return bar, bar * 4, (bar + 1) * 4
end
reaper = mock

package.loaded["services.midi_service"] = {}
local module_file = "vendor/REAPER-Notator-2.55/modules/services/filter_notes_service.lua"
local filter = dofile(module_file)
assert(type(filter) == "table" and type(filter.is_note_regular) == "function",
  "original GPL FilterNotesService did not load")

local function check(qn, grid, triplets, expected, description)
  local regular, difference = filter.is_note_regular({}, qn * 960, grid, 10, triplets)
  assert(regular == expected,
    description .. ": expected " .. tostring(expected) .. " but got " .. tostring(regular))
  assert(type(difference) == "number" and difference >= 0)
end

check(0.25, 0.25, false, true, "exact sixteenth")
check(0.125, 0.25, false, false, "32nd onset off 16th grid")
check(0.125, 0.125, false, true, "32nd onset on 32nd grid")
check(0.26, 0.25, false, true, "within ten ticks")
check(0.333333333333, 0.125, false, false, "triplet without recognition")
check(0.333333333333, 0.125, true, true, "triplet with recognition")
check(4.125, 0.125, false, true, "bar-relative grid")

print("OK: 7 GPL FilterNotesService tests (no REAPER data modified)")
