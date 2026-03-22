# NoAir

NoAir is a local-first iPhone app for tracking oxygen saturation (`SpO2`), pulse, symptoms, ventilation sessions, treatments, lab results, and passive context such as weather, location, and motion.

The product is intended to make manual health logging fast, structured, and useful for pattern awareness and clinician conversations.

NoAir is not a medical device. It does not diagnose, recommend treatment, or make emergency decisions.

## Repository Status

This repository currently has two meaningful states:

- `main`
  This branch is the clean Xcode/SwiftData scaffold plus repository hygiene and documentation.
- `codex/noair-v1`
  This branch contains the active application implementation work: dashboard flows, timeline editing, reminders, AI commentary, and health-log models.

This `README.md` lives on `main`, so it documents both:

- what NoAir is supposed to become
- what is actually present on `main` today

## Product Vision

NoAir is designed around a few principles:

- local-first by default
- manual-first, automation-assisted
- fast logging over perfect completeness
- one unified timeline instead of fragmented health notes
- transparent summaries instead of black-box advice

## Target User

NoAir is meant for a technically capable iPhone user who:

- manually checks oxygen saturation with a pulse oximeter
- needs to correlate readings with symptoms, ventilation, treatments, and labs
- wants a clearer personal record before talking to clinicians
- prefers speed, clarity, and control over generic wellness tooling

## Intended Feature Set

Planned product scope includes:

- quick `SpO2` and pulse logging
- symptom tagging and contextual notes
- ventilation session logging
- treatment event logging
- lab result logging
- unified reverse-chronological timeline
- dashboard summaries and charts
- passive enrichment with weather, altitude, and motion context
- non-clinical AI summaries of recent logs
- local reminders to log readings

## Current State On `main`

The `main` branch is still the default SwiftUI + SwiftData starter project created by Xcode.

What is on `main` right now:

- a single `Item` SwiftData model
- a starter `NavigationSplitView`
- a working Xcode project (`NoAir.xcodeproj`)
- repository hygiene via `.gitignore`
- project documentation in this `README.md`

What is not yet on `main`:

- the actual NoAir data models
- the dashboard/timeline/logging workflows
- reminders, context enrichment, or AI commentary

Those live on `codex/noair-v1` until merged.

## Project Structure

Current structure on `main`:

```text
NoAir/
├── NoAir/
│   ├── ContentView.swift
│   ├── Item.swift
│   ├── NoAirApp.swift
│   └── Assets.xcassets/
├── NoAir.xcodeproj/
├── .gitignore
└── README.md
```

Expected structure once the product branch is merged:

```text
NoAir/
├── NoAir/
│   ├── Features/
│   │   ├── Dashboard/
│   │   ├── Logging/
│   │   └── Timeline/
│   ├── Models/
│   ├── Services/
│   ├── Shared/
│   ├── ContentView.swift
│   └── NoAirApp.swift
├── NoAir.xcodeproj/
├── .gitignore
└── README.md
```

## Tech Stack

The app is being built with:

- Swift
- SwiftUI
- SwiftData
- Xcode project workflow

Planned integrations in the fuller app branch include:

- Core Location
- motion/activity APIs
- weather API integration
- local notifications
- Gemini API for descriptive commentary

## Running The App

On `main`:

1. Open [NoAir.xcodeproj](/Users/yohanneshaile/Documents/Projects/vibed/NoAir/NoAir.xcodeproj).
2. Select the `NoAir` scheme.
3. Choose an iPhone simulator.
4. Build and run from Xcode.

Or from Terminal:

```bash
xcodebuild -scheme NoAir -project NoAir.xcodeproj -destination 'generic/platform=iOS Simulator' build
```

## Branch Workflow

Recommended interpretation of branches in this repo:

- `main`
  Stable baseline, documentation, and eventual merged product state.
- `codex/noair-v1`
  Feature work and active product iteration.

If you want the fully implemented NoAir experience described in the recent product work, use or merge `codex/noair-v1`.

## Safety

NoAir should be treated as a personal logging tool, not a clinical decision system.

- It should not tell users what treatment to take.
- It should not determine whether ventilation is needed.
- It should not be used for emergency decisions.
- Any AI-generated summary must remain descriptive and non-prescriptive.

## Roadmap

High-priority next steps for bringing `main` up to product shape:

1. Merge the NoAir feature branch into `main`.
2. Replace the starter `Item` model with domain-specific health models.
3. Add dashboard, quick logging, and timeline flows.
4. Wire passive context enrichment and reminders.
5. Add export/reporting and tighten permissions handling.

## Development Notes

The `.gitignore` is configured for typical Xcode and Swift development so local machine state does not pollute the repository. It ignores:

- Xcode build artifacts
- user-specific workspace state
- SwiftPM local build output
- macOS Finder metadata
- common local editor temp files

## License

No license file is currently present in this repository.
