# Project "time" - Status & Context

This file serves as the foundational context for Gemini CLI. It tracks the current state of the project, architectural decisions, and recent changes.

## Project Overview
An iOS Time Tracking application built with SwiftUI, featuring a Home Screen Widget.

### Core Architecture
- **TimeManager.swift**: Central logic using `ObservableObject`. Manages `TimeSegment` arrays, `TimerState`, and `CompletedDay` history. Handles AppGroup sharing for Widget synchronization.
- **SharedConstants.swift**: Contains shared enums (`TimerState`, `SegmentType`) and structures (`TimeSegment`, `CompletedDay`) used by both the app and the widget.
- **ContentView.swift**: Main UI providing start/pause/stop controls, a quote display, and access to history/logs.
- **Progress Views**:
    - `TimeProgressBar.swift`: Linear timeline view.
    - `CircularProgressBar.swift`: Circular clock-like view.
- **TimeWidget**: Home screen widget for quick actions and status overview.

## Key Features & Rules
- **Break Rules**: 
    - 5:45h: Warning notification (15 mins before mandatory 30 min break).
    - 6:00h: Mandatory 30-minute break notification (if < 30 min total).
    - 8:45h: Warning notification (15 mins before mandatory 45 min break).
    - 9:00h: Mandatory 45-minute break notification (if < 45 min total).
    - 10:00h: Maximum working time reached notification.
- **Test Mode**: Accelerates time by 300x for testing.
- **AppGroup**: Uses `group.com.alireza.Widget` for data sharing between the app and its extensions.

## Recent Changes (March 21, 2026)
- **Summary Persistence**: Modified `TimeManager` to capture and store total work/pause times before resetting at the end of the day.
- **UI Summary Update**: Progress bars (Linear and Circular) now display the last finished day's summary when the app is in `idle` state, ensuring the user can see their results after clicking "Tag beenden".
- **Notification Fix**: Confirmed notifications are working. Fixed reset flags to ensure consistency across sessions.
- **Start Reset**: When a new day is started via "Start Arbeitszeit", the previous summary is cleared (set to 0) to begin fresh.
- **Widget Update**: Added a lightning bolt icon (`bolt.fill`) to the widget's status bar when Test Mode is active. Interactive widget buttons now trigger notification scheduling even when the app is closed.

## Development Guidelines
- Always update `GEMINI.md` after significant changes.
- Ensure all logic in `TimeManager` is mirrored or accessible to the `TimeWidget` via `UserDefaults(suiteName: AppGroup.identifier)`.
- Maintain the "Test Mode" functionality for all new time-based features.
