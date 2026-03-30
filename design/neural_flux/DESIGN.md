# Design System Strategy: The Digital Curator

## 1. Overview & Creative North Star
The "Creative North Star" for this design system is **The Digital Curator**. This philosophy posits that a "Second Brain" should not feel like a cluttered database, but like a high-end, private gallery for your thoughts. 

We move beyond the "template" look of SaaS apps by embracing **intentional asymmetry** and **tonal depth**. Rather than boxing content into rigid grids with heavy borders, we use the 640px centered content column as a "stage" where information breathes. The goal is a "high-end editorial" experience: high-contrast typography scales, generous vertical whitespace, and a UI that feels carved out of deep ink rather than built with blocks.

---

## 2. Color & Surface Architecture
The palette is rooted in `background: #111319` (Deep Ink). The primary goal is to create a sense of infinite depth through layering.

### The "No-Line" Rule
**Explicit Instruction:** Prohibit 1px solid borders for sectioning. 
Boundaries must be defined solely through background color shifts. To separate a sidebar from a main feed, transition from `surface-dim` to `surface-container-low`. Use the 8px spacing scale to create "gaps" that act as invisible dividers.

### Surface Hierarchy & Nesting
Treat the UI as a series of physical layers—like stacked sheets of frosted obsidian. 
- **Base Level:** `surface` (#111319) - The canvas.
- **Section Level:** `surface-container-low` (#191b22) - Used for grouping related thoughts.
- **Interactive Level:** `surface-container-high` (#282a30) - For hover states or active card focus.

### The "Glass & Gradient" Rule
Floating elements (Command Palettes, Popovers) must use **Glassmorphism**. Use `surface-bright` (#373940) at 60% opacity with a `backdrop-blur` of 20px. 
**Signature Texture:** Main CTAs should not be flat. Apply a subtle linear gradient from `primary` (#c0c1ff) to `primary-container` (#8083ff) at a 135-degree angle to provide a professional "glow" that feels premium and intentional.

---

## 3. Typography: Editorial Authority
We utilize **Inter Variable** for high-readability UI and **JetBrains Mono** for technical metadata, creating a "Scientific Journal" aesthetic.

- **Display (display-lg):** 3.5rem / Inter / Tight tracking (-0.02em). Use for high-impact landing moments.
- **Headlines (headline-md):** 1.75rem / Inter / Semi-Bold. These are the anchors of your notes.
- **Body (body-md):** 0.875rem / Inter / Regular. Line height must be set to 1.6 to ensure long-form reading comfort.
- **Metadata (label-sm):** 0.6875rem / JetBrains Mono / Medium. Used for timestamps, tags, and ID numbers. This monospace contrast signals "data" vs "thought."

Hierarchy is conveyed through **Value, not just Weight**. Secondary information should drop to `on-surface-variant` (#c7c4d7) rather than just becoming a smaller font size.

---

## 4. Elevation & Depth
Depth is achieved through **Tonal Layering** rather than structural lines.

- **The Layering Principle:** Place a `surface-container-lowest` (#0c0e14) card on a `surface-container-low` (#191b22) section to create a soft, natural "recessed" effect.
- **Ambient Shadows:** For floating Modals, use a shadow with a 32px blur, 0% spread, and 6% opacity. The shadow color must be a tinted version of the background (#000000), never a neutral grey.
- **The "Ghost Border" Fallback:** If a border is required for accessibility, use the `outline-variant` (#464554) at 15% opacity. High-contrast, 100% opaque borders are strictly forbidden.

---

## 5. Components

### Buttons
- **Primary:** Gradient fill (`primary` to `primary-container`), white text, 0.5rem (lg) radius.
- **Secondary:** `surface-container-highest` fill, no border, `on-surface` text.
- **Tertiary/Ghost:** No fill. `primary` text. Use 0.5 opacity for inactive states.

### Input Fields
- **Styling:** Minimalist. No border. Use `surface-container-low` as the base. On focus, transition the background to `surface-container-high` and add a 1px "Ghost Border" using the `primary` color at 30% opacity.

### Cards & Lists
- **Prohibition:** Do not use divider lines.
- **Separation:** Use `spacing-4` (1rem) or `spacing-6` (1.5rem) to separate list items. For visual grouping, use a subtle background shift on hover (`surface-container-low`).

### The "Thought Node" (Custom Component)
A specific component for this design system. A card with a 1.5px stroke `outline-variant` at 10% opacity, featuring a `JetBrains Mono` timestamp in the top right and an `Inter` title. It uses "Glassmorphism" when dragged.

---

## 6. Do’s and Don’ts

### Do
- **Do** use the 640px max-width column for all text-heavy content to mirror the experience of a physical notebook.
- **Do** use `JetBrains Mono` for any system-generated data (dates, file sizes, line numbers).
- **Do** leverage `backdrop-blur` for all navigation bars to allow the content to "bleed" through as the user scrolls.

### Don't
- **Don't** use pure black (#000000). Use `surface-container-lowest` (#0c0e14) for the deepest tones.
- **Don't** use 100% opaque borders to separate UI sections. Use tonal shifts.
- **Don't** use standard "drop shadows." If an element needs to pop, increase its surface brightness (`surface-bright`) or use an ambient, low-opacity shadow.
- **Don't** use icons larger than 20px. Keep the stroke at a consistent 1.5px to maintain the "Thin-Lite" premium aesthetic.