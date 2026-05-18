# WinGet Output Fixtures

Captured (and curated) WinGet CLI output samples used by `tools\Test-WinGetRunner.ps1`
to verify locale-independent classification and parser behavior. Files are plain
text so contributors can add new locales by capturing output, redacting any user
paths, and dropping the file here.

Each fixture pairs a representative `winget` output with an expected classification:

- `install-success-en.txt` - English install success; exit code 0; expected status `SUCCESS`.
- `upgrade-uptodate-en.txt` - English "No available upgrade found"; exit code 0; expected status `UP TO DATE` via text fallback.
- `upgrade-uptodate-de.txt` - German "Es wurde kein verfügbares Upgrade gefunden"; expected status `UP TO DATE` via HRESULT (text fallback does not match German prose).
- `upgrade-uptodate-es.txt` - Spanish "No se encontró ninguna actualización aplicable"; expected status `UP TO DATE` via HRESULT.
- `install-failure-en.txt` - English installer failure with non-zero exit; expected status `FAILED`.
- `pin-list-blocking.txt` - `winget pin list` row with `Blocking` pin type column.
- `pin-list-gating.txt` - `winget pin list` row with `Gating` pin type column.
- `pin-list-pinning.txt` - `winget pin list` row with `Pinning` (default pin) column.
- `pin-list-empty.txt` - "There are no pins configured."
- `list-updates-available.txt` - `winget list` with two catalog packages, one with an available update.
- `show-full-en.txt` - `winget show` output with full installer block (publisher, installer type/URL/SHA256, homepage).

When adding a new locale fixture for `UP TO DATE` classification, pair it with the
exit code that WinGet returns for that locale's run; classification should pass on
the exit code alone so the test would still detect a regression if the English-text
fallback regex were removed.
