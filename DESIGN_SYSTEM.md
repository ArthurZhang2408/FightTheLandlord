# 斗地主计分牌 Design System

## Overview

This document defines the design language for the Dou Di Zhu (斗地主 - Fight the Landlord) scoring app, following **Apple's Human Interface Guidelines (HIG)** for iOS. All future development should follow these guidelines to maintain visual consistency and optimal user experience.

---

## 1. Design Principles (Apple HIG)

### 1.1 Clarity
- Content is paramount - score data is front and center
- Use system fonts for readability (SF Pro)
- Use appropriate text sizes with Dynamic Type support
- Clear visual hierarchy between primary and secondary information

### 1.2 Deference
- UI elements support the content, not compete with it
- Use translucent materials where appropriate
- Let the score data shine

### 1.3 Depth
- Use layered interfaces for modals and sheets
- Maintain clear visual hierarchy through shadows and blur

---

## 2. Color System

### 2.1 Score Colors (User Configurable)
The app supports two color modes for displaying win/lose scores, configurable in Settings:

**Mode 1: 绿色为赢 (Green = Win)**
```swift
winColor  = .green   // System green for positive scores
loseColor = .red     // System red for negative scores
```

**Mode 2: 红色为赢 (Red = Win)**  
```swift
winColor  = .red     // System red for positive scores
loseColor = .green   // System green for negative scores
```

This flexibility respects Chinese cultural preferences where red often represents prosperity.

### 2.2 Role Colors
```swift
landlordColor = .orange  // System orange - landlord indicator
farmerColor   = .blue    // System blue - farmer indicator
```

### 2.3 System Colors
Follow iOS semantic colors for adaptability to Light/Dark mode:
```swift
.primary            // For primary text and icons
.secondary          // For secondary text
.tertiaryLabel      // For hints and placeholders
.systemBackground   // For backgrounds
.secondarySystemBackground  // For grouped content
.systemGroupedBackground    // For inset grouped lists
```

---

## 3. Layout Architecture

### 3.1 Main Tab Structure
```
┌──────────────────────────────────────────┐
│  Tab 1: 当前对局 (Current Match)          │
│  - Score summary card at top             │
│  - Player picker section                 │
│  - Game history list below               │
│  - FAB for adding new game               │
├──────────────────────────────────────────┤
│  Tab 2: 历史记录 (Match History)          │
│  - List of completed matches             │
│  - Expandable for game details           │
│  - Player statistics for each match      │
├──────────────────────────────────────────┤
│  Tab 3: 玩家统计 (Player Stats)           │
│  - Player list with avatars              │
│  - Drill-down for detailed statistics    │
│  - Charts for visual data representation │
└──────────────────────────────────────────┘
```

### 3.2 Current Match View
```
┌──────────────────────────────────────────┐
│ 当前对局                    [设置] [结束]  │
├──────────────────────────────────────────┤
│ ┌────────────────────────────────────┐   │
│ │    Score Summary Card               │   │
│ │  ┌────────┬────────┬────────┐      │   │
│ │  │ 玩家A  │ 玩家B  │ 玩家C  │      │   │
│ │  │  +800  │  -400  │  -400  │      │   │
│ │  └────────┴────────┴────────┘      │   │
│ └────────────────────────────────────┘   │
│                                          │
│ 选择玩家                                  │
│ ┌────────┬────────┬────────┐            │
│ │ 选A... │ 选B... │ 选C... │            │
│ └────────┴────────┴────────┘            │
│                                          │
│ 局数记录                                  │
│ ┌────────────────────────────────────┐   │
│ │ 1 │ 👑+200    -100    -100      ⋮ │   │
│ ├────────────────────────────────────┤   │
│ │ 2 │  -100   👑+200    -100      ⋮ │   │
│ └────────────────────────────────────┘   │
│                                          │
│        [＋ 添加新局]                      │
└──────────────────────────────────────────┘
```

### 3.3 Add Game Flow (Single-Page Form)
Uses a native iOS Form with sections for clarity:

```
┌──────────────────────────────────────────┐
│ 添加新局                [取消]   [完成]   │
├──────────────────────────────────────────┤
│                                          │
│ ⚠️ 本局由 玩家A 先叫分                    │
│                                          │
│ ─── 叫分 ───                             │
│                                          │
│ 玩家A [先叫]                              │
│ [不叫] [1分] [2分] [3分]                 │
│                                          │
│ 玩家B                                    │
│ [不叫] [1分] [2分] [3分]                 │
│                                          │
│ 玩家C                                    │
│ [不叫] [1分] [2分] [3分]                 │
│                                          │
│ 👑 玩家A 成为地主                         │
│                                          │
│ ─── 倍数 ───                             │
│                                          │
│ 炸弹数量              [-] 0 [+]          │
│ 春天                        [ ]          │
│                                          │
│ ─── 加倍 ───                             │
│                                          │
│ 玩家A加倍                   [ ]          │
│ 玩家B加倍                   [ ]          │
│ 玩家C加倍                   [ ]          │
│                                          │
│ ─── 结果 ───                             │
│                                          │
│ [  地主赢了  |  农民赢了  ]               │
│                                          │
└──────────────────────────────────────────┘
```

**Special Feature: Auto-Advance First Bidder**
When no one bids (all select "不叫"), clicking "完成" will:
1. Close the form without adding a game
2. Automatically advance the first bidder to the next player
3. Show a hint at the footer: "⚠️ 没人叫分，点击完成将自动轮换到下一位玩家先叫"

---

## 4. UX Logic

