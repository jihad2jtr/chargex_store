# Design System: JGO Store (Swiss Neo-FinTech & Digital Ticket Passes)

**Target App:** JGO Store Mobile App (`mobile/`)  
**Design Philosophy:** Swiss Neo-Bento combined with physical Tactile Ticket Passes. Ultra-crisp typography, tactile feedback, calibrated micro-interactions, quiet chrome, and zero AI-slop (no synthetic glows, no tacky water droplet reflections, no raw un-themed text styles).

---

## 1. Direction & Brand Identity
- **Product:** A high-speed digital voucher, gaming top-up, and virtual numbers platform for Syrian & regional users.
- **Character:** *Precise, tactile, solid, responsive.*
- **World:** Physical airline boarding passes, stock ticker terminals, and Swiss watch instruments. Heavy card stock, crisp perforations, and deep slate frames.
- **Moments:** The tactile ticket pass notches with perforations, the liquid-smooth active tab transition, and authentic high-resolution game/app badges.
- **Signature:** The 6-8px circular ticket perforations (`TicketPassClipper`) with dashed cut-lines on white paper card stock.

---

## 2. Color Palette (Calibrated Ramp)

### Core Surfaces & Backgrounds
| Token | Hex | Role & Usage |
| :--- | :--- | :--- |
| `AppColors.background` / `paper` | `#F4F6F9` | Neutral light Swiss paper background. Clean, calm canvas. |
| `AppColors.surfaceCard` | `#FFFFFF` | Primary white card stock for passes, modals, and list items. |
| `AppColors.surfaceSecondary` | `#F1F5F9` | Secondary recessed bento slot / chip background (`slate100`). |
| `AppColors.darkNav` / `inverseSurface` | `#0F172A` | Deep Slate dock & tactical header frame (`slate900`). |
| `AppColors.borderLight` / `outline` | `#E2E8F0` | Subdued hairlines between components (`slate200`). |
| `AppColors.outlineVariant` | `#CBD5E1` | Perforated dashed lines and subtle dividers (`slate300`). |

### Brand & Functional Accents
| Token | Hex | Role & Usage | Contrast |
| :--- | :--- | :--- | :--- |
| `AppColors.primary` | `#0284C7` | Electric Cyan: Primary action buttons, selection indicators. | 4.8:1 on light |
| `AppColors.secondary` / `ticketAmber` | `#F59E0B` | Ticket Gold: Active ticket tabs, featured badges, warnings. | High visibility |
| `AppColors.secondaryBright` | `#D97706` | Deep Amber: Pricing labels on light backgrounds. | > 4.5:1 WCAG |
| `AppColors.accentGreen` / `emerald` | `#10B981` | Emerald: Instant delivery, active server node, verified status. | 4.6:1 |
| `AppColors.rose` | `#EF4444` | Critical alerts, game tags, destructive confirmation actions. | High contrast |
| `AppColors.brand` | `#F18223` | JGO Brand Emblem Orange. Reserved for logo and core signature. | — |

### Text Hierarchy (Cairo & Plus Jakarta Sans)
| Role | Color Token | Hex | Font & Weight |
| :--- | :--- | :--- | :--- |
| `textPrimary` | `AppColors.slate900` | `#0F172A` | Cairo w800/w900 (Headings, Titles, Values) |
| `textSecondary` | `AppColors.slate600` | `#475569` | Cairo w600/w700 (Subtitles, Descriptions) |
| `textMuted` | `AppColors.slate400` | `#94A3B8` | Cairo w500 / Plus Jakarta Sans (Metadata, Hints) |

---

## 3. Geometry & Spacing (4pt / 8pt Scale)

- **Grid:** All paddings, margins, gaps, and heights must be multiples of 4 or 8 (`4`, `8`, `12`, `16`, `20`, `24`, `32`).
- **Screen Edges:** Standard horizontal screen padding is `16px` (or `12px` on compact screens < 360dp).
- **Corner Radii (`BorderRadius`):**
  - **Pills / Status Chips:** `BorderRadius.circular(20)` or `BorderRadius.circular(8)` for compact badges.
  - **Interactive Buttons / Inputs:** `BorderRadius.circular(12)` to `14`.
  - **Pass Cards / Dialogs:** `BorderRadius.circular(16)`.
  - **Dock Frame:** `BorderRadius.circular(20)`.
- **Perforations (Ticket Notches):**
  - Card notches: `notchRadius = 6.0` to `7.0`.
  - Dock / Carousel notches: `notchRadius = 8.0` to `12.0`.

---

## 4. Depth & Elevation
- **Anti-Slop Elevation Rule:** No colored glowing shadows (`blurRadius: 18, color: Amber.withAlpha(0.55)`).
- **Surface Elevation:**
  - Flat base: `elevation: 0` with hairline borders (`1px Border.all(color: AppColors.borderLight)`).
  - Subtle floating cards: `BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: Offset(0, 2))`.
  - Floating Dock / Header: `BoxShadow(color: Colors.black.withOpacity(0.22), blurRadius: 14, offset: Offset(0, 4))`.

---

## 5. Interaction & Animation Standards (Emil Kowalski Framework)
1. **Button Feedback:** Every pressable card and button must provide instant tactile feedback (e.g. `AnimatedScale(scale: pressed ? 0.96 : 1.0, duration: Duration(milliseconds: 120), curve: Curves.easeOut)`).
2. **Tab Transitions:** `AnimatedPositionedDirectional` with `Duration(milliseconds: 250)` using `Curves.easeOutCubic`.
3. **Typography:** All Arabic texts must strictly use `AppTypography.cairo(...)` and code/numbers must use `AppTypography.spaceMono(...)` or `AppTypography.balance(...)`. No raw un-styled `TextStyle()` allowed.
4. **RTL Directionality:** All custom positionings and paddings must use directional tokens (`EdgeInsetsDirectional`, `PositionedDirectional`, `AnimatedPositionedDirectional`) to ensure flawless Arabic experience.

