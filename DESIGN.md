---
name: Typer
description: An AAC typing aid that helps nonverbal children communicate and practice spelling with ultra-large type and spoken feedback.
colors:
  speak-blue: "#2196F3"
  words-green: "#C5E1A5"
  words-green-deep: "#33691E"
  phrases-purple: "#CE93D8"
  phrases-purple-wash: "#F3E5F5"
  phrases-purple-border: "#E1BEE7"
  phrases-purple-deep: "#4A148C"
  typing-yellow: "#FFF59D"
  typing-orange: "#E65100"
  correct-green: "#388E3C"
  correct-green-deep: "#2E7D32"
  incorrect-red: "#D32F2F"
  destructive-red: "#F44336"
  warning-amber: "#FFE0B2"
  warning-amber-deep: "#E65100"
  ink: "#000000"
  ink-secondary: "#616161"
  hairline: "#E0E0E0"
  surface-raised: "#FFFFFF"
  surface-alt: "#F5F5F5"
  surface-sunken: "#EEEEEE"
typography:
  display-typing:
    fontFamily: "Fredoka"
    fontSize: "120px"
    fontWeight: 700
  display-module:
    fontFamily: "Fredoka"
    fontSize: "200px"
    fontWeight: 700
  headline:
    fontFamily: "Fredoka"
    fontSize: "32px"
    fontWeight: 700
  title:
    fontFamily: "Fredoka"
    fontSize: "24px"
    fontWeight: 700
  body:
    fontFamily: "Fredoka"
    fontSize: "18px"
    fontWeight: 400
  label:
    fontFamily: "Fredoka"
    fontSize: "16px"
    fontWeight: 400
rounded:
  sm: "8px"
  md: "12px"
  lg: "16px"
spacing:
  sm: "8px"
  md: "16px"
  lg: "24px"
components:
  button-speak:
    backgroundColor: "{colors.speak-blue}"
    textColor: "#FFFFFF"
    rounded: "{rounded.lg}"
    padding: "24px 48px"
  button-menu-primary:
    backgroundColor: "{colors.words-green}"
    textColor: "{colors.words-green-deep}"
    rounded: "{rounded.lg}"
    size: "400x100"
  button-destructive:
    backgroundColor: "{colors.destructive-red}"
    textColor: "#FFFFFF"
    rounded: "{rounded.md}"
---

# Design System: Typer

## Overview

**Creative North Star: "The Giant Letter Classroom"**

Typer's visual system serves two audiences with one language: a child who may type slowly and needs to see (and hear) every letter at enormous scale, and an adult setting up practice content quickly between lessons. Everything a child touches is oversized, high-contrast, and forgiving; everything an adult touches is standard-density Material organized around the same four-color activity coding the child learns.

Each student activity owns exactly one accent color — Words is green, Phrases is purple, Free Typing is yellow-on-orange, and the Phrasebook is a pale purple wash — introduced on the main menu and repeated wherever that activity appears. Fredoka's rounded warmth carries the whole app by default; the reader may switch to Lexend or Andika in Settings, but only one face is active at a time.

**Key Characteristics:**
- One accent color per activity, never mixed within a screen
- Type scale is extreme by design: 120–200px on student typing surfaces, 16–24px on adult surfaces
- Correctness is never encoded by hue alone (underline/strikethrough accompany green/red)
- Destructive actions always confirm, always back up first, and are always red

## Colors

A bright, saturated primary palette borrowed from candy-toned Material shades, grounded by near-black ink on white.