### 4.1 Player Selection Validation
**Before saving a match:**
- All 3 players (A, B, C) must be selected
- If not, show alert: "请为位置A、B、C都选择玩家后再保存牌局"
- Match will NOT be saved if players are not selected

### 4.2 First Bidder Rotation
- First bidder rotates automatically: A → B → C → A
- Calculated as: `(gameCount + initialStarter) % 3`
- When no one bids, advance starter to next player

### 4.3 Score Color Logic
The color is determined by the score value AND the user's `greenWin` setting:
```swift
private func scoreColor(_ score: Int) -> Color {
    if score == 0 { return .primary }
    let isPositive = score > 0
    if dataSingleton.greenWin {
        return isPositive ? .green : .red
    } else {
        return isPositive ? .red : .green
    }
}
```

---

## 5. Components (Apple HIG Style)

### 5.1 Score Card
- Use **Card** style with rounded corners (16pt)
- System background with slight elevation
- Large, prominent numbers using `.title2` font
- Color coded based on user preference (green/red toggle)

### 5.2 Game Row
- Use **Inset Grouped List** style
- Crown emoji (👑) for landlord indicator
- Swipe actions for edit/delete
- Subtle dividers between rows
- Score colors based on win/lose + user preference

### 5.3 Buttons
- Use system button styles (`.borderedProminent`, `.bordered`)
- Follow iOS sizing (44pt minimum touch target)
- Appropriate tint colors

### 5.4 Pickers & Toggles
- Use native iOS Picker with `.segmented` style for bids
- Use native Toggle for boolean options (spring, double)
- Custom +/- buttons for bomb count

### 5.5 Navigation
- Use NavigationStack for modern navigation
- Modal sheets for add/edit flows
- Confirmation dialogs for destructive actions

### 5.6 Charts (iOS 16+)
- Pie chart for win rate overview
- Bar chart for role comparison (landlord vs farmer)
- Bar chart for bid distribution
- Fallback views for older iOS versions

---

## 6. Statistics Display

### 6.1 Player Statistics (Consistent Style)
Both the Stats tab and History tab use consistent styling:

**Structure:**
1. Win Rate Pie Chart (visual overview)
2. Overall Statistics section
3. Role Comparison Bar Chart
4. Role Statistics section
5. Special Statistics section (spring, double)
6. Streak Statistics section
7. Bid Distribution Chart (if applicable)
8. Match Statistics section
9. Score Records section

**Each stat row includes:**
- Icon on the left (SF Symbol)
- Label text
- Value on the right
- Optional color coding for values

### 6.2 Color Coding in Statistics
- Use `scoreColor()` function for all score-related values
- Green/red based on user's `greenWin` preference
- Positive values get the "win" color
- Negative values get the "lose" color
- Zero values use primary color

---

## 7. Typography

Use SF Pro (system font) exclusively:
```swift
.largeTitle     // 34pt - Main scores
.title          // 28pt - Section headers  
.title2         // 22pt - Card titles
.headline       // 17pt semibold - Row titles
.body           // 17pt - Content
.callout        // 16pt - Supporting text
.subheadline    // 15pt - Secondary info
.footnote       // 13pt - Timestamps
.caption        // 12pt - Labels
```

---

## 8. Interaction Patterns

### 8.1 Adding a Game
- Tap floating "添加新局" button
- Single-page form (not multi-step wizard)
- Immediate validation feedback
- Clear completion confirmation
- Auto-advance first bidder when no bids

### 8.2 Editing a Game
- Tap game row or use menu → Edit
- Same form layout, pre-populated
- Clear "保存" vs "取消" options

### 8.3 Ending a Match
- Prominent "结束" button in toolbar
- Validation: all 3 players must be selected
- Confirmation dialog with summary
- Automatic save to history
- Navigate to saved match in History tab

### 8.4 Settings
- Use Form/List with grouped sections
- Immediate feedback on changes
- Clear labels and descriptions
- Color legend explanation

---

## 9. Iconography (SF Symbols)

```swift
"house.fill"              // 当前对局 tab
"clock.arrow.circlepath"  // 历史记录 tab  
"chart.bar.fill"          // 玩家统计 tab
"gearshape"               // Settings
"plus.circle.fill"        // Add new game
"trash"                   // Delete
"pencil"                  // Edit
"crown.fill"              // Landlord indicator
"person.circle.fill"      // Player avatar
"checkmark.circle.fill"   // Completion
"xmark.circle.fill"       // Cancel/Error
"hand.point.right.fill"   // First bidder indicator
"bolt.fill"               // Bombs
"sun.max.fill"            // Spring
"trophy.fill"             // Wins
"flame.fill"              // Win streak
```

---

## 10. Accessibility

### 10.1 VoiceOver
- All controls properly labeled
- Score announcements are clear
- Navigation hints provided

### 10.2 Dynamic Type
- Support all text sizes
- Layouts adapt to larger text
- Minimum font size: 11pt

### 10.3 Color
- Don't rely solely on color for meaning
- Use icons alongside colors
- Support reduced transparency

---

## Changelog

### Version 2.1 (Current)
- Single-page form instead of multi-step wizard for adding games
- Auto-advance first bidder when no one bids
- Player selection validation before saving match
- Fixed color settings applied consistently throughout app (including history)
- Added charts to statistics (pie chart, bar charts)
- Improved statistics UI with icons and consistent styling
- Color legend explanation in settings

### Version 2.0 (Apple HIG Redesign)
- Complete redesign following Apple HIG
- Score card summary at top of match view
- Retained user-configurable green/red color preference
- Native iOS components throughout
- Improved visual hierarchy and clarity
