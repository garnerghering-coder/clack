# Clack visual design system: extraction for the SwiftUI port

Source of truth: `DESIGN.md` wins on visuals (CLAUDE.md, "Which document wins"). The values below are copied verbatim
from the web app as it stands (commit `cfde6a0`). Where the code and DESIGN.md disagree, see **§0**. All `styles.css`
references are `apps/web/src/styles.css:<line>`.

> Reference for [docs/SWIFT_PORT.md](../SWIFT_PORT.md), written from the code on 2026-10-23. Line numbers drift; when this and the code disagree, the code wins.
>
> §0 below was settled on 2026-10-23: DESIGN.md now matches the code for rows 1 to 7 (the owner's later decisions). Row 8 (Passport count-up): not built on the web, leave it out unless Garner asks. Row 9: use Space Grotesk 700. Rows 10 and 11: use the radius tokens. Train art (§3.14): the family outlines are gone; see SWIFT_PORT.md B7.

---

## 0. Conflicts between code and DESIGN.md (decide before porting)

| # | DESIGN.md says | Code does | Where |
|---|---|---|---|
| 1 | Unknown band grey `#8E99A8` (§2.1, DESIGN.md:48) | `--unknown: #8e8e8e` dark, `#8a8a8a` light | styles.css:35, :90 |
| 2 | Split-flap 280 ms per digit, 40 ms stagger (§10, DESIGN.md:244) | 180 ms top leaf + 180 ms bottom leaf = 360 ms, 50 ms stagger | styles.css:609-610; SplitFlap.tsx:2, :38 |
| 3 | Basemap land `#10151D`, water `#0A0D12` (§2.4, DESIGN.md:69) | Superseded by §2.1 (DESIGN.md:37) and `map/style.ts`: dark `#151515` land / `#0a0a0a` water; light `#f7f7f7` / `#dfe2e5` | style.ts:7-36 |
| 4 | Route ahead of a live train: 35% opacity, dashed (§2.4, DESIGN.md:74) | `line-opacity: 0.8`, `line-dasharray: [1.5, 1.5]` at width 4 | style.ts:165-171 |
| 5 | Tabs: Trips, Passport, Settings (§3, DESIGN.md:83) | Tabs: Trips, Explore, Passport. Settings is a gear icon button in each page header (the "product brief §3") | AppShell.tsx:1-3, :12-16 |
| 6 | Rail network layer "off by default" (§2.4, DESIGN.md:76) | `showRailNetwork: true` default (owner, 2026-10-21) | packages/shared/src/index.ts:58-59 |
| 7 | Live train marker: ring + pulsing halo (§2.4, DESIGN.md:77) | Explore map: flat Apple-Maps-style disc, "No rings or fading (owner feedback 2026-10-21)". The trip-detail map (RouteMap) still uses the DOM marker with halo | LiveMapPage.tsx:92-125, :380; RouteMap.tsx:250-277; styles.css:426-431 |
| 8 | Count-up of Passport numbers over 900 ms (§10) | No count-up animation found in the code | (grep for rAF/setInterval in pages) |
| 9 | Big numbers "Inter Tight or Space Grotesk, 600-700" (§2.2) | Space Grotesk; weights 600 and 700 loaded, but 800 is requested in `.medal-number` (styles.css:879) and the share card (shareCard.ts:222, :261, :278), so it renders as synthesized/nearest | main.tsx:4-5 |
| 10 | "Nothing is a full pill" (§2.3) | `.wordmark-rule` `border-radius: 999px` (styles.css:144); `.phone-toggle` 999px (styles.css:568, laptop phone-frame only, not needed natively) | |
| 11 | Radii from one scale (§2.3) | Several hard-coded radii outside the tokens: `.leg-pill` 18px (:862), `.toast` 14px (:418), `.milestone` 14px (:843), `.layover` 14px (:897), `.passport-tiles > div` 14px (:525), `.station-map-title` 14px (:750), `.passport-hero` 24px (:487), `.segmented button` 9px (:237), `.side-link`/`.row select`/`.train-option`/`.share-pick`/`.level-chip` 10px, `.record`/`.route-end`/`.alt-toggle`/`.board-row.cancelled` 12px, `.featured-map-tag`/`.station-map-level` 8px | |

Other small findings: `MultiRouteMap.tsx:131` hard-codes the English "Map unavailable" (not i18n); `OperatorBadge.tsx:35`
hard-codes `aria-label` "Unknown operator"; `.passport-distance` references `var(--font, sans-serif)` but `--font` is
never defined (styles.css:520); `.date-field` hard-codes `color-scheme: dark` in both themes (styles.css:329).

---

## 1. Design tokens (CSS custom properties)

Defined on `:root` (dark, the default) at styles.css:2-59 and overridden by `:root[data-theme='light']` at
styles.css:61-101. Station-map tokens at styles.css:698-699. "(same)" = not overridden in light, so the dark value
applies.

### 1.1 Surfaces

| Token | Dark | Light | Use |
|---|---|---|---|
| `--bg` | `#0a0a0a` | `#ffffff` | App background (`html, body`, :104) |
| `--surface` | `#151515` | `#f4f4f4` | Cards, sheets |
| `--surface-raised` | `#1f1f1f` | `#e9e9e9` | Buttons, chips, inputs, pressed |
| `--glass` | `rgba(21, 21, 21, 0.88)` | `rgba(255, 255, 255, 0.9)` | Panels over maps (with `backdrop-filter: blur(10px)` typically) |
| `--glass-strong` | `rgba(10, 10, 10, 0.94)` | `rgba(255, 255, 255, 0.95)` | Tab bar (`blur(14px)`), station-map bottom card |
| `--scrim` | `rgba(0, 0, 0, 0.55)` | `rgba(0, 0, 0, 0.35)` | Behind modal sheets |
| `--fill-soft` | `rgba(255, 255, 255, 0.08)` | `rgba(0, 0, 0, 0.06)` | `.pill` background |
| `--map-bg` | `#111111` | `#f2f2f2` | Map container before tiles load |

### 1.2 Text / ink

| Token | Dark | Light |
|---|---|---|
| `--text` | `#ffffff` | `#0a0a0a` |
| `--text-2` | `#a3a3a3` | `#5c5c5c` |
| `--text-3` | `#6e6e6e` | `#8a8a8a` |

### 1.3 Accent (signal yellow)

| Token | Dark | Light | Note |
|---|---|---|---|
| `--accent` | `#f8d64a` | (same) `#f8d64a` | Fill only |
| `--on-accent` | `#0a0a0a` | (same) | Text/icon on a yellow fill |
| `--accent-ink` | `#f8d64a` | `#0a0a0a` | Accent as text/icon (links, active tab icon) |
| `--accent-soft` | `rgba(248, 214, 74, 0.16)` | `rgba(248, 214, 74, 0.35)` | |
| `--accent-line` | `rgba(248, 214, 74, 0.55)` | `#e0b800` | Focus ring, focused input border, caret, hairline accents |

### 1.4 Status colours (delay bands) and their ink variants

Fills (bars, dots, live dot) use the base token; text uses the `-ink` token ("status is written, not boxed").

| Band | Fill token | Dark | Light | Ink token | Dark | Light |
|---|---|---|---|---|---|---|
| On time (≤0 min) | `--on-time` | `#3ddc84` | (same) | `--on-time-ink` | `= --on-time` | `#12813f` |
| Slight (1-15) | `--slight` | `#f5d90a` | (same) | `--slight-ink` | `= --slight` | `#8a6a00` |
| Late (16-30) | `--late` | `#ff9500` | (same) | `--late-ink` | `= --late` | `#b4570a` |
| Very late (31+) / cancelled | `--very-late` | `#ff453a` | (same) | `--very-late-ink` | `= --very-late` | `#c4271c` |
| Unknown | `--unknown` | `#8e8e8e` | `#8a8a8a` | (text uses `--text-3`) | | |

Band thresholds: `packages/shared/src/delay.ts:8-15` (`<=0` on_time, `<=15` slight, `<=30` late, else very_late;
`canceled` → cancelled; null → unknown). On-time % stat threshold `ON_TIME_MAX_DELAY_MIN = 5` (delay.ts:3).

Banner/alert tints:

| Token | Dark | Light |
|---|---|---|
| `--error-bg` | `rgba(255, 69, 58, 0.14)` | `rgba(255, 69, 58, 0.12)` |
| `--error-text` | `#ff8a82` | `#c4271c` |
| `--warn-bg` | `rgba(255, 149, 0, 0.14)` | `rgba(255, 149, 0, 0.14)` |
| `--warn-text` | `#ffc066` | `#9a5800` |

### 1.5 Borders

| Token | Dark | Light |
|---|---|---|
| `--hairline` | `rgba(255, 255, 255, 0.09)` | `rgba(0, 0, 0, 0.09)` |
| `--marker-ring` | `#ffffff` | `#ffffff` |

All borders are `1px solid var(--hairline)` unless stated.

### 1.6 Split-flap tiles

| Token | Dark | Light | Note |
|---|---|---|---|
| `--flap-top` | `#222222` | `#161616` | Logo tiles always dark |
| `--flap-bottom` | `#1a1a1a` | `#0c0c0c` | |
| `--flap-hinge` | `rgba(0, 0, 0, 0.6)` | `rgba(255, 255, 255, 0.18)` | |
| `--flap-text` | `#ffffff` | `#ffffff` | |
| `--tflap-top` | (undefined → falls back to `--flap-top`) | `#fdfdfd` | Time tiles: pale in light mode |
| `--tflap-bottom` | (→ `--flap-bottom`) | `#efefef` | |
| `--tflap-hinge` | (→ `--flap-hinge`) | `rgba(0, 0, 0, 0.12)` | |
| `--tflap-text` | (→ `--flap-text`) | `#0a0a0a` | |
| `--tflap-edge` | (→ `inset 0 -1px 0 rgba(0, 0, 0, 0.4)`, styles.css:601) | `inset 0 0 0 1px rgba(0, 0, 0, 0.1), 0 1px 2px rgba(0, 0, 0, 0.08)` | Tile shadow |

### 1.7 Radii (one scale, owner 2026-10-23; styles.css:40-46)

| Token | Value | DESIGN §2.3 use |
|---|---|---|
| `--r-tag` | `6px` | Tags (platform chip) |
| `--r-control-sm` | `10px` | 34 px buttons, filter chips, date field, glass labels over map; operator badge ≈ round(size×0.28) = 10 at 36 |
| `--r-input` | `12px` | Buttons, inputs, segmented control, banners, skeletons |
| `--r-card` | `16px` | Cards, time blocks, tiles, mini maps |
| `--r-sheet` | `24px` | Sheets (top corners on phone) |

Circles only for icon buttons (44), map buttons (40), FAB (56), dots. Focus ring radius 6px (:109).

### 1.8 Spacing / sizes

No spacing tokens; DESIGN §2.3: 4 px grid, 16 px gutters on phone (24 px ≥640 px, styles.css:209). Fixed sizes:
`--tabbar-h: 64px` (:53); page padding `calc(12px + safe-top) 16px 24px`, grid gap 16, max-width 720 (:208); main
bottom padding `tabbar + safe-bottom + 24px` (:122). Touch targets ≥44 (DESIGN §16).

### 1.9 Shadows

| Token | Dark | Light |
|---|---|---|
| `--shadow` | `0 8px 24px rgba(0, 0, 0, 0.45)` | `0 8px 24px rgba(0, 0, 0, 0.12)` |

Used on FAB, map buttons, sheets, toasts, live sheets/results, ticket-return card. Other literal shadows:
offline banner `0 4px 14px rgba(0,0,0,0.25)` (:1045); medal `drop-shadow(0 6px 10px rgba(0,0,0,0.35))` (:877);
passport hero (:493); op-badge text-shadow `0 1px 2px rgba(0,0,0,0.35)` (:267).

### 1.10 Gradients
Not tokens; see §3.10.

### 1.11 Fonts
`:root { font-family: 'Inter Variable', Inter, -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
font-size: 16px; line-height: 22px; }` (:54-56). Display font `'Space Grotesk', sans-serif` is set per selector (§2).
Mono: `ui-monospace, 'SF Mono', Menlo, monospace` (`.passport-mrz`, :517).

### 1.12 Station map (indoor) tokens (styles.css:698-699)

| Token | Dark | Light |
|---|---|---|
| `--path` | `#f8d64a` | `#0a0a0a` |
| `--path-glow` | `rgba(248, 214, 74, 0.28)` | `rgba(248, 214, 74, 0.55)` |
| `--platform-fill` | `#2a2a2a` | `#dcdcdc` |
| `--hall-fill` | `#1b1b1b` | `#efefef` |
| `--shop-fill` | `#222` | `#e6e6e6` |
| `--me` | `#3b8bff` | `#1a6ff0` |
| `--unit-fill` | `#2b2b2b` | `#e2e2e2` |
| `--unit-food` | `#33302a` | `#ece4d6` |
| `--unit-service` | `#2a2f33` | `#dde5ec` |

### 1.13 Per-element custom properties (set from code)

- `--op`: operator brand colour, set inline on `.leg-pill`, `.featured`, `.live-module`, `.tl-stop`, `.stop-pick`,
  `.live-train-sheet`, `.train-marker` (TripsPage.tsx:81, :212, :303; Live.tsx:64; TripDetailPage.tsx:81;
  AddTripPage.tsx:339; LiveMapPage.tsx:1071; RouteMap.tsx:264). Value is `opColor(brandColor)` = brand colour, or
  the theme's strong colour when unknown: `#f8d64a` dark / `#0a0a0a` light (style.ts:20, :35, :39). CSS fallback when
  `--op` is unset is `var(--accent)`. `OperatorBadge` alone falls back to `#3a4555` (OperatorBadge.tsx:15).
- `--tone`: alert tone (`.alert-severe` = `--very-late`, `.alert-warn` = `--late`, `.alert-watch` = `--slight`,
  default `--text-2`) (:1014-1023).
- `--i`: stagger index for medals (PassportPage.tsx:76, TripProgress.tsx:42).
- `--d`: flip delay per tile (SplitFlap.tsx:41).
- `--rx`, `--ry`, `--mx`: Passport hero tilt and sheen (PassportPage.tsx:119-125).

### 1.14 z-index (stacking)

| z | Element | Line |
|---|---|---|
| 100 | `.splash` | :148 |
| 60 | `.offline-banner` | :1045 |
| 50 | `.phone-toggle` (web laptop only) | :568 |
| 40 | `.sheet-backdrop`, `.ticket-return` | :621, :963 |
| 30 | `.sheet-page`, `.toast` | :312, :418 |
| 20 | `.tabbar` | :125 |
| 15 | `.fab` | :232 |
| 5 | `.passport-controls` (sticky), `.live-sheet`, `.live-results` | :482, :655, :824 |
| 4 | `.live-top`, `.live-ops` | :817, :642 |
| 3 | `.sticky-actions`, `.live-filters`, `.live-counter`, `.live-legend`, station-map head/filters/side/bottom | |
| 2 | `.map-button`, `.map-chip`, `.month-header` (sticky), `.flap-leaf` | |
| 1 | page over detail map, `.live-page`, `.station-map-page` | |

### 1.15 How light / dark / system is chosen

- Setting `theme: 'system' | 'dark' | 'light'`, default `'dark'` (packages/shared/src/index.ts:31-33, :62). Stored
  server-side in settings; Settings → Appearance segmented control (`settings.themes.*` = System / Dark / Light).
- Applied as **`data-theme="light" | "dark"` on `<html>`** (theme.ts:34-37). `system` resolves through
  `matchMedia('(prefers-color-scheme: light)')` (theme.ts:11) and follows changes live (theme.ts:43-46).
- A copy is kept in `localStorage['clack.theme']`, applied by an inline script in `index.html:12-21` before first
  paint (no flash); after settings load, `applyTheme(settings.theme)` (settings.tsx:33-36).
- On change it also sets `<meta name="theme-color">` to `#ffffff` / `#0a0a0a` (theme.ts:38) and the native status bar:
  `StatusBar.setStyle(theme === 'light' ? Style.Light : Style.Dark)` (native.ts:9-12), i.e. light text on dark.
- Maps read colours once and are **re-created when the theme changes** (RouteMap.tsx:334-338, MultiRouteMap.tsx:137-141).
- SwiftUI mapping: `preferredColorScheme(nil | .dark | .light)` with default `.dark`.

---

## 2. Typography

### 2.1 Families and bundling

| Family | How loaded | Weights | Licence |
|---|---|---|---|
| Inter (variable) | Bundled via npm `@fontsource-variable/inter` ^5.3.0, imported in `main.tsx:3` | variable (400-800 used) | SIL OFL 1.1 |
| Space Grotesk | Bundled via npm `@fontsource/space-grotesk` ^5.3.0, `main.tsx:4-5` imports `600.css` and `700.css` only | 600, 700 | SIL OFL 1.1 |
| System mono | `ui-monospace, 'SF Mono', Menlo, monospace` | system | (system) |
| Noto Sans Regular / Medium | Map label glyph PBFs in `apps/web/public/map/fonts/` (ranges 0-255, 256-511, 512-767, 768-1023, 1024-1279, 8192-8447) + `OFL.txt` | Regular, Medium | SIL OFL 1.1 (OFL.txt: "Copyright 2022 The Noto Project Authors") |

Nothing is fetched from a font CDN. For SwiftUI: bundle Inter and Space Grotesk TTF/OTF (OFL allows it); fallback is
the system font per DESIGN §2.2 ("Inter (fallback system UI font)").

Global: `-webkit-font-smoothing: antialiased` (:105). Tabular numbers on `.tabular, .big-time, .time-big, .tile-value,
.hero-times, .delay-pill, .stop-time, .tl-times` (:112) plus `.leg-row-meta` (:299), `.flap` (:600), `.speedo` (:1041),
`.level-chip` (:758), `.track-pick` (:775), station platform chip text (:721). DESIGN §2.2: tabular for every time,
delay and stat → SwiftUI `.monospacedDigit()`.

### 2.2 DESIGN scale (§2.2, DESIGN.md:57)
Display 40/44, Title 28/34, Headline 20/26, Body 16/22, Caption 13/18, Micro 11/14 (size/line-height). Station names:
Body 600. Train numbers and codes: caption 600, letter-spacing +0.02em. Real iOS-style large titles on main tabs.

### 2.3 As implemented, by role (Inter unless "SG" = Space Grotesk)

| Role | Selector (line) | Size / line | Weight | Tracking / other |
|---|---|---|---|---|
| Large page title | `.page-header h1` (:211) | 40/44 | 800 | -0.02em |
| Sheet title | `.sheet-header h1` (:322) | 28/34 | 800 | |
| Trip detail route | `.detail-route` (:399) | 28/34 | 800 | -0.01em |
| Success title | `.done h2` (:390) | 28 | 800 | |
| Welcome card | `.welcome-card h2` (:993) | 24/30 | 800 | |
| Headline | `.section-title` (:214), `.hero-route` (:286) | 20/26 | 700 | |
| Board sheet title | `.board-sheet-title` (:626) | 20/26 | 800 | |
| Empty-state title | `.empty h2` (:303) | 20 | 700 | |
| Alert title | `.alert-head h2` (:1030) | 17/22 | 800 | |
| Board destination | `.board-dest` (:588) | 17 | 700 | ellipsis |
| Search field | `.search-field` (:335) | 18 | 600 | placeholder 500, `--text-3` |
| Train name / tile value | `.train-name` (:358) 18; `.tile-value` (:445) 18 | 18 | 700 (tile) | tabular |
| Body | `:root` (:55-56) | 16/22 | 400 | |
| Station / row title | `.leg-row-route`, `.station-name`, `.tl-name` | 16 | 600 | |
| Leg pill route | `.leg-pill-route` (:868) | 16 | 700 | |
| Settings row | `.row` (:466) | 16 | 500 | select/input 15 |
| Button | `.button` (:218-220) | 16 | 600 | small: 14 |
| Chip button / pill / banner | `.chip-button` 14/600, `.pill` 14/600, `.banner` 14/500 | 14 | | |
| Delay text | `.delay-pill` (:253) | 14/18 | 700 | tabular; unknown 600 |
| Stop list | `.stop-time`, `.stop-name` (:661, :665) | 14/18 | 600 / 400 | |
| Caption | `.caption` (:113), `.leg-row-meta` (:299) | 13/18 | 400 | `--text-2` |
| Status chip (text) | `.chip` (:241) | 13/18 | 600 | `--text-2`, nowrap |
| Section header | `.section-header` (:213) | 13/18 | 700 | 0.06em, UPPERCASE, `--text-2` |
| Month header | `.month-header` (:215) | 13 | 700 | 0.05em, UPPERCASE, sticky |
| Passport group | `.passport-group` (:841) | 13 | 400 | 0.06em, UPPERCASE |
| Medal label | `.medal-label` (:876) | 13/17 | 700 | |
| "When" on leg pill | `.leg-pill-when` (:887) | 12 | 700 | 0.02em, `--accent-ink` |
| Micro / caption upper | `.caption.upper` (:114) | 11/14 | 600 | 0.06em, UPPERCASE |
| Tab label | `.tab` (:131) | 11 | 600 | |
| Map attribution | `.map-attrib` (:183) | 10/12 | 400 | `--text-3` |
| Splash tagline | `.splash-tagline` (:154) | 13 | 600 | 0.22em, `--text-2` |
| Wordmark | `.wordmark` (:135) | 26 (sidebar), 64 (splash, :153) | 800 | line-height 1 |
| Operator badge | `.op-badge` (:267) + OperatorBadge.tsx:30 | size×0.36 (≤2 chars) or ×0.3 | 800 | 0.02em, white |
| Passport kind | `.passport-hero-kind` (:515) | 15 | 800 | 0.02em |
| Passport MRZ | `.passport-mrz` (:517) | 11 mono | | 0.12em |

**Big numbers and times (Space Grotesk):**

| Role | Selector (line) | Size / line | Weight | Tracking |
|---|---|---|---|---|
| Passport distance | `.passport-distance` (:520) | 56/60 | 700 | -0.02em; unit `small` 22/600 `--text-2` |
| Passport big stat | `.passport-big` (:522) | 40/44 | 700 | |
| Trip detail time block | `.time-big` (:440) | 36/40 | 700 | |
| Trip detail flap time | `.time-flap` (:614) | 34/44 | 700 | 0 |
| Hero times | `.hero-times` (:287) | 34/40 | 700 | -0.01em; in `.featured` 28/34 (:812) |
| Search result times | `.big-time` (:351) | 26/30 | 700 | |
| Walk time | `.walk-big` (:764) | 26/30 | 700 | |
| Flap lg / md / sm | `.flap-lg .flap` 30/40, `.flap-md` 22/30, `.flap-sm` 14/20 (:913-918) | | 700 (:912) | |
| Board time | `.board-flap` (:618) | 18/24 | 700 | |
| Medal number | `.medal-number` (:879) | 26 (≤3 chars) / 21 (Medal.tsx:83) | 800 | fill `rgba(0,0,0,0.72)` |

---

## 3. Component styles

### 3.1 Buttons (styles.css:218-234)

| Variant | Spec |
|---|---|
| Base `.button` (secondary) | inline-flex, gap 8, `min-height: 44px`, `padding: 0 18px`, `border-radius: var(--r-input)` (12), bg `--surface-raised`, `1px solid --hairline`, text `--text`, 600 |
| `.primary` | bg `--accent`, border `--accent`, text `--on-accent` |
| `.danger` | text `--very-late` (bg unchanged) |
| `.small` | `min-height: 34px; padding: 0 14px; font-size: 14px; border-radius: var(--r-control-sm)` (10) |
| `.wide` | width 100% |
| `:disabled` | `opacity: 0.45` |
| `.is-following` | border `--accent`, `box-shadow: inset 0 0 0 0.5px var(--accent)` (:831) |
| Sheet actions | `.train-sheet-actions .button` / `.live-sheet-actions .button`: flex 1, `min-height: 48px`, gap 6 (:872, :1008) |
| `.icon-button` | 44×44 circle, bg `--surface-raised`, hairline border, `--text`; `.small` 34×34 (:575); `.fav-on` text `--slight` (:576) |
| `.link-button` | text `--accent-ink`, 600; **light theme**: underline, decoration colour `--accent`, thickness 2px, offset 3px (also `.back-link`) (:230) |
| `.fab` | 56×56 circle, `right: 16px; bottom: tabbar + safe-bottom + 16px`, bg `--accent`, `--on-accent`, `--shadow` (:231-234); hidden ≥1024 |
| `.map-button` | 40×40 circle, bg `--glass`, hairline, `blur(10px)`, `--shadow`; `[aria-pressed=true]` → accent fill, `--on-accent` (:184-188); `.small` 32×32 (:646). Positions: back/layers top `12 + safe-top`, 16 from sides; recenter bottom-right 16; follow `top: 60 + safe-top` |
| No hover/pressed states defined for `.button` beyond these; `-webkit-tap-highlight-color: transparent` everywhere (:103). Focus ring: `outline: 2px solid var(--accent-line); outline-offset: 2px; border-radius: 6px` (:109). |

### 3.2 Segmented control (:236-238, :683-685)
Container: flex, `padding: 3px; gap: 3px`, bg `--surface`, radius 12, hairline border. Segment: flex 1,
`min-height: 36px`, radius 9px, 600, `--text-2`. Active (final rule, :685): bg `--accent`, text `--on-accent`
(overrides the earlier raised-surface active at :238). `.small`: flex `0 1 260px`, segments `min-height: 32px`,
14px, `padding: 0 10px`.

### 3.3 Cards and surfaces

- `.card` (:274, :928-932): `padding: 14px 16px; gap: 10px; radius 16; 1px hairline`; background is the "lit"
  gradient (§3.10a), not flat.
- `.time-block` (:435): padding 14, radius 16, bg `--surface`, hairline; head `min-height: 26px`.
- `.tile` (:444): padding 12, radius 16, bg `--surface`, hairline; tiles grid 3 columns gap 10 (:443).
- `.result-card` (:348): padding 14, gap 8, radius 16, bg `--surface-raised`, hairline; hover border `--accent-line`.
- `.journey-card` (:555): `padding: 4px 14px 6px`, radius 16, bg `--surface`, hairline, margin-bottom 10.
- `.leg-pill` (:861-866): flex gap 12, `padding: 12px 14px`, **radius 18px**, hairline, gradient §3.10c. In a journey
  card: no bg/border, padding `8px 0` (:892). `.not-taken` opacity 0.55.
- `.featured` (:805-813): radius 16, hairline, overflow hidden, bg `linear-gradient(160deg, surface-raised, surface)`;
  top map 140px high (160 ≥600 px wide), `border-bottom` hairline, non-interactive; tag at `left 10 top 8`,
  `padding 2px 8px`, radius 8, bg `--glass`, 11/16. Body `padding: 14px 16px 16px; gap 8` with hero gradient §3.10b.
- `.hero` (:277-283): padding 18, radius 16, `min-height: 190px`, gradient §3.10b.
- `.record` (:529): `padding: 10px 12px`, radius 12, bg `--surface-raised`. Grid `minmax(150px, 1fr)` gap 10.
- `.milestone` (:843): `padding: 10px 12px`, radius 14, bg `--surface-raised`, border `--accent-line`, min-width 120.
- `.banner` (:269-271): `padding: 12px 14px`, radius 12, bg `--surface-raised`, 14/500; `.error` `--error-bg/--error-text`;
  `.warn` `--warn-bg/--warn-text`.
- `.toast` (:418): fixed top `12 + safe-top`, centred, max-width `100% - 32`, `padding: 10px 16px`, radius 14, bg
  `--surface-raised`, hairline, `--shadow`, 600; auto-dismiss 6000 ms (TripDetailPage.tsx:156).
- `.offline-banner` (:1045): fixed top `safe-top + 6`, centred, `padding: 4px 12px`, radius 10, hairline, bg
  `--surface-raised`, `--text-2`, 12/600, WifiOff 14 icon.
- Alert card (:1014-1037): see §3.10d; header `padding: 10px 10px 10px 14px`; icon disc 30×30 bg `--tone`, glyph
  `#0b0e13` (white for severe); body `padding: 14px 16px 16px; gap 12`; `.alt-toggle` 44 high radius 12, border
  `color-mix(tone 40%, hairline)`.

### 3.4 Sheets

- Modal sheet `.sheet` (:313-316): width 100%, max 640, `height: calc(100dvh - 12px - safe-top)`, bg `--surface`,
  radius 24 top corners, `--shadow`; over `.sheet-page` scrim `--scrim`, aligned to bottom (:312). Header
  `padding: 20px 16px 8px` (:321); body `padding: 8px 16px 32px; gap 14`, scrolls (:323). ≥1024: centred 560 wide,
  `height: min(820px, 92dvh)`, all corners 24.
- Board sheet `.board-sheet` (:622): max-width 560, `max-height: 85dvh`, `padding: 18px 16px calc(18px + safe-bottom)`,
  gap 12, radius 24 top, hairline, shadow, lit gradient (§3.10a), enters with `sheet-up` (§4).
- Trip detail page over map (:197): page overlaps the map by 24 (`margin-top: -24px`), bg `--bg`, radius 24 top,
  `padding-top: 20px`. Map height `min(55dvh, 520px)` (:193).
- Explore sheets `.live-sheet`, `.live-train-sheet` (:934, :655, :998): "iOS-style material": bg `--glass`,
  `backdrop-filter: blur(24px) saturate(180%)`; position `left/right/bottom 12`, max-width 460, `--shadow`; train
  sheet `max-height: min(74%, 680px)`, `.full` `height: calc(100% - 24px)`. Grabber (:1049-1054): 22 px tall touch
  row, bar 36×5 radius 3 `--text-3` at opacity 0.6 → 0.9 and width 44 on press. Three sizes (collapsed / sized /
  full), height settles with 0.22 s ease (§4). On scroll the head shrinks: padding `4px/6px`, hairline bottom
  border, op-badge `scale(0.8)` (:1003-1004). Actions bar: `padding: 10px 16px 14px`, hairline top (:1007).
- SwiftUI mapping: `.presentationDetents`, `.presentationBackground(.ultraThinMaterial)` style for Explore sheets,
  `.presentationCornerRadius(24)`.

### 3.5 Chips / tags / status text

- **Status is text, not a box** (owner 2026-10-23). `.chip` (:241-244): inline-flex gap 5, 13/18/600, `--text-2`.
  `.chip.accent`: `--text` with a 6×6 dot `--accent-line` before. Row `.chip-row`: wrap, gap `6px 14px`.
- `.chip-button` (filter chips, :245-250): `min-height: 34px; padding: 0 14px`, radius 10, bg `--surface-raised`,
  hairline, `--text`, 600, 14px; `.active` = accent fill, `--on-accent`; removable `×` icon `--text-2`. Over a map:
  inactive bg `--glass` + `blur(8px)` (:640-641, :754-755).
- `.pill` (:251): `padding: 4px 12px`, radius 10, bg `--fill-soft`, 600, 14.
- `.platform-chip` (:593-595): `padding: 2px 8px`, min-width 34, radius `--r-tag` (6), bg `--surface-raised`, 700;
  `.changed` bg `rgba(255,149,0,0.18)` text `--late`, old value `<s>` `--text-3` 500.
- `.level-chip` (:758-760): min 40×34, radius 10, glass, 13/700 tabular; active accent; `.small` 28 high 12/600.
- Over a map a status gets a glass backing: `.live-counter .chip` `padding: 6px 10px`, radius 10, `--glass`,
  hairline, `blur(10px)` (:645). `.map-chip` (:192) same idea, `padding: 4px 10px`.
- `.station-collection li` (:847): `padding: 6px 10px`, radius 10, raised, hairline, 14.
- Filters badge count `.filters-count` (:823): 18×18 min, radius 9, bg `--text`, text `--bg`, 11/800, at `-4/-4`.

### 3.6 Status text colours

| Class | Colour | Line |
|---|---|---|
| `.delay-pill.band-on_time` / `.delay-text.band-on_time` | `--on-time-ink` | :254, :260 |
| `band-slight` | `--slight-ink` | :255, :261 |
| `band-late` | `--late-ink` | :256, :262 |
| `band-very_late` | `--very-late-ink` | :257, :263 |
| `band-cancelled` | `--very-late-ink`; `.delay-text` adds `line-through` | :258, :264 |
| `band-unknown` (pill) | `--text-3`, weight 600 | :259 |
| `.delay-text.estimate` | italic | :424 |
| `.status-planned` | `--accent-ink` | :400 |
| `.status-cancelled` | `--very-late` | :401 |
| `.status-boarding` | `--slight` | :402 |
| `.status-live` | `--on-time` | :403 |
| `.live-chip`, `.chip.live-pos` (GPS) | `--on-time-ink` | :406, :830 |
| `.stale-chip` | `--text-3` | :410 |
| `.stop-new.late` / `.early` | `--late` / `--on-time` | :662-663 |
| `.board-dev`, `.date-label .hint`, `.transfer.tight` | `--slight` | :590, :331, :560 |
| `.transfer.missed`, `.layover.at-risk`, activity cancelled | `--very-late` | :561, :907, :423 |
| `.changed-label`, `.record-review` | `--late` | :596, :839 |
| `.review-chip`, `.onboard-notice` | `--warn-text` | :836, :691 |
| `.struck` | line-through, opacity 0.6 | :118 |
| `.sched-struck` | `--text-3`, line-through, 14 | :441 |
| POI open / closing soon / closed | `--on-time` / `--late` / `--text-3` | :786-791 |

Delay text formatting: `fmtDelay` → `+8`, `−2` (U+2212 minus), `0`, `—` for unknown (format.ts:51-55); `DelayPill`
shows `t('delay.on_time')` "On time" for 0, "Cancelled", "—" (DelayPill.tsx:9). Delay colour never alone (DESIGN §2.1).
Board cancelled row: `1px solid --very-late` border, radius 12, times at opacity 0.5 (:584-585). Past board rows
opacity 0.45 (:583).

### 3.7 Inputs

- `.search-field` (:333-339): 52 high, radius 12, bg `--surface-raised`, hairline; `padding: 0 14px`; 18/600 `--text`;
  caret `--accent-line`; focus border `--accent-line`.
- `.live-search` (:819-820): 44 high, radius 12, `--glass`, hairline, `blur(10px)`, `--text-2` icon, input 16px.
- `.date-field` (:329): 34 high, `padding: 0 12px`, radius 10, **border `1px solid --accent`**, raised, 600.
- `.row select`, `.row .text-input` (:468-469): raised, hairline, radius 10, `padding: 7px 10px`, 15px, max 55% width,
  text input right-aligned.
- Checkbox (:470): 22×22, `accent-color: var(--accent)` → SwiftUI Toggle tinted accent.
- `.route-end` (:768-771): 42 high, radius 12, raised, hairline; placeholder `--text-3` 500.

### 3.8 Tab bar and navigation (:124-133; AppShell.tsx)

Fixed bottom, bg `--glass-strong`, `backdrop-filter: blur(14px)`, top hairline, padding-bottom safe area. Each tab
flex 1, 64 high, icon above label gap 3, label 11/600. Inactive `--text-3`; active label `--text`, active icon
`--accent-ink`. Icons Lucide 22 px, stroke 1.75 (AppShell.tsx:115). Tabs: Trips (`TrainFront`), Explore (`Compass`),
Passport (`Stamp`). Settings: `SettingsLink` icon button (gear `Settings` 20) in page headers (AppShell.tsx:64-72).
≥1024: 240 px left sidebar with wordmark, links (`padding: 10px 12px`, radius 10, 600, active raised + `--text`),
Stations link, primary "Add train" button, Settings at the foot (:164-175).

### 3.9 Lists / rows

- `.leg-row` (:296-300): flex gap 12, `padding: 12px 0`, bottom hairline, `min-height: 64px`; side column right
  aligned gap 4.
- `.station-row` (:342): gap 12, `padding: 10px 0`, min 52. `.row` (settings, :466): min 52, bottom hairline (none
  on last), 500.
- `.board-row` (:582): grid `74px 1fr auto`, gap 12, `padding: 12px 0`, bottom hairline.
- `.poi-row` (:782): gap 12, `padding: 10px 4px`; badge 32 circle.
- `.live-result` (:825): grid `26px 1fr`, `padding: 8px 2px`, min 44.
- **Trip-detail timeline** `.tl-stop` (:448-461): grid `20px 1fr auto 44px`, gap 10, min 48. Rail: 2 px line at x=9,
  `--hairline`; ridden part `--op`; starts at 50% on board stop, ends at 50% on alight stop. Dot 10×10 `--text` with
  `0 0 0 2px var(--bg)` ring; dim stops: dot `--text-3`, name `--text-3`/500; board/alight dot 14×14 `--op` with
  `0 0 0 2px var(--text)` ring. Scheduled small 12/500 `--text-3`.
- **Explore stop list** `.stop-row` (:660-677, :942): grid `58px 16px 1fr`, gap 10, min 40. Rail 2 px at x=7
  `--hairline`; dot 10 (ring 2 px `--text-2`, fill `--surface`); passed: rail and dot `--accent`, text `--text-3`;
  next stop: dot 14 with 3 px `--accent` ring; cancelled: name line-through.
- **Stop picker** `.stop-pick` (:373-383): min 46; dot 12 with 2 px `--text-3` ring on `--surface`; from/to dot 16,
  2 px `--marker-ring`, fill `--op`; between: ring `--op`, rail `--op`; outside `--text-3`.
- Transfer/layover connector: dashed 2 px vertical `repeating-linear-gradient(--text-3 0 3px, transparent 3px 6px)`
  (:559) or `0 3px / 3px 7px` (:900). `.layover.linked`: bg `color-mix(surface 60%, transparent)`, `1px dashed
  --hairline` (:898).
- Bars (Passport): track 6 high radius 3 `--hairline`, fill operator colour (:535-536). Band distribution bar 12 high
  radius 6, gap 2, segments min 6 wide in band fills (:544-551). Progress track 8 high radius 4 `--surface-raised`;
  before `color-mix(accent 35%, transparent)`, after `--accent` (:983-986). Live progress 4 high radius 2
  `--hairline`, fill `--op`, dot 14 with 2 px white border (`.hollow`: bg `--bg`, border `--op`) (:413-416).

### 3.10 Gradients (operator colour mixing)

`color-mix(in srgb, X N%, transparent)` = colour X at N% alpha. SwiftUI: `Color(X).opacity(N/100)`. `--op` defaults to
`--accent` when unset.

a. **Card / board sheet "lit" surface** (:928-932):
`radial-gradient(110% 70% at 100% 0%, color-mix(in srgb, var(--op, var(--accent)) 7%, transparent), transparent 60%),
linear-gradient(160deg, var(--surface-raised), var(--surface) 55%)`

b. **Hero / featured body** (:279-281, :854-858):
`radial-gradient(120% 90% at 85% 10%, color-mix(in srgb, var(--op, var(--accent)) 30%, transparent), transparent 60%),
linear-gradient(160deg, var(--surface-raised), var(--surface))`

c. **Leg pill** (:863-865):
`radial-gradient(90% 120% at 100% 0%, color-mix(in srgb, var(--op, var(--accent)) 16%, transparent), transparent 65%),
var(--surface)`

d. **Alert card** (:1016-1018): `radial-gradient(120% 80% at 100% 0%, color-mix(tone 22%, transparent), transparent
60%), linear-gradient(160deg, color-mix(tone 8%, var(--surface-raised)), var(--surface) 60%)`; border
`color-mix(tone 50%, hairline)`; head band `linear-gradient(100deg, tone 34%, tone 8%)`. `.alert-watch` softer: 12% /
plain surfaces / border 30% / head 18%→4% (:1022-1029).

e. **Passport hero** (:485-512): radius 24, `padding: 20px 20px 16px`, text `--on-accent`;
`radial-gradient(120% 80% at 0% 0%, #fff3b0 0%, transparent 55%), radial-gradient(90% 90% at 100% 100%, #d99a00 0%,
transparent 60%), linear-gradient(155deg, #ffe169 0%, #f8d64a 45%, #eab21c 100%)`; shadow
`0 18px 40px -18px rgba(248,214,74,0.55), inset 0 1px 0 rgba(255,255,255,0.55), inset 0 -1px 0 rgba(0,0,0,0.12)`.
Guilloche `::before`: inset -40%, opacity 0.16, two `repeating-radial-gradient`s (circle at 78% 20%, 9 px transparent
then 1 px `rgba(120,70,0,0.9)`; circle at 10% 95%, 13 px / 1 px `rgba(120,70,0,0.7)`), masked top→bottom
`black → rgba(0,0,0,0.35)`. Sheen `::after`: `linear-gradient(105deg, transparent 30%, rgba(255,255,255,0.45) 45%,
transparent 60%)`, size 250%×100%, `mix-blend-mode: soft-light`. Secondary text inside `rgba(10,10,10,0.62)`. Emblem
44 circle, 2 px `rgba(10,10,10,0.55)` border. Inner tiles `rgba(10,10,10,0.08)` radius 14. Tilt: `perspective(900px)
rotateX(--rx) rotateY(--ry)`, rx = ±3°, ry = ±4° from pointer (PassportPage.tsx:119-120).

f. **Wordmark tiles**: §3.11. **Skeleton** shimmer: `linear-gradient(90deg, surface 0%, surface-raised 50%, surface
100%)`, size 200% (:307). **Sticky actions fade**: `linear-gradient(transparent, var(--surface) 30%)` (:384).

g. **Map markers**: no CSS gradients; canvas-drawn (§5.6). Heading cone uses a radial gradient of the operator
colour from `${color}80` (50% alpha) to `${color}00` (LiveMapPage.tsx:102-104).

### 3.11 Split-flap display (SplitFlap.tsx, styles.css:599-618, :910-923)

Structure: each character is a tile; `:`, space and `.` are separators (`.flap-sep`, `padding: 0 1px`, `--text-2`,
not tiles) (SplitFlap.tsx:23-29).

Tile `.flap-tile` (:601-602): `min-width: 0.62em; padding: 0 1px; border-radius: 4px; text-align: center`;
background `linear-gradient(to bottom, var(--tflap-top, --flap-top) 0 49%, var(--tflap-bottom, --flap-bottom) 51%
100%)`; colour `--tflap-text`/`--flap-text`; shadow `--tflap-edge` (dark default `inset 0 -1px 0 rgba(0,0,0,0.4)`).
Hinge: 1 px line across at 50%, `--tflap-hinge`/`--flap-hinge`. Container `.flap`: inline-flex, gap 1, Space Grotesk,
tabular.

Sizes: `.time-flap` 34/44/700, tiles min 0.66em, padding `0 2px`, radius 7, gap 3 (:614-616); `.flap-lg` 30/40, gap
3, tiles 0.66em, radius 6; `.flap-md` 22/30, gap 2, radius 5; `.flap-sm` 14/20, radius 3 (:913-918);
`.board-flap` 18/24.

Flip animation (only for characters that changed; `intro` makes every tile flip on first show by starting from
spaces, SplitFlap.tsx:9):
1. Static layers: `.flap-half.top` shows the **new** char clipped to the top half; `.flap-half.bottom` shows the
   **old** char clipped to the bottom half (`clip-path: inset(0 0 50% 0)` / `inset(50% 0 0 0)`).
2. `.flap-leaf.top` (old char, top half) rotates `rotateX(0) → rotateX(-90deg)`, **180 ms ease-in**, delay `--d`.
3. `.flap-leaf.bottom` (new char, bottom half) rotates `rotateX(90deg) → rotateX(0)`, **180 ms ease-out**, delay
   `--d + 180ms`. Both `transform-origin: 50% 50%`, `backface-visibility: hidden`, z-index 2; tile `perspective:
   240px` (:604-612).
4. Stagger: `--d = n × 50ms` where n counts only flipping tiles, left to right (SplitFlap.tsx:38). Total per tile
   360 ms.
5. Reduced motion: leaves and bottom half hidden → the new char appears instantly (:613).

`FlapTime` (SplitFlap.tsx:59-93): sizes `text | sm | md | lg`. "text" is plain tabular digits. If the scheduled time
differs by ≥1 minute: old time struck (`.flap-old` 0.8em, `--text-3`, 500; 12px in sm, :920-921) before the new one,
and the new digits in `--accent-ink` (:919; text form bold 700 :895). Missing time `—`. Where used: featured trip
`lg` with intro (TripsPage.tsx:235), trip detail departure/arrival `SplitFlap` `.time-flap` intro
(TripDetailPage.tsx:61), board `.board-flap` (BoardPage.tsx:49); elsewhere text form.

Time formatting (format.ts:8-12): 24h `en-GB` `HH:mm`; 12h `en-US` `h:mm` + ` am`/` pm` (lowercase, space). Missing
`--:--`. Always in the station's time zone.

**Wordmark** (Brand.tsx; styles.css:135-144): lowercase `c l a c k`, Inter 800, gap 0.1em. Tile `0.92em × 1.32em`,
radius `0.16em`, `linear-gradient(to bottom, --flap-top 0 49.5%, --flap-bottom 50.5% 100%)`, text `--flap-text`.
Hinge: `left/right -0.06em`, height `0.05em` at 50%, `--flap-hinge` (pins stick out both sides). Fifth tile "k":
`#f8d64a → #e9c63c`, text `#0a0a0a`, hinge `rgba(0,0,0,0.35)`. Rule (splash only): `0.12em` high, `margin-top: 0.4em`,
fully rounded, `--accent-ink`.

### 3.12 Operator badge (OperatorBadge.tsx; styles.css:266-267)
Square `size` (default 36; 28 in featured), radius `round(size × 0.28)`; fill brand colour (fallback `#3a4555`); white
`short_name`, 800, 0.02em, font-size `size×0.36` (≤2 chars) or `size×0.3`, text-shadow `0 1px 2px rgba(0,0,0,0.35)`.
If a downloaded logo exists and logos are enabled: image, `object-fit: cover`, bg `#fff`, inset hairline. The web's
App Store build turned logos off (`VITE_OPERATOR_LOGOS=false`, trademarks, App Review 5.2.1) (OperatorBadge.tsx:6-10);
the Swift app keeps them on, with the operators' approval (docs/APP_STORE.md).

### 3.13 Medals and rim progress (Medal.tsx; styles.css:873-884, :978-994)

SVG viewBox `0 0 120 150`, rendered `size × size*1.25` (default 92). Ribbon: polygons `30,0 54,0 70,62 48,66` (face
dark), `90,0 66,0 50,62 72,66` (face light), knot `54,0 66,0 60,24` `rgba(0,0,0,0.18)`. Rim circle r43 at (60,96) with
linear gradient TL→BR metal `[m0 0, m1 0.55, m0 1]`; face r34 radial gradient (cx .35, cy .3, r .9) `f0 → f1`; inner
highlight r34 stroke `rgba(255,255,255,0.35)` 1.5; groove r38.5 stroke `rgba(0,0,0,0.18)` 1; shine ellipse (46,74)
rx18 ry9 `rgba(255,255,255,0.28)` rotated -30°. Number at y 115 (113 if >3 chars), small icon 14 at (53,68) stroke 2.4
`rgba(0,0,0,0.55)`; or a 36 icon at (42,78) stroke 2.2 `rgba(0,0,0,0.62)` when target is 1 or ≥40 000.

Faces per family (Medal.tsx:9-17): journeys `#ffe27a/#d9a400`; distanceKm `#7db7ff/#2563d9`; stations
`#7ef0b0/#1f9e5c`; operators `#ffb08a/#e0582a`; countries `#cfa8ff/#7d3fd6`; borderCrossings `#ff8fa3/#d12a4a`;
nightTrains `#9aa6ff/#3242b8`. Icons: TrainFront, Route, MapPin, Ticket, Globe2, Flag, Moon (Globe2 for ≥40 000 km).
Metals (Medal.tsx:19-24): bronze `#f0b27a/#9c5a25`, silver `#f4f4f4/#8e8e8e`, gold `#ffe9a0/#c48a1c`, platinum
`#e9f7ff/#7fa7c2`; level = `floor(index × 4 / levels.length)`; single-level families gold. Levels (Medal.tsx:26-34).
Centre text: `1k`, `2.5k`, `10k` (Medal.tsx:44-48).

Locked: body and ribbon `grayscale(1)`, opacity 0.38 (:878). **Rim progress** on locked medals: circle r38.5, stroke
`var(--accent)`, width 8.5, round caps, `dasharray = 2π·38.5·progress, 2π·38.5`, rotated -90° (starts at 12 o'clock,
clockwise) (Medal.tsx:95-97). Shadow `drop-shadow(0 6px 10px rgba(0,0,0,0.35))`. Grid: 3 columns, gap `14px 8px`.

### 3.14 Train art
- `TrainArt` (TrainArt.tsx): procedural family silhouettes, viewBox height 40 (roof y 7, base y 31), default rendered
  height 28. Steel body gradient `#eef1f5 → #c3c9d1 (0.55) → #8e96a1`; glass `#262c35`; livery stripe = operator
  colour, 2.2 high at `BOTTOM-5.5`; skirt `rgba(20,24,30,0.45)`; doors `rgba(0,0,0,0.16)`; bogies `#1c2027` r2.2;
  rail line `rgba(255,255,255,0.12)`; steam/tender `#2b2f36`; wood coaches `#8a5a3c → #5b3a26`. Families: `x2000`,
  `coradia`, `regina`, `contessa`, `flirt`, `x3`, `double_deck`, `loco`, `loco_sleeper`, `railcar`, `steam`, default.
  Nose shapes `flat|round|sloped|pointy|blunt|cab` (TrainArt.tsx:17-85).
- Detailed side views (`components/trains/*.tsx`, generated by `scripts/trains/<model>.py`; DESIGN rule: measured from
  photos, docs/TRAIN_ART.md). Selection logic `TrainPicture.tsx:40-95`: drawn livery if the operator's livery is drawn,
  else `plain`; unknown or uncertain type → family outline in `#8a8a8a` inside `.train-art-unknown` (opacity 0.45,
  grayscale) (styles.css:1066). Rendered height 54 in live sheet, 56 in train cards (:1063-1064).
- Native assets: `assets/trains/<model>-<livery>.svg`, 54 files (list in §9).

---

## 4. Animations and transitions

| What | Duration / easing | Keyframes / values | Where |
|---|---|---|---|
| Split-flap leaves | 180 ms ease-in + 180 ms ease-out, 50 ms stagger | `rotateX 0→-90°`, `90°→0` | :609-612, SplitFlap.tsx:38 |
| Splash wordmark tiles | 420 ms `cubic-bezier(0.3, 0.7, 0.2, 1)`, both; delays 0/60/120/180/240 ms | `flap-in`: `perspective(300px) rotateX(-90deg)`, opacity 0 → none, 1 | :155-162 |
| Splash shown/hidden | min 900 ms; fade `opacity 350ms ease, visibility 350ms`; removed after 400 ms | | Brand.tsx:27-35; :149-151 |
| Live dot | 1.8 s ease-in-out infinite | opacity 1 → 0.35 (50%) → 1 | :407-409 |
| Train halo (trip-detail marker) | 1.8 s ease-out infinite | scale 1→2.4, opacity 0.5→0 | :429-430 |
| Live progress dot | `left 1s linear` | | :415 |
| Explore marker glide | 1500 ms, ease-out cubic `1-(1-k)^3` (JS) | position from→to | LiveMapPage.tsx:57, :235-237 |
| Route draw-on | 1200 ms, ease-out cubic (JS), skipped if reduced motion or live | line grows by length | RouteMap.tsx:196-212 |
| Camera fit | 1200 ms (0 if reduced motion); maxZoom 13 | | RouteMap.tsx:164 |
| Follow train | `easeTo` 800 ms (0 reduced) | | RouteMap.tsx:276 |
| Explore select train | `easeTo` default duration, zoom ≥8, offset `[0, -min(320, h×0.34)]` | | LiveMapPage.tsx:609 |
| Scheduled-train fit | 600 ms, padding top 90, bottom `min(420, h×0.5)`, sides 40 | | LiveMapPage.tsx:658-664 |
| Cluster tap | `easeTo` zoom +2 | | LiveMapPage.tsx:422 |
| Toast in | 0.25 s ease-out | from opacity 0, `translate(-50%, -8px)` | :418-419 |
| Sheet up (board sheet) | 0.22 s ease-out | from `translateY(24px)`, opacity 0 | :622-623 |
| Train sheet height settle | `height 0.22s cubic-bezier(0.2, 0.8, 0.2, 1)` | | :1057 |
| Train sheet head on scroll | `padding 0.2s ease, border-color 0.2s ease`; badge `transform 0.2s ease` to scale 0.8 | | :1000-1004 |
| Grabber | `opacity 0.15s ease, width 0.15s ease` (36→44, 0.6→0.9) | | :1051-1052 |
| Skeleton shimmer | 1.2 s linear infinite | `background-position → -200% 0` | :307-309 |
| Success check | 350 ms ease-out, 100 ms delay | stroke-dashoffset 40 → 0; ring `--on-time` opacity .35 stroke 3; check stroke 4 round | :392-395 |
| Passport sheen | 1.6 s ease-out 0.3 s, both | `background-position 140% → var(--mx)` | :511-512 |
| Passport tilt | `transform 0.25s ease-out` | ±3°/±4° | :494-495 |
| Medals appear | 0.45 s `cubic-bezier(0.2, 1.4, 0.4, 1)` (overshoot), delay `i × 60ms` | `medal-in`: scale 0.6, opacity 0 → none | :880-884 |
| Medal hover | 0.2 s | `translateY(-2px) rotate(-3deg)` | :882 |
| Unlocked medal pop (after adding a trip) | 0.6 s same curve, delay `0.4s + i × 120ms` | `medal-in` | :988-990 |
| Progress fill | `width 1.1s cubic-bezier(0.2, 0.8, 0.2, 1) 0.3s` | starts on 2nd animation frame | :986; TripProgress.tsx:24 |
| Station walk path | 0.9 s linear infinite | `stroke-dashoffset → -1.2` (marching dots) | :726-727 |

**Reduced motion** (`prefers-reduced-motion`):
- Global (:476-479): every animation and transition set to `0.01ms`, iteration count 1; check mark drawn complete.
- Opt-in only under `no-preference`: splash tile flips (:155), passport sheen (:511), medals (:880), unlocked pop
  (:988), marching path (:726).
- Flap leaves hidden (:613); progress fill no transition (:991).
- JS: draw-on skipped and camera durations 0 (RouteMap.tsx:131, :164, :196, :276); passport tilt disabled
  (PassportPage.tsx:117).
- DESIGN §10: "All motion obeys prefers-reduced-motion (replace with fades or no animation)." SwiftUI:
  `@Environment(\.accessibilityReduceMotion)`.

DESIGN §10 also lists: sheet spring snap between peek/half/full; stamp scale 1.4→1 with rotation settle (P2, not
found in code); count-up 900 ms (not found); optional haptic tick on iOS for the flap (DESIGN §1).

---

## 5. Map style (map/style.ts, RouteMap.tsx, MultiRouteMap.tsx, LiveMapPage.tsx)

### 5.1 Sources, providers, licences
- **Basemap**: vector PMTiles served by Clack's own server: `pmtiles://${apiOrigin()}/api/map/basemap.pmtiles`
  (style.ts:44), HTTP range requests (apps/server/src/routes/map.ts:20-34). Built by
  `apps/server/src/import/basemap.ts` from **Protomaps' free daily planet build** (`https://build.protomaps.com/`,
  list `https://build-metadata.protomaps.dev/builds.json`), cut to `NORDIC_BBOX = { minLon: 3.5, minLat: 52.2,
  maxLon: 32, maxLat: 71.5 }` up to z10 (whole world to z4), slimmed to layers `earth`, `water`, `places`,
  `boundaries`, `roads` (kind `highway` only) (mvtFilter.ts:5-11). Over-zoomed beyond z10. Data © OpenStreetMap
  contributors (ODbL). Availability check `GET /api/map/status` → `{ basemap, railGraph }`; without a basemap the style
  is just the background (style.ts:119-130).
