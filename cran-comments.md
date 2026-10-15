## Resubmission summary

This is a resubmission addressing the feedback from the incoming pre-tests (received from Uwe Ligges on 2026-10-14).

### Feedback and fixes applied:

1. **Package CITATION old-style `citEntry()`**:
   - Replaced deprecated `citEntry()` with `bibentry(bibtype = "Manual", ...)` in `inst/CITATION`. Verified with `utils::readCitationFile()`.

2. **Redirected URLs (Status: 301)**:
   - Added trailing slash to `https://paulesantos.github.io/walkability/` in `DESCRIPTION`, `man/walkability-package.Rd`, and `inst/CITATION`.
   - Updated `https://www.rust-lang.org/` to canonical `https://rust-lang.org/` in `README.md` and `README.Rmd`.

3. **Invalid file URI (`/d:/walkability/R/plot.R` from `inst/doc/visualizacion-avanzada.html`)**:
   - Removed the local file URI link `[`theme_walkability()`](file:///d:/walkability/R/plot.R)` from `vignettes/visualizacion-avanzada.Rmd` and replaced it with plain code formatting `` `theme_walkability()` ``.

4. **Spell check NOTE in DESCRIPTION**:
   - `'OpenStreetMap'` is now enclosed in single quotes as per CRAN policy for software/data source names.
   - Rephrased "active transitability" to "active mobility".
   - Created `inst/WORDLIST` containing domain-specific terminology (`geospatial`, `isochrone`, `walkability`, `Walkability`).
   - The remaining words ('geospatial', 'isochrone', 'walkability', 'Walkability') are standard and recognized GIS / urban planning scientific terminology and the package name itself.

## Test environments
- Windows (local and win-builder)
- Debian Linux (win-builder / rhub / CRAN pretest)

## R CMD check results

0 errors | 0 warnings | 1 note

* This is a new submission.
