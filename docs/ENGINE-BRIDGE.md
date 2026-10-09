# Composition Engine → REAPER adapter (Vorbereitung)

Die zentrale Engine liegt in `wibem1/Composition-Engine/composition-engine.js` (JavaScript).
Der Adapter `engine-bridge.js` ist ein lokaler Node.js-Prozess. Er lädt **eine lokale Kopie dieser echten Engine** und verwendet deren `extractJson()` und `findScore()` statt einen eigenen JSON-Parser zu entwickeln.

Aufruf:
```
node engine-bridge.js composition-engine.js antwort.json result.cs
```

Die Datei `result.cs` enthält ausschließlich REAPER-kompatible MIDI-Ereignisse. Die technische Umsetzung in REAPER übernimmt die vorhandene `apply_composition()`-Funktion des Lua-Skripts.

**Status:** Adapter ist separat vorbereitet. Der Standard-Kompositionspfad von Composition Studio wurde noch nicht umgeschaltet. Die Engine muss zunächst lokal installiert und der Adapter mit echter REAPER-Umgebung getestet werden. Es wird kein Node.js stillschweigend vorausgesetzt. Kein KI-Aufruf, keine LilyPond-Konvertierung in diesem Adapter.

**Grenzen:** Der Adapter akzeptiert das JSON-Schema `{bpm,timeSignature,tracks:[{name,program,channel,notes:[[startBeat,durationBeat,pitch,velocity],...]}]}`. Er unterstützt hier noch keine zusätzlichen CC-/Pitchbend-Ereignisse oder Fortsetzungen. Er validiert Noten streng und ergänzt keine fehlenden Takte oder Noten.
