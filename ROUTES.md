# Synapse — Route Map

The single source of truth for every route, implemented in
`apps/app/lib/router/routes.dart` (typed helpers) and `router.dart`
(`go_router` `StatefulShellRoute`). Every path is deep-linkable and resolves to
a real screen; feature-flagged/experimental routes resolve to a branded
"coming soon" surface so deep links never break (prompt 31 §G).

## A. Auth & onboarding
| Path | Screen |
|------|--------|
| `/splash` | Splash |
| `/onboarding` | Onboarding stepper |

## B. Shell branch 1 — Home
| Path | Screen |
|------|--------|
| `/home` | Hub (greeting, streak/XP, **Today plan**, quests, quick-access, 12 tiles) |
| `/review` | Unified Daily Review (SRS) |
| `/search` | Global search |
| `/copilot` · `/copilot/:threadId` | Copilot chat (grounded, cited, safety-guarded) |
| `/concept/:conceptId` | Concept hub — cross-module "See also" |
| `/plan` · `/plan/track/:trackId` | Adaptive Study Plan + curriculum tracks |
| `/insights` · `/profile/stats` | Learner dashboard (heatmap, readiness, forecast) |
| `/cases` · `/cases/:caseId` | Virtual Patient encounters |

## C. Shell branch 2 — Learn
**Terms** `/learn/terms` · `/learn/terms/unit/:unitId` · `/learn/terms/lesson/:lessonId` ·
`/learn/terms/practice` · `/learn/terms/stories` · `/learn/terms/leaderboard`
**Cards** `/learn/cards` · `/learn/cards/deck/:deckId` · `/learn/cards/deck/:deckId/edit` ·
`/learn/cards/card/:cardId/edit` · `/learn/cards/graph` · `/learn/cards/study` · `/learn/cards/import`
**Mnemonics** `/learn/mnemonics` · `/learn/mnemonics/:mnemonicId` · `/learn/mnemonics/new` ·
`/learn/mnemonics/collections(/:collectionId)` · `/learn/mnemonics/mine` ·
`/learn/mnemonics/tag/:tagId` · `/learn/mnemonics/search`

## D. Shell branch 3 — Clinical
**ECG** `/clinical/ecg` · `/clinical/ecg/drill` · `/clinical/ecg/review` · `/clinical/ecg/case/:caseId` ·
`/clinical/ecg/generative` *(flag)* · `/clinical/ecg/stats`
**Sounds** `/clinical/sounds` · `/clinical/sounds/library` · `/clinical/sounds/:soundId` ·
`/clinical/sounds/quiz` · `/clinical/sounds/simulator` *(flag)* · `/clinical/sounds/stats`
**Labs** `/clinical/labs` · `/clinical/labs/panel/:panel` · `/clinical/labs/result/:evaluationId` ·
`/clinical/labs/history` · `/clinical/labs/ruleset` · `/clinical/labs/learn`
**Algorithms** `/clinical/algorithms` · `/clinical/algorithms/:algorithmId` ·
`/clinical/algorithms/:algorithmId/play` · `/clinical/algorithms/:algorithmId/edit` ·
`/clinical/algorithms/new` · `/clinical/algorithms/sessions` · `/clinical/algorithms/bookmarks`
**OR Lab** `/clinical/or-lab` · `/clinical/or-lab/:dramaId` · `/clinical/or-lab/:dramaId/play` ·
`/clinical/or-lab/:dramaId/sim` *(flag)* · `/clinical/or-lab/:dramaId/transcript`
**OSCE** `/clinical/osce` · `/clinical/osce/:stationId` · `/clinical/osce/:stationId/play`

## E. Shell branch 4 — Social
**Rounds** `/social/rounds` · `/social/rounds/discover` · `/social/rounds/record` ·
`/social/rounds/:roundId` · `/social/rounds/:roundId/comments` · `/social/rounds/:roundId/remix`
**Buddies** `/social/buddies` · `/social/buddies/discover` · `/social/buddies/requests` ·
`/social/buddies/matches` · `/social/buddies/:userId` · `/social/buddies/groups(/:groupId)`
**Arena** `/social/arena` · `/social/arena/battle` · `/social/arena/deck` · `/social/arena/collection` ·
`/social/arena/capsules` · `/social/arena/shop` · `/social/arena/clan(/:clanId)` ·
`/social/arena/leaderboard` · `/social/arena/season` · `/social/arena/replay/:replayId`
**Community** `/social/rooms` · `/social/rooms/:roomId` · `/social/community` · `/social/events` ·
`/social/leaderboard`

## F. Shell branch 5 — Profile & global account
`/profile` · `/profile/edit` · `/profile/stats` · `/profile/customize` · `/u/:handle` ·
`/rewards` · `/achievements` · `/quests` · `/settings` (+ `/settings/data`, `/settings/privacy`,
`/settings/redeem`, `/settings/subscription`) · `/legal/:doc` · `/inbox` · `/notifications` ·
`/chat` · `/chat/:threadId`

## G. Library (reference banks — Part III)
`/library` · `/library/diseases` · `/library/diseases/:id` · `/library/diseases/compare?ids=` ·
`/library/drugs` · `/library/drugs/:id` · `/library/drugs/class/:classId` ·
`/library/drugs/interactions` · `/library/tools` · `/library/tools/:id` ·
`/library/atlas(/:id)` · `/library/imaging(/:id)` · `/library/procedures(/:id)` ·
`/library/guidelines(/:id)` · `/library/journal(/:id)`

## H. Monetization, CMS & institutional
`/pro` · `/shop` · `/create` · `/admin` (+ `/admin/content`, `/admin/review`, `/admin/users`,
`/admin/flags`) · `/classes` · `/org` · `/integrations`

## Conventions
- Typed params and helpers (`Routes.disease(id)`, `context.goConcept(id)`).
- Adaptive: `NavigationBar` (compact) → `NavigationRail` → extended rail (desktop);
  list/detail use `TwoPaneScaffold` on wide layouts.
- Command palette (⌘K / Ctrl-K) is an overlay over the whole map (no route).
- Every reference/library item is Concept-anchored and appears on `/concept/:id`.
