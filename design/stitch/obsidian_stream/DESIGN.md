---
name: Obsidian Stream
colors:
  surface: '#131313'
  surface-dim: '#131313'
  surface-bright: '#3a3939'
  surface-container-lowest: '#0e0e0e'
  surface-container-low: '#1c1b1b'
  surface-container: '#201f1f'
  surface-container-high: '#2a2a2a'
  surface-container-highest: '#353534'
  on-surface: '#e5e2e1'
  on-surface-variant: '#ebbbb4'
  inverse-surface: '#e5e2e1'
  inverse-on-surface: '#313030'
  outline: '#b18780'
  outline-variant: '#603e39'
  surface-tint: '#ffb4a8'
  primary: '#ffb4a8'
  on-primary: '#690100'
  primary-container: '#ff5540'
  on-primary-container: '#5c0000'
  inverse-primary: '#c00100'
  secondary: '#9ccaff'
  on-secondary: '#003257'
  secondary-container: '#2295ed'
  on-secondary-container: '#002b4c'
  tertiary: '#c6c6c7'
  on-tertiary: '#2f3131'
  tertiary-container: '#909191'
  on-tertiary-container: '#282a2a'
  error: '#ffb4ab'
  on-error: '#690005'
  error-container: '#93000a'
  on-error-container: '#ffdad6'
  primary-fixed: '#ffdad4'
  primary-fixed-dim: '#ffb4a8'
  on-primary-fixed: '#410000'
  on-primary-fixed-variant: '#930100'
  secondary-fixed: '#d0e4ff'
  secondary-fixed-dim: '#9ccaff'
  on-secondary-fixed: '#001d35'
  on-secondary-fixed-variant: '#00497b'
  tertiary-fixed: '#e2e2e2'
  tertiary-fixed-dim: '#c6c6c7'
  on-tertiary-fixed: '#1a1c1c'
  on-tertiary-fixed-variant: '#454747'
  background: '#131313'
  on-background: '#e5e2e1'
  surface-variant: '#353534'
typography:
  headline-lg:
    fontFamily: Inter
    fontSize: 24px
    fontWeight: '700'
    lineHeight: 32px
    letterSpacing: -0.02em
  headline-md:
    fontFamily: Inter
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 28px
    letterSpacing: -0.01em
  headline-sm:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '600'
    lineHeight: 22px
  title-md:
    fontFamily: Inter
    fontSize: 15px
    fontWeight: '500'
    lineHeight: 20px
  body-lg:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  body-md:
    fontFamily: Inter
    fontSize: 13px
    fontWeight: '400'
    lineHeight: 18px
  body-sm:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '400'
    lineHeight: 16px
  label-lg:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '600'
    lineHeight: 20px
  label-md:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '500'
    lineHeight: 16px
  label-sm:
    fontFamily: Inter
    fontSize: 10px
    fontWeight: '500'
    lineHeight: 14px
    letterSpacing: 0.02em
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  gutter: 0.75rem
  margin: 0.75rem
  space-xs: 0.25rem
  space-sm: 0.5rem
  space-md: 0.75rem
  space-lg: 1rem
  space-xl: 1.5rem
---

## Brand & Style

This design system establishes an immersive, content-first mobile video experience. Engineered for modern mobile displays, the aesthetic leans into dark-mode ergonomics—minimizing optical glare while letting high-resolution video thumbnails, dynamic creators, and live video previews dominate the canvas. 

The aesthetic is rooted in modern Material Design 3 layered architecture combined with utilitarian media controls. Interface chrome recedes into deep obsidian shades, asserting high contrast hierarchy only where necessary: vibrant crimson triggers for brand identity and core creation moments, paired with precise electric azure markers for engagement, verified channels, and dynamic actions. The user interface feels immediate, cinematic, tactile, and frictionless.

## Colors

The palette is engineered specifically for deep-tier OLED dark UI rendering:

- **Canvas Base (`#0F0F0F`)**: The absolute screen background providing deep contrast without harsh black clipping.
- **Surface / Container (`#212121`)**: Base container tier for structural sections, comment trays, collapsed mini-players, and cards.
- **Surface Elevated (`#282828`)**: Raised interactive state for active sheets, dialogs, floating action trays, and contextual menus.
- **Primary Red (`#FF0000`)**: Used exclusively for high-intent actions—recording triggers, subscribe conversions, dynamic playback scrub heads, and live status badges.
- **Secondary Blue (`#3EA6FF`)**: Dedicated to verified creator credentials, interactive timestamps, hashtags, links, and system-level metadata.
- **Borders & Dividers (`#2E2E2E`)**: Low-profile hairline structural boundaries that partition feeds without introducing visual clutter.
- **Text Layers**: Primary white (`#FFFFFF`) at full opacity for headers and video titles; secondary muted gray (`#AAAAAA`) for metadata, views, relative timestamps, and inactive iconography.

## Typography

Typography balances rapid scanning with dense information architecture:

