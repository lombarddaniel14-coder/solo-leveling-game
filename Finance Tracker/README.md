# Finance Tracker

**Open it:** double-click `index.html` (or `Launch Finance Tracker.bat`). Works offline in Chrome/Edge — no install, no internet.

**How data saves:** every add/edit/delete auto-saves instantly to the browser's localStorage (key `finance-tracker-data`). Data survives refresh and browser restarts. The "Last saved" timestamp in the header confirms each save. First-ever load starts from the built-in seed data.

**Back up:** click **Export JSON** (full backup — restore anytime with **Import JSON**) and **Export CSV** (open in Excel/Sheets). Do this weekly — localStorage is per-browser, so a backup protects you if you clear browsing data or switch browsers.

Seed copies of the data live here as `finance-data.json` and `finance-data.csv`.