- **Rail network**: GeoJSON `${apiOrigin()}/api/map/rail-network.geojson` (style.ts:45), gzip, one `MultiLineString`
  feature `{kind: 'rail'}` (OSM rail graph, service/minor tracks dropped) + one Point per rail station
  `{kind: 'station', id, name, dpd}` (dpd = weighted departures/day) (apps/server/src/geo/railNetwork.ts:44-66).
- **Glyphs**: `${window.location.origin}/map/fonts/{fontstack}/{range}.pbf` (style.ts:123), Noto Sans Regular/Medium
  bundled in `apps/web/public/map/fonts/` (OFL).
- No sprite; markers are images drawn on canvas at runtime.
- **Attribution text** (exact; MapLibre's own control is off, `attributionControl: false`):
  - Route/passport maps: `© OpenStreetMap contributors · Protomaps` (RouteMap.tsx:329, MultiRouteMap.tsx:132)
  - Explore map: `© OpenStreetMap contributors · Protomaps · Trafikverket · Entur (NLOD)` (LiveMapPage.tsx:856)
  - Station map: `{t('stationMap.hoursNote')} · © OpenStreetMap contributors` (StationMapPage.tsx:322)
  - About: en `"Rail network and map data © OpenStreetMap contributors (ODbL). Basemap tiles by Protomaps."`
    (en.json:353), sv `"Järnvägsnät och kartdata © OpenStreetMap-bidragsgivare (ODbL). Bakgrundskarta från Protomaps."`
  - Style: `.map-attrib` bottom-left `left: 8px; bottom: 6px`, 10/12, `--text-3`, no pointer events (:183); 30 px
    up on the trip detail map because the sheet overlaps (:195). DESIGN §2.4: bottom-left, `text-tertiary`.
- Note for native: the style is a plain MapLibre style object, so MapLibre Native iOS can reuse it; whether its
  `pmtiles://` support matches the web's protocol handler must be verified (not checked here).

### 5.2 Theme colours (style.ts:7-36)

| Key | Dark | Light |
|---|---|---|
| land | `#151515` | `#f7f7f7` |
| water | `#0a0a0a` | `#dfe2e5` |
| bg | `#0a0a0a` | `#ffffff` |
| label | `#9a9a9a` | `#6b6b6b` |
| labelHalo | `#0a0a0a` | `#ffffff` |
| text | `#ffffff` | `#0a0a0a` |
| border | `rgba(255,255,255,0.12)` | `rgba(0,0,0,0.18)` |
| road | `rgba(255,255,255,0.06)` | `rgba(0,0,0,0.07)` |
| rail | `rgba(255,255,255,0.13)` | `rgba(0,0,0,0.16)` |
| railStation | `rgba(255,255,255,0.35)` | `rgba(0,0,0,0.4)` |
| stopFill | `#ffffff` | `#ffffff` |
| fallback (unknown operator) | `#f8d64a` | `#0a0a0a` |

### 5.3 Basemap layers (style.ts:61-130), bottom to top

| id | type | source-layer / filter | paint / layout |
|---|---|---|---|
| `background` | background | | `background-color`: water (if basemap) else land |
| `earth` | fill | `earth` | `fill-color` land |
| `water` | fill | `water`, geometry Polygon | `fill-color` water |
| `borders` | line | `boundaries`, `kind == country` | border colour, width 1, dash `[3, 2]` |
| `motorways` | line | `roads`, minzoom 6 | road colour, width interpolate linear z6 0.5 → z12 1.5 |
| `towns` | symbol | `places`, minzoom 8, `kind == locality` and `kind_detail == town` | text `coalesce(name, name:en)`, `Noto Sans Regular`, size 11, max-width 8; label colour, opacity 0.7, halo labelHalo 1.2 |
| `cities` | symbol | `places`, minzoom 3, `kind_detail == city` | size interpolate z4 11 → z10 13; sort key `20 - population_rank`; label colour, halo 1.2 |

### 5.4 Rail network layers (style.ts:132-151)
`rail-network` line, LineString, rail colour, width 1. `rail-stations` circle, minzoom 9, Points, radius 1.6,
railStation colour. Inserted below the route layers (RouteMap.tsx:285); default visible (setting
`showRailNetwork`, default true); layers button toggles visibility.

### 5.5 Route line layers (style.ts:153-204), operator colour `color`

| id | source | paint |
|---|---|---|
| `route-context` (rest of the train's route not ridden) | `route-context` | colour, opacity 0.3, width 2, dash `[2, 2]`, round cap/join |
| `route-ahead` (part still ahead of a live train) | `route-ahead` | colour, opacity 0.8, width 4, dash `[1.5, 1.5]` (= 6 px dash, 6 px gap), butt caps |
| `route-glow` | `route` | colour, opacity 0.35, width 12, blur 6, round |
| `route-body` | `route` | colour, opacity 0.85, width 4, round |
| `route-core` | `route` | `lighten(color, 0.55)` (each channel `c + (255 - c) × 0.55`, style.ts:48-57), width 1.5, round |
| `stops-mid` | `stops` kind `mid` | radius 3, fill `#ffffff`, stroke 1.5 (dark `#0a0a0a`, light `#0a0a0a` text) |
| `stops-end` (board/alight) | `stops` kind `end` | radius 6, fill colour, stroke `#ffffff` 2 |
| `stops-label` | `stops` kind `end` | `Noto Sans Medium` 13, variable anchor left/right/top/bottom, radial offset 0.9, justify auto; text colour, halo bg 1.5 |

Camera: padding `{ top: 72, bottom: 96, left: 64, right: 72 }` interactive, `{ top: 28, bottom: 28, left: 56, right:
56 }` mini; maxZoom 13; default `center [15, 62] zoom 4`; `fadeDuration: 0` (RouteMap.tsx:129-130, :178-185). Mini
map 180 high, radius 16, hairline (:181). Controls: layers (top-right), follow (only with a train), recenter
(bottom-right); icons `Layers`, `Navigation`, `LocateFixed` 18.

**Trip-detail train marker** (DOM, RouteMap.tsx:260-275; styles.css:426-431): 14×14; dot `--op` with 2 px white
border; halo `--op` opacity 0.5 pulsing (§4); chevron white triangle 10 wide × 7 tall, centred 17 px above the dot,
rotated by bearing (hidden when bearing unknown); **estimated**: dot fill `--bg`, 3 px `--op` ring (hollow), title
"Estimated position". Live split: route = travelled (full strokes), route-ahead = rest.

### 5.6 Explore (live) map (LiveMapPage.tsx:290-470)
Opens on bounds `[[4.5, 55.3], [24.5, 68.6]]` (Bergen to the Finnish border, Malmö to Narvik). Layer order: rail
network → `live-stations` → `clusters` → `train-followed` → (selected route layers inserted before `train-mine`) →
`train-mine` → `train-selected` → `train-dot` → `train-label` → `live-station-labels` (moved to top).

- **Stations** `live-stations` (symbol, minzoom 5): image 20 px canvas at pixelRatio 2 (10 pt): rounded square
  `roundRect(3, 3, 14, 14, 3)`, fill map bg, stroke map text, line width 3 (1.5 pt) (LiveMapPage.tsx:147-160). Size
  interpolate z5 0.55, z9 0.75, z13 1. Filter: `dpd >= step(zoom, 60, 6.5→25, 8→8, 9.5→0)`. Rounded squares so they
  never read as trains.
- **Station labels** (minzoom 6): `dpd >= step(zoom, 90, 7.5→40, 9→15, 11→0)`; `Noto Sans Regular` 10.5, offset
  `[0, 0.8]` top; label colour, halo bg 1.2.
- **Trains** source: GeoJSON, `cluster: true, clusterMaxZoom: 6, clusterRadius: 36`.
- **Clusters**: image 76 px @2x (38 pt): circle r27 (13.5 pt), fill dark `rgba(44, 44, 46, 0.94)` / light
  `rgba(255, 255, 255, 0.96)`, shadow `rgba(0,0,0,0.3)` blur 8 offsetY 2, stroke 2 dark `rgba(255,255,255,0.55)` /
  light `rgba(0,0,0,0.08)` (:129-145). icon-size `step(count, 0.85, 10→1.05, 50→1.3)`; count text `Noto Sans Medium`
  `step(count, 12, 10→13, 50→15)`, colour light `#0a0a0a` / dark `#ffffff`.
- **Train dot** (`tdot-<color>` / `tpuck-<color>`): 96 px @2x (48 pt) canvas: white disc r15.5 with shadow
  `rgba(0,0,0,0.35)` blur 6 offsetY 1.5, operator disc r12 on top; with a known heading a translucent cone (radial
  gradient r10→r46, `${color}80`→`${color}00`, wedge ±0.55 rad around up) rotated to the bearing, map-aligned
  (:98-126). Size `interpolate(zoom, 5: mine 0.72 / 0.6, 9: 0.9 / 0.78, 13: 1.1 / 0.95)`; your own trains sort on top.
  Flat, no gloss, "Apple Maps' language" (owner 2026-10-21). **No rings or fading** for delay/GPS state (:380).
- **Your own train** `train-mine`: circle r13, fill `rgba(248,214,74,0.28)`, stroke `#f8d64a` 2 (always yellow, both
  themes; DESIGN §2.1 "your own train always gets a yellow halo").
- **Followed train** `train-followed`: circle r10, transparent, stroke map text colour 2 (white ring on dark).
- **Selected** `train-selected`: circle r11, fill operator colour opacity 0.35, stroke `#ffffff` 2, under the dot.
- **Train label** (minzoom 9): train number; from z11 `"<number> · <destination>"`; `Noto Sans Medium` 11, offset
  `[0, 1.3]` top, text colour, halo bg 1.4.
- Colour per train: `opColor(brandColor)` (fallback yellow/black).
- Over-map UI: top bar (search 44 high glass + filters button), counter chips and legend bottom-left (legend: train
  dot 10 `--text-2` ringed `--marker-ring`; station 9×9 radius 2 `--bg` with 1.6 `--text` border; line 22×4 accent,
  dashed variant) (:643-653, :817-824).
- Selected train route: same `routeLayers(color)`: travelled solid, ahead dashed, cut at the nearest point to the train
  (LiveMapPage.tsx:290-300, :610-626).

### 5.7 Passport map (MultiRouteMap.tsx)
All ridden routes in operator colours: `routes-glow` opacity 0.22, width 10, blur 5 (stacks brighter where ridden often);
`routes-body` opacity 0.75, width 2.5, round. Stations circle radius `interpolate(count, 1→3, 10→7, 50→11)`, fill
`#ffffff`, stroke map bg 1.5, sorted by count. Fit padding 36, maxZoom 10. Height 280 (`.passport-map`, :527);
journey map 240 (:562).

### 5.8 Station (indoor) map
SVG scene (`map/StationScene.tsx`) using the §1.12 tokens: buildings `--surface`, halls `--hall-fill`, platforms
`--platform-fill`, tracks `--text-3` at 0.4, walk path glow `--path-glow` + marching dots `--path`, "me" pin `--me`
with 0.2 halo, destination pin accent with `--on-accent` text, POI badges raised surface + hairline with open-state dot
(styles.css:700-747).

---

## 6. Icons

- **Set**: Lucide via `lucide-react` ^1.60.0 (ISC licence). DESIGN §2.3: "Icons: Lucide, 20px, 1.75 stroke." In code,
  stroke 1.75 is only used on navigation icons (AppShell.tsx); everything else uses Lucide's default stroke 2. Sizes
  used (count of `size={}`): 18 ×41, 16 ×29, 14 ×19, 20 ×9, 22 ×6 (tab bar), 32 ×5, 30 ×3, 24 ×3, 12 ×2, 84 ×1.
- No icon SVG files in the repo; icons are React components. For SwiftUI either bundle the Lucide SVGs as template
  images (ISC permits) or map to SF Symbols (the SF Symbol names below are suggestions, not from the repo).
- Other custom SVGs: round country flags SE, DK, NO, DE, AT (components/Flag.tsx, 32×32 clipped to a circle; grey
  `#555` fallback), medals, train art, dotted-line empty-state illustration (`.dotted-line` 220×44, stroke
  `--accent-line` 3, dash `2 9`, round, opacity 0.85, :291-293), success check.

| Screen / file | Lucide icons | Suggested SF Symbol |
|---|---|---|
| Tab bar / sidebar (AppShell.tsx) | `TrainFront` (Trips), `Compass` (Explore), `Stamp` (Passport), `Search` (Stations), `Plus` (Add train), `Settings` (gear), `WifiOff` (offline banner) | tram.fill, safari, (no stamp; e.g. seal), magnifyingglass, plus, gearshape, wifi.slash |
| Trips (TripsPage.tsx) | `Clock`, `Compass`, `Eye`, `Map`, `Plus`, `Search`, `Stamp` | clock, safari, eye, map, plus, magnifyingglass |
| Trip detail (TripDetailPage.tsx) | `ArrowLeft`, `Radar`, `RefreshCw`, `Repeat`, `Stamp`, `Trash2` | chevron.left/arrow.left, dot.radiowaves..., arrow.clockwise, repeat, trash |
| Route map controls (RouteMap.tsx) | `Layers`, `Navigation`, `LocateFixed` (18) | square.3.layers.3d, location.north.fill, scope |
| Add trip (AddTripPage.tsx) / Manual (ManualTrip.tsx) | `ArrowLeft`, `X` | |
| Explore (LiveMapPage.tsx) | `Check`, `ChevronDown`, `ChevronUp`, `Eye`, `EyeOff`, `Info`, `Search`, `SlidersHorizontal`, `X` | |
| Live module (Live.tsx) | `Gauge` (speed) | gauge |
| Passport (PassportPage.tsx) | `Share2`, `TrainFront`; medals: `TrainFront`, `Route`, `MapPin`, `Ticket`, `Globe2`, `Flag`, `Moon` | |
| Share sheet (ShareSheet.tsx) | `Download`, `Share2`, `X` | |
| Stations / Board (StationsPage.tsx, BoardPage.tsx) | `ArrowLeft`, `Star`, `Map`, `X` | |
| Station map (StationMapPage.tsx) | `ArrowDownUp`, `ArrowLeft`, `Clock`, `DoorOpen`, `List`, `LocateFixed`, `Map`, `Radar`, `Route`, `Search`, `TrainFront`, `X` | |
| Station POIs (StationScene.tsx:25-40) | toilet `Toilet`, cafe `Coffee`, restaurant `UtensilsCrossed`, kiosk `ShoppingBasket`, shop `ShoppingBag`, ticket `Ticket`, locker `Luggage`, waiting `Armchair`, info `Info`, pharmacy `Pill`, atm `Banknote`, taxi `CarTaxiFront`, bus `Bus`, other `MapPin`; level change `ArrowUpDown` | |
| On board amenities (Onboard.tsx:9-22) | catering `Coffee`, wifi `Wifi`, power `Plug`, quiet_car `VolumeX`, first_class `Crown`, family_area `Baby`, pets_area `PawPrint`, bikes `Bike`, wheelchair_space `Accessibility`, step_free `DoorOpen`, accessible_toilet `Toilet`, sleeper `BedDouble`; notices `TriangleAlert` | |
| Disruption / alerts (Disruption.tsx, Alert.tsx, Risk.tsx) | `AlertTriangle`, `ChevronDown`, `ChevronUp`, `Info`, `X`, `Activity` | |
| Connections (Connection.tsx) | `Map` | |
| Tickets (Tickets.tsx) | `ExternalLink` | |
| Settings / About / Privacy / Journey | `ChevronRight`, `ArrowLeft` | |
| Web-only (PhoneFrame.tsx) | `Maximize2`, `Smartphone` (laptop phone frame; not needed natively) | |

---

## 7. i18n

- **Library**: `i18next` ^26.5.3 + `react-i18next` ^16.2.1. Config (i18n/index.ts:9-14): resources `{ en:
  { translation: en }, sv: { translation: sv } }` (single namespace `translation`), `lng: 'en'`, `fallbackLng: 'en'`,
  `interpolation: { escapeValue: false }`. Language follows `settings.language` (`'en' | 'sv'`, default `'en'`)
  via `i18n.changeLanguage` (settings.tsx:29-31; shared index.ts:28). Note: default is English, not the device language.
- **Files**: `apps/web/src/i18n/locales/en.json`, `sv.json`. Nested JSON, 33 top-level groups (`app, nav, trips,
  add, products, status, delay, detail, passport, settings, about, countries, common, map, live, activity, train,
  journey, stations, board, liveMap, onboard, stationMap, connection, record, share, manual, tickets, disruption,
  risk, progress, offline, privacy`). **764 leaf strings per locale**; the key sets are identical and placeholders
  match (enforced by `locales.test.ts:20-35`; no empty strings, :11-17). All values are strings.
- **Interpolation**: `{{name}}` (54 distinct variables, e.g. `{{count}}`, `{{time}}`, `{{name}}`, `{{ago}}`,
  `{{from}}`, `{{to}}`, `{{platform}}`, `{{delay}}`, `{{station}}`, `{{number}}`, `{{min}}`, `{{pct}}`, `{{route}}`,
  `{{month}}`, `{{target}}`, `{{value}}`). No i18next formatters (`{{x, number}}`), no `$t()` nesting, no
  context suffixes.
- **Plurals**: i18next v4 JSON suffixes `_one` / `_other` only (Swedish and English both use one/other). 22 plural
  pairs: `add.stopsBetween`, `delay.explainLate`, `delay.explainEarly`, `passport.flavor.route`,
  `passport.flavor.month`, `passport.minutesLate`, `passport.timesCount`, `passport.visitsCount`,
  `passport.trainsCount`, `passport.basedOn`, `passport.borders`, `passport.reviewBanner`,
  `passport.milestone.{journeys,stations,operators,countries,borderCrossings,nightTrains}`, `journey.label`,
  `liveMap.operatorsN`, `liveMap.simulated`, `liveMap.trainsRunning`. Examples:
  - `add.stopsBetween_one` `"{{count}} stop"` / `_other` `"{{count}} stops"` (en.json:81); sv `"{{count}} stopp"` both.
  - `delay.explainLate_one` `"Arrived {{count}} minute after the timetable."` (en.json:126); sv `"Kom fram {{count}}
    minut efter tidtabellen."` / `"… minuter …"`.
  - `passport.flavor.route_one` `"Your most-ridden line: {{route}} ({{count}} time)"` (en.json:194).
  - `journey.label_other` `"Journey · {{count}} trains"`; sv `"Resa · {{count}} tåg"`.
  For SwiftUI String Catalogs: map `_one`/`_other` to `one`/`other` plural variations, `{{x}}` to `%@`/`%lld`.
  `scripts/ios/sync_assets.py` already copies both JSON files into `<app>/Resources/i18n/` "read by L10n.swift, same
  keys" (sync_assets.py:3, :41-44), i.e. the plan is to read the same JSON natively.
- **Markup**: no HTML or markdown in any value. `<Trans>` is not used. Some values contain `&` (`settings.about`,
  `about.title`) and typographic characters (`·`, `→`, `—`, `−`, `…`).
- **Dynamic keys** built in code (must exist for every enum value): `nav.${key}`, `settings.themes.${v}`,
  `settings.units.${v}`, `settings.clocks.${v}`, `settings.co2.${v}`, `settings.languages.${v}`,
  `settings.paces.${v}`, `products.${category}`, `countries.${code}`, `passport.bands.${b}`,
  `passport.co2Modes.${mode}`, `passport.milestone.${family}`, `detail.quality.${q}`, `detail.qualityNote.${q}`,
  `connection.status.${s}`, `record.state.${ride}`, `record.why.${reason}`, `risk.kind.${k}`, `onboard.keys.${k}`,
  `onboard.notices.${n}`, `onboard.catering.${c}`, `board.window.${w}`, `share.variant.${v}`, `manual.kinds.${c}`,
  `privacy.${p}Title/Body`, `about.sources.${s}`, `disruption.rightsEu_${claim}`.
- **Dates/numbers** (format.ts): app locale `sv-SE` when language is `sv`, else `en-GB` (format.ts:6). Always in the
  station's IANA time zone (the station's `tz` from the API; `Europe/Stockholm` is the fallback in code).
  - Time 24h: `Intl.DateTimeFormat('en-GB', {hour:'2-digit', minute:'2-digit', hour12:false})` → `08:03`; 12h:
    `en-US` `h:mm` then ` am`/` pm` lowercase (format.ts:8-12). Clock is a setting (`24h` default), independent of
    language.
  - Day: `{weekday:'short', day:'numeric', month:'short'}` (+ year if not current year), comma removed → "Fri 17 Oct" /
    "fre 17 okt" (format.ts:15-18). Long: weekday long, day, month long, year (format.ts:20-22). Month header:
    month long + year (format.ts:24-26).
  - Duration: `2h 48m`, `14m`, `5d 3h` (format.ts:38-43), not localised.
  - Distance: `Math.round(v).toLocaleString(locale())` + ` km`/` mi` (format.ts:45-49).
  - Delay: `+8`, `−2` (U+2212), `0`, `—` (format.ts:51-55).
  - Medal centre `1k`/`2.5k` with `toLocaleString('en', {maximumFractionDigits: 1})` (Medal.tsx:46).
  - Other `toLocaleString(locale())` / `toLocaleDateString(locale(), …)` in PassportPage.tsx:60, :80, :100, :212,
    :280, :502, :516 and ShareSheet.tsx:19. Ticket times use `sv-SE` regardless (Tickets.tsx:59).
- **iOS**: `CFBundleLocalizations` = `en`, `sv` (Info.plist:71-75); `CFBundleDevelopmentRegion` `en`.

---

## 8. Operator brand colours (data/operators.json, 23 brands)

`color` is "the brand colour taken from its app icon, brightened where needed to read on the dark map"
(operators.json:2). Unknown operator → theme strong colour (`#f8d64a` dark / `#0a0a0a` light) on maps and accents;
`#3a4555` for the badge.

| id | name | short_name | color | country |
|---|---|---|---|---|
| `sj` | SJ | SJ | `#1fb14f` | SE |
| `snalltaget` | Snälltåget | SN | `#f04a3a` | SE |
| `vr` | VR Snabbtåg | VR | `#00b451` | SE |
| `vy` | Vy | Vy | `#00a07a` | NO |
| `oresundstag` | Öresundståg | ÖT | `#e8402e` | SE |
| `pagatag` | Pågatåg | PÅ | `#9b59d0` | SE |
| `vasttagen` | Västtågen | VT | `#1a8fd6` | SE |
| `sl` | SL | SL | `#0a8fd0` | SE |
| `malartag` | Mälartåg | MÄ | `#00a19a` | SE |
| `arlanda-express` | Arlanda Express | AE | `#f2d74a` | SE |
| `tib` | Tåg i Bergslagen | TiB | `#d9532c` | SE |
| `krosatag` | Krösatåg | KR | `#d9a400` | SE |
| `ostgotapendeln` | Östgötapendeln | ÖP | `#e3262f` | SE |
| `norrtag` | Norrtåg | NT | `#2f7fd0` | SE |
| `varmlandstrafik` | Värmlandstrafik | VÄ | `#f0b000` | SE |
| `x-taget` | X-Tåget | X | `#e83a2a` | SE |
| `tagab` | Tågab | TÅ | `#2b4fa2` | SE |
| `inlandsbanan` | Inlandsbanan | IB | `#c8414f` | SE |
| `lennakatten` | Lennakatten | LK | `#3f8f2a` | SE |
| `tjf` | TJF Smalspåret | TJF | `#795548` | SE |
| `go-ahead-norge` | Go-Ahead Nordic | GA | `#e4003b` | NO |
| `sj-nord` | SJ Nord | SJN | `#0b6e3a` | NO |
| `flytoget` | Flytoget | FLY | `#e30613` | NO |

The client gets these via the API (`brandColor`, `shortName`), loaded into the DB by
apps/server/src/import/brands.ts:13. Logos are not committed (trademarks) and are off in the App Store build.

---

## 9. App icon, splash, logo files

| Asset | Path | Notes |
|---|---|---|
| iOS app icon | `apps/web/ios/App/App/Assets.xcassets/AppIcon.appiconset/AppIcon-512@2x.png` | 1024×1024 RGB, single universal 1024 entry (Contents.json). Black `#0a0a0a` square, one yellow split-flap tile (`#f8d64a` top / `#e9c63c` bottom) with a black "c" and dark hinge line |
| iOS launch image | `apps/web/ios/App/App/Assets.xcassets/Splash.imageset/splash-2732x2732.png`, `-1.png`, `-2.png` | 2732×2732 each (1x/2x/3x), dark only: small "c" tile centred on `#0a0a0a` |
| Launch storyboard | `apps/web/ios/App/App/Base.lproj/LaunchScreen.storyboard` | Image "Splash", `scaleAspectFill`, view bg `systemBackgroundColor` |
| Capacitor | `apps/web/capacitor.config.ts` | `appId: 'app.clack'`, `appName: 'Clack'`, iOS `backgroundColor: '#0a0a0a'`, `contentInset: 'never'`, SplashScreen `launchShowDuration: 0`, bg `#0a0a0a` |
| Favicon (vector logo tile) | `apps/web/public/favicon.svg` | 64×64: rounded rect r14 `#0a0a0a`; tile 32×40 at (16,12) r6, top half `#f8d64a`, bottom `#e9c63c`; "c" Inter 800 34 `#0a0a0a`; hinge `rect x=14 y=31.4 w=36 h=1.2` black at 0.4 |
| PWA / touch icons | `apps/web/public/icons/apple-touch-icon.png` (180), `icon-192.png`, `icon-512.png` (also maskable) | PWA manifest theme/background `#0a0a0a` (vite.config.ts:15-22) |
| Wordmark | `apps/web/src/components/Brand.tsx` (`Wordmark`, `Splash`) | Code-drawn, no image file (§3.11) |
| Train drawings | `assets/trains/*.svg` (54 files, `<model>-<livery>.svg`, `plain` = unpainted), generated by `scripts/trains/export_svg.py` | er1-{malartag,plain}; flytoget71-{flytoget,plain}; flytoget78-{flytoget,plain}; no_flirt-{plain,vy}; no_type72-{go-ahead-norge,plain,vy}; no_type73-{go-ahead-norge,plain,sj-nord}; no_type76-{plain,sj-nord}; rc6_coaches-{plain,sj}; regina-{malartag,plain,sj,tib,varmlandstrafik,vasttagen,x-taget}; x11-{krosatag,plain}; x2000-{plain,sj-x2,sj}; x2000_trailer-{plain,sj-x2,sj}; x3-{arlanda-express,plain}; x31-{dsb,oresundstag,plain}; x40-{plain,sj}; x55-{plain,sj}; x60-{plain,sl}; x61-{pagatag,plain}; x61vt-plain; x62-{norrtag,plain}; x74-{plain,vr}; y31-{krosatag,plain,vasttagen} |
| Sync script | `scripts/ios/sync_assets.py` | Copies locales → `<app>/Resources/i18n/`, train SVGs → `Assets.xcassets/Trains/<name>.imageset` (preserves vector), and the AppIcon set into `apps/Clack/Clack` (default) |
| Fonts | npm packages (Inter, Space Grotesk); map glyphs `apps/web/public/map/fonts/` | Not present as TTF files in the repo; obtain OFL TTFs for bundling |

DESIGN §14: app icon = "one signal-yellow split-flap tile with a black 'c' on black". Launch screen: wordmark flips in
tile by tile, the rule, tagline near the bottom, on the theme's background; colourways black / yellow / white, app uses
black or white with the theme. The current static launch image is dark only.

---

## 10. DESIGN.md rules a native app must follow

- **§1 Product feel**: "calm, dark, precise, a little playful"; split-flap is the signature animation for times, delays
  and big numbers; "No sound in the web app (optional haptic tick later on iOS)". Copy: "friendly, short, never snarky
  about delays".
- **§2.1 Colors**: "Black, white and greys carry the interface; signal yellow is the one accent. Yellow is a fill …
  with black type on it." Accent as text/icon uses `accent-ink` ("yellow text on white is unreadable"). User picks
  System / Dark / Light, **default Dark**. Delay colours: "*Always* show the number or word too … never color alone."
  "Operator colors never replace delay colors." "Do not guess exact brand hex values." Own train on the live map
  "always gets a yellow halo".
- **§2.2 Typography**: Inter; tabular numerals "for every time, delay and stat"; "real iOS-style large titles on the
  main tabs"; station names Body 600; train numbers caption 600, +0.02em.
- **§2.3 Shape**: 4 px grid, 16 px gutters; the radius scale 6/10/12/16/24, operator badge 10; "Circles only for icon
  buttons, the FAB and dots. Nothing is a full pill." "Status is written, not boxed … Only over a map does a status
  get a backing (a glass label, radius 10)." Depth "mostly color and hairlines, not shadows"; floating elements get
  `0 8px 24px` at 45% (dark) / 12% (light). "Icons: Lucide, 20px, 1.75 stroke." (CLAUDE.md repeats: no pill badges,
  no 999 px radii, use the radius tokens and ink colours.)
- **§2.4 Map**: three stacked route strokes (glow/body/core), past vs future, stop dots, rail network layer, estimated
  position shown hollow and labelled "Estimated position", draw-on 1.2 s with 48 px fit, attribution "© OpenStreetMap
  contributors" bottom-left in text-tertiary.
- **§9.5 Live**: LIVE label with pulsing dot while fresh; grey "Stale · updated 3 min ago" after 2 minutes; freshness
  label always visible; Follow train turns off on drag; "Honest data: never present an estimate as GPS."
- **§10 Motion**: split-flap, draw-on, marker pulse, spring sheet snaps, count-up, success check, stamp; "All motion
  obeys prefers-reduced-motion (replace with fades or no animation)."
- **§14 Brand**: tagline "EVERY TRAIN. EVERY TRIP." / "VARJE TÅG. VARJE RESA."; wordmark = five split-flap tiles,
  hinge line, "k" tile signal yellow with black letter; app icon as in §9.
- **§15 States**: every screen needs loading (skeleton), empty, error with retry, offline (saved data + banner), long
  text (ellipsis); "+1" for arrivals after midnight; station-local time zones.
- **§16 Accessibility**: contrast ≥4.5:1; touch targets ≥44 px; visible accent focus; maps have a text alternative
  (the stop timeline); "Support dynamic text sizing and prefers-reduced-motion"; announce live changes politely
  (`aria-live="polite"` → VoiceOver announcements).
- **§17 Breakpoints**: phone < 640; the iOS app is portrait-only (Info.plist:55-58).
- **CLAUDE.md standing rules** that bind the port too: accuracy first (show less rather than guess: "Train type not
  known", unpainted train); every user-facing string in both `en.json` and `sv.json`; zero running costs (no paid map
  or font services); no owner email in requests/headers/user agents.