- **Inter** provides exceptional legibility at compact mobile scale, clear numeral differentiation for time codes, and uniform tracking across variable screen densities.
- **Video Titles**: Set in `headline-sm` with a 2-line maximum clamp and ellipsis cutoff, ensuring thumbnail-to-title cadence remains consistent throughout continuous scroll feeds.
- **Metadata Ribbons**: View counts, relative publish times, and author handles utilize `body-md` and `body-sm` rendered in `#AAAAAA`.
- **Badges & Overlays**: Video duration tags (`label-sm`) leverage semi-transparent alpha backings with bold weight for high-contrast legibility over bright or dark video frames.

## Layout & Spacing

The layout is built around a mobile-first, edge-to-edge media feed:

- **Screen Boundaries**: Edge margin defaults to 12px (`0.75rem`), permitting content cards to maximize viewport width while providing breathable separation from physical display edges. Full-bleed options are reserved for primary video playback and continuous Shorts reels.
- **Vertical Feed Cadence**: Video feed items maintain a strict 16px to 24px vertical separation (`space-lg` to `space-xl`) between distinct cards, ensuring unambiguous grouping between a thumbnail and its associated metadata block.
- **Top App Bar**: 48px fixed height housing the brand mark, casting triggers, notification bell, and search actions.
- **Bottom Navigation Bar**: 56px fixed height (exclusive of device home indicators), featuring 4 to 5 core destinations with an elevated circular creation hub button.
- **Tablet / Large Form Reflow**: When viewport exceeds 600px width, layout switches from single-column vertical feed to a multi-column responsive grid (2-column at 600px–900px, 3-column beyond 900px) with fixed 16:9 thumbnail aspect ratios.

## Elevation & Depth

Visual hierarchy is communicated through calibrated tonal surfaces and hairline boundaries rather than dramatic drop shadows:

- **Level 0 (Base)**: `#0F0F0F` — Default canvas and scrollable body.
- **Level 1 (Sub-surface)**: `#212121` — Filter chip ribbons, non-active action buttons, search bars, and card containers.
- **Level 2 (Elevated Panels)**: `#282828` — Bottom sheets, comment panels, contextual action menus, and the floating mini-player.
- **Separation Technique**: Structural division is enforced by `#2E2E2E` 1px borders or dividers. Shadows are strictly functional: a subtle `0 4px 12px rgba(0, 0, 0, 0.45)` is reserved exclusively for elevated overlays (modal sheets, bottom navigation bar over scroll content, and video scrub hover previews).

## Shapes

The design system implements a strict, multi-tier shape hierarchy tailored to touch interactions:

- **Media & Cards (12px)**: Video thumbnails, modular preview cards, and bottom sheet containers utilize a standardized 12px corner radius, balancing modern softness with media framing stability.
- **Controls & Pills (Fully Rounded / 9999px)**: Filter chips, primary conversion actions (e.g., Subscribe), quick reaction buttons (Like/Share/Remix), and live viewer pills use a full pill radius to denote immediate tap targets.
- **Form Inputs & Search (8px)**: Search boxes, text entry surfaces, and inline comment inputs follow an 8px radius to preserve structural stability inside dense toolbars.

## Components

### Buttons & Action Bars
- **Primary Conversion (Subscribe)**: High-contrast solid white background (`#FFFFFF`) with deep black text (`#0F0F0F`) and full pill radius (9999px). On subscribed state: transitions to elevated surface (`#282828`) with primary white text and a bell icon.
- **Pill Action Groups**: Segmented reaction bars (Like / Dislike split pills, Share, Remix, Download) utilize `#212121` surface fills, 36px height, 12px horizontal padding, and `#FFFFFF` icons paired with `label-md` typography.
- **Live / Urgent Actions**: Highlighted with `#FF0000` solid background with pure white text.

### Chips & Filter Ribbons
- Horizontally scrollable carousels seated directly below the top bar.
- Height: 32px with full pill radius.
- **Inactive**: `#212121` container, `#FFFFFF` text (`label-md`), zero border.
- **Active**: `#FFFFFF` container, `#0F0F0F` text, bold weight.

### Video Cards & Feeds
- **Thumbnails**: 16:9 ratio, 12px radius, with an absolute-positioned bottom-right timestamp badge (`#000000` with 80% opacity, 4px radius, `label-sm` font).
- **Metadata Block**: 36px circular avatar left-aligned; 12px right-aligned content area featuring 2-line title (`headline-sm`), channel name (`body-md`), view count, and publication timestamp separated by middle dots (`•`). Contextual three-dot overflow trigger pinned to the upper-right corner.

### Form Inputs & Search Bar
- Height: 40px with an 8px border radius.
- Background: `#212121` with a hairline `#2E2E2E` stroke.
- Placeholder text in `#AAAAAA` (`body-md`), with high-contrast `#FFFFFF` active input. Integrated voice search and clear glyphs aligned inside the trailing padding.

### Navigation Bars
- **Top Bar**: Fixed 48px height, `#0F0F0F` background, containing the brand logotype (Crimson `#FF0000` icon with white wordmark), followed by Cast, Notification, Search, and Account Profile glyphs (24px icons).
- **Bottom Bar**: Fixed 56px height, `#0F0F0F` background with a top 1px border of `#2E2E2E`. 5-destination distribution: Home, Shorts, Create (`+` in a 36px pill/circle), Subscriptions, You/Library. Inactive items use `#AAAAAA`; active selections illuminate in `#FFFFFF`.