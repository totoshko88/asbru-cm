# Cosmic integration review

Summary:
- Keep PACTrayCosmic for advanced paths (AppIndicator/SNI) but gate via detection and env ASBRU_DISABLE_COSMIC=1.
- In PACTray standard, only use helper window if legacy tray missing on Cosmic; otherwise use StatusIcon.
- Centralize detection in PACCompat; avoid duplicating is_cosmic_desktop logic elsewhere.

Actioned tweaks in this commit:
- PACMain: clarified truth/ref check for PACTrayCosmic object construction.
- PACTray: respect ASBRU_DISABLE_COSMIC and use case-insensitive match; minor comment casing.

When to remove duplication:
- If Cosmic panel API stabilizes, fold helper window into PACTrayCosmic and call it exclusively under Cosmic.

Environment toggles:
- ASBRU_DISABLE_COSMIC=1 — disable Cosmic-specific logic paths
- ASBRU_FORCE_SNI=1 — prefer StatusNotifierItem integration when watcher present
