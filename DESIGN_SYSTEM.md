# 斗地主计分牌 Design System

## Overview

This document defines the design language for the Dou Di Zhu (斗地主 - Fight the Landlord) scoring app. All future development should follow these guidelines to maintain visual consistency and optimal user experience.

---

## 1. Color Palette

### Primary Colors
The app uses a dark theme with purple as the primary accent color.

```swift
// Brand Colors
primary      = #5E00F5  // Deep purple - main actions
primary500   = #7722FF  // Bright purple - interactive elements
primary20    = #924EFF  // Light purple - highlights
primary10    = #AD7BFF  // Lighter purple - secondary highlights
primary5     = #C9A7FF  // Pale purple - subtle accents
primary0     = #E4D3FF  // Very pale purple - backgrounds
```

### Semantic Colors (NEW)
These colors are used to indicate game outcomes and states:

```swift
// Win/Lose Indicators (replacing confusing red/green toggle)
winColor     = #FFD700  // Gold - positive scores/wins
loseColor    = #FF6B6B  // Coral red - negative scores/losses
neutralColor = #FFFFFF  // White - zero/neutral

// Role Indicators
landlordColor    = #FFB800  // Amber - landlord indicator
farmerColor      = #4CAF50  // Green - farmer indicator

// State Colors
successColor     = #4CAF50  // Green - success states
warningColor     = #FF9800  // Orange - warning states
errorColor       = #F44336  // Red - error states
```

### Gray Scale (Background & Text)
```swift
grayC   = #0E0E12  // Darkest - main background
gray80  = #1C1C23  // Dark - card backgrounds
gray70  = #353542  // Medium dark - borders, dividers
gray60  = #4E4E61  // Medium - disabled states
gray50  = #666680  // Medium light - secondary text
gray40  = #83839C  // Light - tertiary text
gray30  = #A2A2B5  // Lighter - placeholder text
gray20  = #C1C1CD  // Very light - subtle elements
gray10  = #E0E0E6  // Near white - highlights
```

---

## 2. Typography

### Font Family
The app uses **Inter** font family with the following weights:
- Regular (400) - Body text
- Medium (500) - Emphasized text
- SemiBold (600) - Section headers, buttons
- Bold (700) - Titles, important numbers

### Type Scale
```swift
// Titles
largeTitle   = 34pt Bold      // Screen titles
title1       = 28pt Bold      // Major sections
title2       = 22pt SemiBold  // Section headers
title3       = 20pt SemiBold  // Subsections

// Body
headline     = 17pt SemiBold  // List item titles
body         = 17pt Regular   // Main content
callout      = 16pt Regular   // Supporting text
subheadline  = 15pt Regular   // Secondary info

// Small
footnote     = 13pt Regular   // Metadata
caption1     = 12pt Regular   // Labels
caption2     = 11pt Regular   // Small labels
```

---

## 3. Spacing & Layout

### Spacing Scale
```swift
xxs = 4pt   // Tight spacing within components
xs  = 8pt   // Small gaps
sm  = 12pt  // Component padding (vertical)
md  = 16pt  // Component padding (horizontal)
lg  = 20pt  // Section spacing
xl  = 24pt  // Large section spacing
xxl = 32pt  // Screen edge margins
```

### Corner Radius
```swift
small  = 8pt   // Small buttons, badges
medium = 12pt  // Cards, input fields
large  = 16pt  // Large cards, sheets
full   = 9999  // Pills, circular elements
```

---

## 4. Components

### 4.1 Buttons

#### Primary Button
- Background: Linear gradient from `primary500` to `primary`
- Text: White, SemiBold, 14pt
- Height: 48pt
- Corner radius: 12pt (medium)
- Shadow: primary color with 20% opacity, y: 4pt, blur: 12pt

#### Secondary Button
- Background: `gray80`
- Border: 1pt `gray70`
- Text: White, SemiBold, 14pt
- Height: 48pt
- Corner radius: 12pt (medium)

#### Toggle Button (for 加倍 / 春天)
- Off state: `gray70` background, `gray40` text
- On state: `primary500` background, white text
- Height: 36pt
- Corner radius: 8pt (small)

### 4.2 Cards

#### Game Row Card
- Background: `gray80`
- Padding: 12pt vertical, 16pt horizontal
- Corner radius: 12pt
- Scores displayed with semantic colors:
  - Positive: `winColor` (gold)
  - Negative: `loseColor` (coral)
  - Zero: white
- Landlord indicator: Crown icon or `landlordColor` accent

#### Stat Card
- Background: `gray80` with 30% opacity
- Padding: 16pt
- Corner radius: 12pt
- Title: headline style
- Values: title2 or title3 style with semantic colors

### 4.3 Input Fields

