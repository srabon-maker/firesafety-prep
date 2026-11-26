# Fire Safety BD UI/UX 2.0 — review checklist
This branch is a frontend-only incremental redesign. Preserve authentication, remote section configuration, premium locks, existing routes, data and API contracts. No signing or workflow changes. No external fonts or new dependencies; use the platform's Bengali fallback until licensed font assets can be bundled.

## Implemented scope
- Shared Material 3 light/dark typography, card, button, navigation and status styling.
- Home quick access, responsive layout, localized key labels, career entry and loading/retry states.
- Career adaptive dashboard, question and exam feedback, loading placeholders in jobs/notes/community/shop and profile section headings.
- Shared finite animation respecting reduced-motion setting and widget tests.

## Before merging
- [ ] flutter pub get
- [ ] dart format changed Dart files
- [ ] flutter analyze
- [ ] flutter test
- [ ] Test 320/360/412/768 logical-pixel widths, landscape, 1x/1.5x/2x text, Bengali and English, dark/light, reduced motion.
- [ ] Check guest vs logged-in Home, Community, Shop, Profile; career routes and access restrictions.
- [ ] Check premium-locked content, remote banners/order, jobs search, notes/bookmarks, exam timer/submit/resume, cart/bookings, community posting, logout and account deletion.
- [ ] Verify loading, empty, error/retry, offline and long text on each screen.
- [ ] Build existing Android workflow with established signing identity, install and smoke-test. Do not generate a new signing key.
- [ ] Capture actual screenshots and compare design before merging.

## Follow-up
Full localization of all legacy screens, bundled font family, richer job filters, actual preparation progress on Home, reading controls, notification counts and detailed screen-specific redesigns require further implementation and testing. Do not invent verification badges or progress values.
