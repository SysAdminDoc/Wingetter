# Roadmap - Wingetter

Actionable work only. Historical and completed roadmap material is archived in CHANGELOG.md; blocked work is kept in Roadmap_Blocked.md.

## Actionable Items

- [ ] P2: Search lags while typing (issue #1)
  Reported: byteshaman, 2026-09-19, on a gaming PC, so not a hardware limit.
  Why: typing in the search box and filtering the catalog lags noticeably. The likely causes are a filter that runs on every keystroke over the whole catalog on the UI thread, or a search that shells out to `winget search` per keystroke.
  Next: measure with a stopwatch around the filter; debounce input by about 150 ms; move the match off the UI thread; precompute a lowercase index of name, id and tags once per catalog load; cap the rendered rows and virtualize the list if it is not already.
  Acceptance: on a catalog of the current size, each keystroke updates the list within 50 ms on the UI thread and the input never drops characters.
  Evidence: https://github.com/SysAdminDoc/Wingetter/issues/1
  Complexity: S
