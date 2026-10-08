# StickyToDo

A tiny floating to-do card for macOS. Today's tasks stay in view, quick add works from anywhere with `⌥⌘N`, and everything stays on your Mac.

<!-- Screenshot goes here: ![StickyToDo](docs/screenshot.png) -->

## Download

**[Download the latest version](https://github.com/MZZTRMND/StickyToDo/releases/latest)**

1. Unzip **StickyToDo-x.x.zip** and move **StickyToDo.app** to Applications.
2. The app isn't notarized by Apple, so macOS blocks it the first time. Try to open it once, then go to **System Settings → Privacy & Security** and click **Open Anyway**.

Requires macOS 26 or later on an Apple Silicon Mac.

## Features

- **Always at hand.** A small floating card with today's date and your tasks
- **Quick add from anywhere.** Press `⌥⌘N` in any app, type, done
- **Categories.** Tabs to filter tasks, and a category picker right in the quick-add field
- **Fresh every day.** Yesterday's completed tasks are cleared away
- **Native look.** Liquid Glass, light and dark mode, adjustable text size
- **Private.** No account, no cloud. Your tasks never leave your Mac

## Tips

- Double-click a task to rename it
- Drag tasks to reorder them, or drop one onto a category tab to move it there
- Right-click a category tab to rename or delete it
- Paste an image while adding or editing a task to attach it
- Drag the card from any empty spot to move it

## Build from Source

Requires Xcode 26 (Swift 6.2).

```bash
cd StickyToDo
swift build
swift run
```

Run the tests with `swift test`.

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
