# Modulare Entwicklungsquellen, weiterhin eine Laufzeitdatei

Der erste Schnitt isoliert ausschließlich den bestehenden Versionsvergleich.
`src/core/version.lua` ist die bearbeitbare Quelle und liefert `parts(v)` sowie
`is_newer(remote, localv)`. Die bisherigen Regeln einschließlich `x.y-testN`
bleiben erhalten. Keine REAPER-, Provider- oder Musikabhängigkeiten.

Nach Änderungen am Modul aus dem Repository-Root ausführen:

```sh
python tools/build_version_module.py
python tools/build_update_helper.py
python tools/build_offline_installer.py
python tools/test_version_module.py
python tools/test_lilypond_import.py
python tools/test_update_helper.py
python tools/test_offline_installer.py
```

Die Testumgebung benötigt Python, `lupa==2.8` und für die weiteren UI-Regressionen
`imgui-bundle==1.93.0`. Der Differentialtest verwendet den unveränderten
Produktionscommit `4743491d7081cf009f144a88b70c373047febeab` als Referenz;
historische Git-Objekte müssen verfügbar bleiben.

`build_version_module.py --check` prüft die Synchronität ohne Schreibzugriff.
Der eingebettete private Block hält die bisherigen lokalen Funktionsnamen
für Installer und Aufrufer verfügbar. Beide bestehenden Installergeneratoren
übernehmen diesen Block bereits über ihre vorhandenen Quellabschnittsgrenzen.
Es gibt keine neue Laufzeitdatei, kein `require`, keinen neuen Suchpfad und
keine neue Versionsnummer. Eine Veröffentlichung bleibt ein eigener Schritt.

Weitere Module folgen dem [Auditplan](MODULARIZATION-AUDIT-2026-11-05.md).
Bekannte Unicode-/Transport-Fixturefehler werden in diesem Schnitt nicht verändert.
