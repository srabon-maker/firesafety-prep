# Fire Safety BD — UI/UX 2.0

This branch changes presentation only. It preserves existing APIs, routes, authentication and premium checks. No simulated progress, verified badges or fake job data.

## Included
- Global Material 3 theme: shared colors, card shape, buttons, form fields, typography and dark theme.
- Home: quick-access layout, selected translations, loading placeholders, guarded career shortcut.
- Bottom navigation: selected indicator and transitions.
- Job cards: contrast and typography; test question progress/selected option; question card spacing.
- Notes: adjustable reading text size and dark-mode HTML styling.
- Community: post readability and translated counts; marketplace price styling; profile menu readability.
- Career: bilingual responsive dashboard; loading placeholder.
- Finite loading animation respects reduced motion. Added smoke tests.

## Follow-up / verification
- Run flutter analyze, flutter test, and flutter build apk --debug before merge. This branch is not a verified APK.
- Device review: 320/360/412 dp, large fonts, Bengali/English, light/dark, offline/empty/error, TalkBack, login/guest, premium access, purchase and exam submission flows.
- Full localization of existing pages, bundled licensed Bengali/English fonts, server-backed job bookmarks and verified professional labels, global search, actual progress on home, notification badge, richer community/marketplace/profile redesign, and remaining loading states are follow-up work. Do not invent data or change backend contracts to implement them without review.
