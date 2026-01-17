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

## 3. Layout Architecture (Complete Redesign)

### 3.1 Main Tab Structure
```
┌──────────────────────────────────────────┐
│  Tab 1: 当前对局 (Current Match)          │
│  - Score summary card at top             │
│  - Game history list below               │
│  - FAB for adding new game               │
├──────────────────────────────────────────┤
│  Tab 2: 历史记录 (Match History)          │
│  - List of completed matches             │
│  - Expandable for game details           │
├──────────────────────────────────────────┤
│  Tab 3: 玩家统计 (Player Stats)           │
│  - Player cards with statistics          │
│  - Drill-down for details                │
└──────────────────────────────────────────┘
```

### 3.2 Current Match View (NEW Layout)
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
│ 局数记录                                  │
│ ┌────────────────────────────────────┐   │
│ │ 第1局   👑+200    -100    -100     │   │
│ ├────────────────────────────────────┤   │
│ │ 第2局    -100   👑+200    -100     │   │
│ ├────────────────────────────────────┤   │
│ │ 第3局    +400    -200   👑-200     │   │
│ └────────────────────────────────────┘   │
│                                          │
│              [＋ 添加新局]                │
└──────────────────────────────────────────┘
```

### 3.3 Add Game Flow (NEW Interaction)
Instead of a complex form, use a step-by-step flow:

**Step 1: Select Landlord**
```
┌──────────────────────────────────────────┐
│ 谁是地主？                     [取消]    │
├──────────────────────────────────────────┤
│                                          │
│   ┌─────────┐ ┌─────────┐ ┌─────────┐   │
│   │  玩家A  │ │  玩家B  │ │  玩家C  │   │
│   │   👑    │ │         │ │         │   │
│   └─────────┘ └─────────┘ └─────────┘   │
│                                          │
│         [下一步: 设置叫分]                │
└──────────────────────────────────────────┘
```

**Step 2: Set Bid & Multipliers**
```
┌──────────────────────────────────────────┐
│ 游戏参数                       [返回]    │
├──────────────────────────────────────────┤
│                                          │
│  叫分 (底分)                             │
│  ┌───────┬───────┬───────┬───────┐      │
│  │  1分  │  2分  │  3分  │  不叫  │      │
│  └───────┴───────┴───────┴───────┘      │
│                                          │
│  炸弹数量         [  0  ] [-] [+]        │
│                                          │
│  特殊情况                                │
│  ┌──────────┐  ┌──────────┐             │
│  │   春天   │  │  加倍    │             │
│  └──────────┘  └──────────┘             │
│                                          │
│         [下一步: 输入结果]                │
└──────────────────────────────────────────┘
```

**Step 3: Enter Result**
```
┌──────────────────────────────────────────┐
│ 比赛结果                       [返回]    │
├──────────────────────────────────────────┤
│                                          │
│            谁赢了？                       │
│                                          │
│   ┌───────────────────────────────┐      │
│   │         👑 地主赢了            │      │
│   └───────────────────────────────┘      │
│                                          │
│   ┌───────────────────────────────┐      │
│   │         🌾 农民赢了            │      │
│   └───────────────────────────────┘      │
│                                          │
│               [完成]                      │
└──────────────────────────────────────────┘
```

---

## 4. Components (Apple HIG Style)

### 4.1 Score Card
- Use **Card** style with rounded corners (16pt)
- System background with slight elevation
- Large, prominent numbers using `.largeTitle` font
- Color coded based on user preference (green/red toggle)

### 4.2 Game Row
- Use **Inset Grouped List** style
- Crown emoji (👑) for landlord indicator
- Swipe actions for edit/delete
- Subtle dividers between rows

### 4.3 Buttons
- Use system button styles (`.borderedProminent`, `.bordered`)
- Follow iOS sizing (44pt minimum touch target)
- Appropriate tint colors

### 4.4 Pickers & Toggles
- Use native iOS Picker with `.segmented` style
- Use native Toggle for boolean options
- Stepper for numeric values (bomb count)

### 4.5 Navigation
- Use NavigationStack for modern navigation
- Modal sheets for add/edit flows
- Confirmation dialogs for destructive actions

---

## 5. Typography

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

## 6. Interaction Patterns

### 6.1 Adding a Game
- Tap floating "+" button
- Step-by-step wizard (3 steps)
- Progress indicator at top
- Can go back to previous step
- Clear completion confirmation

### 6.2 Editing a Game
- Swipe left on row → Edit
- Same wizard flow, pre-populated
- Clear "Save" vs "Cancel" options

### 6.3 Ending a Match
- Prominent "结束对局" button in toolbar
- Confirmation dialog with summary
- Automatic save to history

### 6.4 Settings
- Use Form/List with grouped sections
- Immediate feedback on changes
- Clear labels and descriptions

---

## 7. Iconography (SF Symbols)

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
```

---

## 8. Animation

Follow iOS system animations:
- Sheet presentation: System spring
- List updates: Automatic animations
- Button feedback: System haptics
- Score changes: Number transition

---

## 9. Accessibility

### 9.1 VoiceOver
- All controls properly labeled
- Score announcements are clear
- Navigation hints provided

### 9.2 Dynamic Type
- Support all text sizes
- Layouts adapt to larger text
- Minimum font size: 11pt

### 9.3 Color
- Don't rely solely on color for meaning
- Use icons alongside colors
- Support reduced transparency

---

## Changelog

### Version 2.0 (Apple HIG Redesign)
- Complete redesign following Apple HIG
- New step-by-step game entry flow
- Score card summary at top of match view
- Retained user-configurable green/red color preference
- Native iOS components throughout
- Improved visual hierarchy and clarity
