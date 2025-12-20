# AI‑Driven Flutter OODA Loop (Android)

## Goal
Provide an **event‑driven, non‑brittle control loop** that allows an AI coding agent (Claude Code, Gemini, Codex, etc.) to **build, run, observe, interact with, and critique Flutter UI sagas** on Android with tight feedback and full visual truth.

Target environment:
- Android only (for now)
- Ubuntu Linux
- Terminal‑only workflow
- `flutter run` invoked directly
- Single emulator/device at a time (AVD)

---

## Core Concept

### Replace “ticks” with **Scenes**
A **Scene** is the atomic unit of iteration.

A scene:
- Puts the app into a known state
- Executes a scripted interaction flow (a saga)
- Captures observations at named **Checkpoints**

Examples:
- `login_flow`
- `login_keyboard_up`
- `onboarding_to_home`
- `modal_permission_visible`

---

## OODA Loop (per Scene)

1. **Observe** — capture UI + state at checkpoints
2. **Orient** — package observations into structured artifacts
3. **Decide** — AI proposes code changes
4. **Act** — AI edits code and re‑runs the scene

---

## Architecture Overview

### Runner (Authoritative Control Plane)
A single long‑lived runner process that:
- Owns one `flutter run` session
- Targets exactly one Android emulator/device
- Exposes commands (reload, restart, run scene)
- Emits structured lifecycle events

No simulated keyboard input. The AI never types `r`.

---

## Observation Model (“Two Cameras”)

### 1) Flutter Camera (Engine View)
- Flutter screenshot
- Widget tree
- Semantics tree

Pros: fast, hot‑reload aligned, structural truth
Cons: blind to Android IME, system dialogs

### 2) Device Camera (Truth View)
- Pixel‑perfect ADB framebuffer screenshot
- Optional short screen recordings

Pros: sees keyboard, permission dialogs, native overlays

### Overlay Detection

```
overlay_present = flutter_image != device_image
```

Rules:
- If `overlay_present == true`, **visual critique uses device image**
- Structural critique always uses widget/semantics data

---

## Event‑Driven Barriers (No Sleeps)

All waits must be **predicate‑based**, **time‑bounded**, and **diagnostic on failure**.

### Required Barriers
- **Device Ready**: emulator connected, Android boot complete
- **App Ready**: app process running, main activity foreground
- **Hot Reload Complete**: structured Flutter tool event (not stdout scraping)
- **Visual Stability**: screen stable via rapid ADB screenshot sampling

No unbounded waits. No raw `sleep N`.

---

## Scenes & Checkpoints

### Scene Phases
1. Setup (ensure emulator + app + clean state)
2. Scripted interactions (tap, type, navigate)
3. Checkpoints (named evaluation moments)

### Checkpoints
At each checkpoint:
- Enforce reload + stability barriers
- Capture observations
- Emit an **Observation Bundle**

---

## Observation Bundle (AI Contract)

Each checkpoint produces a directory with a stable schema:

```
obs/<scene>/<checkpoint>/
  device.png
  flutter.png
  widget_tree.txt
  semantics.txt
  logs.txt
  meta.json
```

`meta.json` includes:
- timestamps
- reload id
- overlay_present
- device/emulator id
- checkpoint name
- stability status

This bundle is the **sole input** for AI critique.

---

## Interaction Capabilities (Android)

The system must support:
- Tap
- Text input
- Key events (back, enter)
- Focus changes (implicitly via taps)

Coordinate‑based input is acceptable initially; semantic targeting may be added later.

---

## Failure Handling

All waits must:
- Timeout
- On timeout, automatically dump:
  - device screenshot
  - recent logcat
  - Flutter tool logs
  - foreground activity info

No silent hangs. No beach‑balling.

---

## Non‑Goals
- iOS support (future)
- Continuous video capture by default
- Human‑driven interaction loops
- Timing‑guess‑based sleeps

---

## Success Criteria

The system succeeds if:
- AI can iteratively build multi‑screen Flutter UI sagas
- Native Android UI (IME, dialogs) is reliably observed
- No integration run blocks indefinitely
- Observations are consistent and machine‑digestible
- AI model can be swapped without changing the loop

---

## North‑Star Principle

> **Do not guess when the system is ready. Wait for proof.**

