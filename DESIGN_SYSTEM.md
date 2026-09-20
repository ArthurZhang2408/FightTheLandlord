# Design System · 斗地主计分

The app is a tool people keep open at a card table for hours. The visual language is therefore quiet and precise: one accent, generous numerals, system surfaces, no decoration that competes with the scores.

## Principles

1. **Numbers first.** Scores use rounded, monospaced numerals and are the largest element on every card.
2. **One accent.** 朱砂 vermilion (`AppTheme.accent`) marks primary actions and the current stake. Nothing else is orange.
3. **Roles are colors, not words.** 地主 is gold, 农民 is jade, everywhere (rows, badges, charts, posters).
4. **Win / lose is a preference.** Positive scores are green or red depending on `AppSettings.greenWin`; zero is neutral grey. Always call `AppTheme.scoreColor`.
5. **System surfaces.** Grouped backgrounds, hairline borders, continuous corners. Cards never cast heavy shadows; only floating actions do.
6. **Calm motion.** Numeric transitions on scores, short ease-outs. No looping ambient animation.

## Tokens (`UICommon/Theme.swift`)

| Token | Light | Dark | Use |
| --- | --- | --- | --- |
| `accent` | #B5432F | #E06A55 | primary buttons, stake 3分, first bidder |
| `gold` | #A9832B | #D8B15A | landlord, winner crown, stake 2分 |
| `jade` | #2C8A66 | #5DBD96 | farmer, “进行中”, stake 1分 |
| `green` / `red` | #2D8F58 / #C4392F | #4FC47C / #E5675C | score sign colors (mapped by preference) |
| `background` / `surface` / `surfaceSecondary` | system grouped | system grouped | page / card / tile |
| `hairline` | separator 55% | separator 55% | card borders, dividers |

Spacing scale: 4 / 8 / 12 / 16 / 24 / 32. Radii: 8 (tiles), 12 (buttons, tiles), 16 (cards), 22 (hero cards).

Type: SF Pro. Scores: `AppFont.score(size)` (rounded, bold). Section titles: footnote semibold, secondary color, no uppercase transform.

Player colors (`PlayerColor.color`) are eight refined hues that stay legible on both appearances.

## Components (`UICommon/Components.swift`)

- `card()` – surface + continuous corner + hairline border.
- `SectionHeader` – title, optional subtitle, optional trailing control.
- `PlayerAvatar` – initial on a tinted circle; `emphasized` fills it (winners).
- `ScoreText` – signed, colored, numeric transition.
- `StatTile`, `StatRowItem` – tile grids and list rows for statistics.
- `Chip`, `RoleBadge`, `FormDots`, `MiniBar`, `WinRateRing`.
- `EmptyStateView`, `InfoBanner`, `SkeletonBlock`/`SkeletonList`.
- `PrimaryButtonStyle`, `SecondaryButtonStyle`.

## Screens

- **计分板** – hero scoreboard card (seat pickers + totals + next bidder), reverse-chronological round list, trend card, summary tiles, floating “记一局”. Idle state offers “开始新牌局”, “沿用上次玩家，再开一场”, a “继续上一场对局” link and a resume banner for auto-ended or in-progress matches.
- **记一局** – form: bids per seat (segmented) with 加倍 toggle, bombs stepper, 春天, result, live score preview and multiplier explanation.
- **历史** – collapsible year (when more than one) and month sections; a day with three or more matches becomes its own collapsible group, quieter days list their rows straight under the month with the date on the row. Rows carry badges (进行中 / 自动结束) and three score capsules; winner marked with a crown.
- **对局详情** – header (ranked players, peak/valley, quick facts), round list (tap to edit), trend, player performance, actions in an ellipsis menu (继续 / 详细统计 / 删除), share button.
- **统计** – leaderboard with metric picker; player page in three segments: 概览 (rings, form, trend 按局/按场/状态, monthly bars), 风格 (early/middle/recent slices with date ranges and a one-line reading, win rate by situation, roles, bidding, specials), 纪录 (record rows that open the match or game, partners & rivals, activity). Record rows share one 44pt height and show a chevron when they link somewhere; the target row in 对局详情 flashes for about two seconds.
- **分享海报** – fixed 390pt width, 3× scale, light/dark `PosterTheme`, `Canvas` charts, never dynamic colors.

## Charts

- Compact charts: lines only, monotone interpolation, dashed zero line, soft grid, legend chips. Tap or the expand button opens the fullscreen chart.
- Fullscreen: landscape. The x scale's domain is a window the view owns (no scrollable axes): drag pans it, pinch or the +/− toolbar buttons resize it, and a tap on the plot selects the nearest point. The selected point's values sit in a panel under the chart, one chip per series; a chip with a chevron opens that game or match. Percent series (rolling win rate) use the same component with a percent value style and a labelled reference line.
- Colors come from the players; never from a chart default palette.

## Copy

Simplified Chinese, short and factual. Prefer verbs on buttons (“记一局”, “结束”, “继续这场对局”). Destructive actions always confirm and name what is lost.
