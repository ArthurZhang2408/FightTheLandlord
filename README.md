# 斗地主计分 · Fight the Landlord Scorekeeper

An iOS app (SwiftUI, iOS 17+) for keeping score in 斗地主 (Dou Di Zhu). It records every game of a sitting, keeps a synced history across devices through Firebase Firestore, and turns the records into player statistics and shareable posters.

## What the app does

- **计分板 (Match tab)** – pick three players, tap “记一局” for each round: bids, doubles, bombs, spring and who won. The score is computed live before you save. Running totals, per-round list and a trend chart update instantly.
- **Auto-save / auto-finish** – the board is persisted on every change. Leaving the app mirrors the sitting into History as “进行中”. After a configurable idle period (default 2 hours) the match is closed automatically. Any match, closed or not, can be reopened from History with “继续这场对局”.
- **历史 (History tab)** – matches grouped by year and month (collapsible), with busy days (3+ matches) grouped further; searchable by player. A match page shows results, every round (editable), the trend, per-player performance and a detailed breakdown; it can be shared, continued or deleted.
- **统计 (Stats tab)** – a leaderboard (总分 / 胜率 / 局数 / 场胜率) and a per-player page in three parts: 概览 (form, score trend, rolling win rate, monthly net score), 风格 (early / middle / recent slices of the career, win rate by situation, roles, bidding, specials) and 纪录 (records, partners and rivals, activity). Every record and every chart point links to the match or game behind it. A comparison chart overlays several players' scores or rolling win rates.
- **分享** – deterministic light or dark posters rendered from fixed-palette views (charts drawn with `Canvas`), saved to Photos or shared with the system sheet.

## Architecture

```
FightTheLandloard.xcodeproj
FightTheLandloardTests/ XCTest cases for the engines
FightTheLandloard/
Models/                 Pure value types + engines (no UI, no Firebase calls)
  Seat, Game, ActiveMatch, Player, GameRecord, MatchRecord
  Scoring/ScoreCalculator          single source of truth for 斗地主 scoring
  Statistics/PlayerStatsEngine     PlayerStatistics from records
  Statistics/MatchStatsEngine      MatchStatistics for one match
  Statistics/Leaderboard           cross-player ranking
Other/Services/         Local-first data layer
  LocalCacheManager     JSON cache in Documents/SyncCache, in-memory game records
  PendingOperationQueue offline operation log with backoff
  SyncManager           Firestore listeners, preload, upsert/delete, replay queue
  DataStore             @MainActor @Observable facade used by views
  NetworkMonitor        NWPathMonitor wrapper
ViewModels/             Observable app state
  MatchSession          the match on the board: edits, persistence, auto-save,
                        auto-finish, resume
  AppSettings           user preferences (UserDefaults)
  AppRouter             cross-tab navigation
UICommon/               Theme tokens, components, charts, share posters
Views/                  Match / History / Stats / Players / Settings screens
```

### Scoring rules (unchanged)

```
base      = 100 × highest bid
base     ×= 2 for every bomb
base     ×= 2 if 春天
base     ×= 2 if the landlord doubled
farmer_i  = base × 2 if that farmer doubled, else base
landlord  = farmer_1 + farmer_2
```
The losing side pays. Bidding validation rejects a round where nobody bid or where two players hold the same top bid.

### Firestore schema

Collections `players`, `matches`, `gameRecords` keep their original field names. Two optional fields were added to `matches`: `autoEnded: Bool?` and `lastActivityAt: Date?`. Old documents decode unchanged. Matches are written with client-generated ids so auto-saves and the final save update one document.

### Match lifecycle

1. `MatchSession` persists `ActiveMatch` to `UserDefaults` on every change (`active_match_v2`; the old `current_match_state` blob is migrated on first launch).
2. On `.background`/`.inactive` the match is upserted into history with `endedAt == nil` (“进行中”). Subsequent edits re-sync with a 1.5 s debounce.
3. On `.active` and every minute while running, `checkIdle()` closes the match when `lastActivityAt` is older than the configured timeout (`endedAt = lastActivityAt`, `autoEnded = true`) and clears the board. A banner offers to continue it.
4. “继续这场对局” loads the records back onto the board and reopens the history entry.
5. First bidder: every new match (including “沿用上次玩家，再开一场”) starts with seat A; each game then passes to the next seat. A round nobody bids on is not recorded and rotates the first bidder once more; the seat menu on the board sets it explicitly, and the 换位 button on the scoreboard card moves everyone one seat to the left (A, B, C → B, C, A) with every per-seat value following its player, so it can be used before or during a match. `MatchSession` reads `nextFirstBidder` into a local before writing `active` (an optional-chain write whose right-hand side reads the same `@Observable` property is an exclusivity trap at runtime).

## Building

- Open `FightTheLandloard.xcodeproj` at the repository root. The app sources live in `FightTheLandloard/`, unit tests in `FightTheLandloardTests/`, UI tests in `FightTheLandloardUITests/`. All three are synchronized folder groups, so new files are picked up automatically.
- Requires the Firebase SDK (FirebaseCore, FirebaseFirestore, resolved through Swift Package Manager) and a `GoogleService-Info.plist` in `FightTheLandloard/Other/` (git-ignored, never commit it).
- Deployment target iOS 17.5, Swift 5 language mode.
- The project's build settings already provide `NSPhotoLibraryAddUsageDescription` (“保存到相册”) and landscape orientations on iPhone, which the fullscreen chart uses through `OrientationController` and the app delegate's `supportedInterfaceOrientationsFor`; every other screen stays portrait.
- Unit tests for the scoring and statistics engines are in `FightTheLandloardTests/`; run them with ⌘U.

## Development notes

- Keep `Models/` free of SwiftUI so the engines stay testable; UI colors for `PlayerColor` live in `UICommon/Theme.swift`.
- All score colors go through `AppTheme.scoreColor(_:greenWin:)`; the green/red preference is a setting, never hard-coded.
- Posters must not use dynamic system colors or Dynamic Type; use `PosterTheme`.
- See `DESIGN_SYSTEM.md` for the visual language.