### Primary
- **Speak Blue** (#2196F3): the voice. SPEAK buttons, selection borders, scrollbars, interactive highlights. If it speaks or is being chosen, it is Speak Blue.

### Secondary
- **Activity Accents** (Words Green #C5E1A5/#33691E · Phrases Purple #CE93D8/#4A148C · Typing Yellow #FFF59D/#E65100): paired background/ink sets used on main-menu buttons and their matching surfaces. Never used for semantics like success/error.

### Neutral
- **Ink** (#000000): all primary text, including the massive draft line.
- **Ink Secondary** (#616161): hints, helper text, captions.
- **Hairline** (#E0E0E0): dividers and quiet borders.
- **Surfaces** (raised #FFFFFF · alt #F5F5F5 · sunken #EEEEEE): app bars are raised; panels and keyboards sit on alt/sunken.

### Named Rules
**The One Voice Rule.** Speak Blue marks anything that produces or receives speech or selection. It is never decorative.
**The Feedback Hue Rule.** Green (#388E3C) means correct/saved; Red (#D32F2F/#F44336) means wrong/destructive; Amber (#FFE0B2/#E65100) means fallback/warning. These four hues never double as decoration.
**The Redundant Cue Rule.** Wherever green/red conveys correctness, a non-color cue (underline, strikethrough) accompanies it.

## Typography

**Display Font:** Fredoka (default; user-selectable in Settings — alternatives: Lexend, Andika. All load from Google Fonts and apply globally via the text theme.)

**Character:** Rounded and friendly without being childish; heavy weights carry the giant displays while regular weights stay legible at small adult sizes.

### Hierarchy
- **Display Typing** (bold, 120px): the child's in-progress sentence in Free Typing.
- **Display Module** (bold, 200px): the letter row in Modules 1–2 (FittedBox scales down to fit).
- **Headline** (bold, 32px): section headings in Settings/Setup, SPEAK button labels.
- **Title** (bold, 24px): app bar titles, list headers, word-list entries.
- **Body** (regular, 18px): explanatory copy for adults.
- **Label** (regular, 16px): interaction-contract hints under typing areas.

### Named Rules
**The If-It-Matters-It's-Huge Rule.** Anything the student must read to act is ≥60px bold. 16–24px type is for adults only.
**The Contract Is Written Rule.** Every screen with an ENTER special behavior states it in a Label-size hint line, regardless of input method.

## Layout

Landscape-locked full-screen columns. Student screens stack: content area (flex 2) above optional keyboard (flex 1). Adult screens use two-column workspaces with a vertical divider. Spacing steps at 8/16/24px; grids use 15–20px gutters.

## Elevation & Depth

Flat-by-default with gentle Material shadow cues. Cards rest at elevation 2–4; the selected profile lifts to 8 with a 3px Speak-Blue border. No ambient glows; depth signals state, not decoration.

## Shapes

Three radii cover everything: 8px for keyboard keys and small fields, 12px for cards and dialog tab-cards, 16px for menu buttons and phrase buttons. Borders are 2–3px solid in the owning accent's mid-shade when a button is outlined rather than filled.

## Components

### Buttons
- **Shape:** 16px radius (menu/activity buttons), 12px (dialogs), 8px (keyboard keys)
- **Primary (SPEAK):** Speak Blue fill, white 32px bold label with 40px icon, 24×48px padding
- **Menu Primary:** activity-accent fill with deep-ink 32px bold label, fixed 400×100
- **Destructive:** Destructive Red fill, white label, named action ("Delete Theme", not "Yes")
- **Outlined Secondary:** white/accent-wash fill, 2–3px accent-mid border

### Cards / Containers
- **Corner Style:** 12px
- **Background:** white or accent wash; profile cards draw from the pastel five-card rotation
- **Shadow Strategy:** elevation 2–4 resting, 8 selected
- **Internal Padding:** 16px

### Inputs / Fields
- **Style:** outlined, 1px Hairline-to-grey border, 8px radius
- **Error:** inline errorText below the field, clears on edit

### Keyboard Keys
- **Shape:** 8px radius, white on sunken grey deck
- **Semantics:** every non-letter key carries a spoken label ("Delete letter", "Space")

## Do's and Don'ts

### Do:
- **Do** use the activity accent pair (bg + deep ink) for anything belonging to Words/Phrases/Typing.
- **Do** pair every correctness hue with underline or strikethrough.
- **Do** confirm every destructive action in a dialog whose button names the action, red on white.
- **Do** reference tokens (`TyperColors`, `Theme.of(context)`) instead of raw `Colors.*`.

### Don't:
- **Don't** introduce a new accent color; extend an existing activity pair instead.
- **Don't** place adult-density UI (tables, small controls) on student screens.
- **Don't** rely on hue alone to convey state.
- **Don't** shrink student-facing type below 60px to fit layout — let FittedBox scale it.