#### Round Text Field
- Background: `gray60` at 5% opacity
- Border: 1pt `gray70`
- Corner radius: 12pt
- Padding: 15pt
- Text: White
- Label: `gray50`, caption1

#### Picker (Bid Selection)
- Style: Segmented control
- Selected: `primary500` background
- Unselected: `gray80` background
- Text: White
- Height: 36pt

### 4.4 Score Display

#### Single Game Score
- Use semantic `winColor`/`loseColor` instead of configurable red/green
- Landlord's score is always more prominent (bold)
- Show role indicator (👑 for landlord)

#### Cumulative Score
- Positive: Gold (#FFD700)
- Negative: Coral (#FF6B6B)
- Zero: White

---

## 5. UX Guidelines

### 5.1 First Bidder Logic (SIMPLIFIED)
**Previous (confusing)**: User manually selects who starts bidding, hidden in settings.

**New approach**: 
- First bidder automatically rotates each round (A → B → C → A...)
- Visual indicator shows whose turn to bid first with a subtle highlight
- Starting player for the session can be set once at match start (not hidden in settings)

### 5.2 Win/Lose Color Indication
**Previous (confusing)**: Toggle between "绿色为赢" and "红色为赢" - this causes confusion.

**New approach**:
- Always use **Gold (#FFD700)** for positive scores/wins
- Always use **Coral (#FF6B6B)** for negative scores/losses
- Remove the toggle entirely - consistent colors across all users
- Universal understanding: Gold = Good, Red = Bad

### 5.3 Landlord Identification
- Add crown icon (👑) next to landlord's name/score
- Use `landlordColor` (amber) accent for landlord-related UI elements
- Clear visual distinction between landlord and farmers

### 5.4 Game Entry Flow (AddColumn)
1. **Bid Selection**: Three columns, each player picks their bid (不叫/1分/2分/3分)
   - Highlight current bidder (based on rotation)
   - Auto-detect landlord based on highest bid
2. **Modifiers**: Horizontal row for 加倍, 炸弹, 春天
3. **Result**: Single toggle for 地主赢/输
4. **Confirm**: Clear primary button

### 5.5 Navigation & Information Architecture
- **Tab 1 (对局)**: Current match - primary focus
- **Tab 2 (历史)**: Past matches - secondary
- **Tab 3 (统计)**: Player stats - tertiary

---

## 6. Iconography

### System Icons Used
```swift
"house.fill"              // 对局 tab
"clock.arrow.circlepath"  // 历史 tab
"chart.bar.fill"          // 统计 tab
"gear"                    // Settings
"plus"                    // Add new
"trash.fill"              // Delete
"pencil"                  // Edit
"crown.fill"              // Landlord indicator (NEW)
"person.circle.fill"      // Player avatar
"chevron.right"           // Navigation disclosure
"chevron.down"            // Dropdown indicator
```

---

## 7. Animation Guidelines

### Transitions
- Sheet presentation: Default iOS spring animation
- List item appearance: Fade in from 0.8 opacity
- Score updates: Scale bounce (1.0 → 1.1 → 1.0) over 0.3s

### Feedback
- Button press: Scale to 0.97 with 0.1s duration
- Toggle: Color transition over 0.2s
- Success: Subtle haptic feedback (impact light)

---

## 8. Accessibility

### Color Contrast
- All text maintains WCAG AA compliance (4.5:1 for small text, 3:1 for large)
- Score colors have alternative pattern indicators for colorblind users

### Touch Targets
- Minimum 44pt × 44pt for all interactive elements
- Adequate spacing between adjacent touch targets

### VoiceOver
- All interactive elements have descriptive labels
- Game outcomes announced clearly (e.g., "地主 张三 赢得 400 分")

---

## 9. Implementation Notes

### Color Extension Updates Needed
Add to `UIExtension.swift`:
```swift
// Semantic colors for game outcomes
static var winColor: Color { Color(hex: "FFD700") }
static var loseColor: Color { Color(hex: "FF6B6B") }
static var landlordColor: Color { Color(hex: "FFB800") }
static var farmerColor: Color { Color(hex: "4CAF50") }
```

### Remove from Settings
- "绿色为赢/红色为赢" toggle - no longer needed

### String Extension Update
Replace the confusing `color` computed property:
```swift
// Old (remove)
var color: Color {
    switch self {
    case "green": return DataSingleton.instance.greenWin ? .green : .red
    case "red": return DataSingleton.instance.greenWin ? .red : .green
    default: return .white
    }
}

// New (add)
var scoreColor: Color {
    switch self {
    case "win": return .winColor
    case "lose": return .loseColor
    default: return .white
    }
}
```

---

## Changelog

### Version 1.0 (Current Redesign)
- Established design system documentation
- Defined semantic color system for scores
- Simplified first-bidder UX logic
- Removed confusing red/green color toggle
- Added landlord visual indicators
- Standardized component specifications
