# StickyToDo

StickyToDo is a lightweight macOS to-do widget built with SwiftUI. It keeps today's tasks in a small floating card, close at hand, and is designed to be fast, minimal, and easy to use.

## Features

- Small floating card you can drag around from any empty spot
- Quick add from anywhere with the global shortcut `Option + Command + N`
- Mark tasks as done or important; double-click a task to rename it
- Drag tasks to reorder them
- Categories as tabs: filter by category, drag a task onto a tab to move it, and rename or delete a tab from its right-click menu
- Pick a category right in the quick-add field; new tasks go to the tab you're on
- Attach an image to a task by pasting it
- Completed tasks are cleared automatically the next day
- System, light, or dark theme, adjustable task font size, optional checkboxes
- Menu bar icon and launch at login
- Everything is stored locally on your Mac

## Requirements

- macOS 26 or later (the UI uses Liquid Glass)
- Xcode 26 / Swift 6.2 toolchain

## Run Locally

```bash
cd StickyToDo
swift build
swift run
```

Run the tests with `swift test`.

## Project Structure

```text
StickyToDo/
├── Package.swift
├── Sources/StickyToDo/
│   ├── AppKit/     # Window, drag, hotkey, menu bar and drop helpers
│   ├── Models/     # TaskItem, TaskCategory
│   ├── Stores/     # Tasks, categories, settings, attachments
│   ├── Support/    # Theme and small utilities
│   └── Views/      # Main window, quick add, settings
├── Tests/StickyToDoTests/
└── Scripts/
    └── make-test-build.sh   # Builds a separate test copy with its own data
```

## Notes

- Tasks and categories are stored locally on your Mac.
- The app is currently set up as a macOS app, not an iPhone or iPad app.

## License

Add your preferred license here if you plan to open-source the project.
