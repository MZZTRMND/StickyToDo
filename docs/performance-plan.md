# StickyToDo performance: what can be done and why

Investigated 2026-11-05 on the `feature/scroll-performance` branch (scrolling
and check-off already fixed there). Numbers come from a benchmark that draws
the real card off-screen with 20 tasks, plus measurements of the running test
app. They don't include the glass and shadow drawing macOS does separately,
so real frames cost a bit more.

**Frame budget:** a smooth frame has about 8 ms (16 ms on a 60 Hz display).
Anything above that makes an animation visibly hitch.

## Already good

| What | Result |
|---|---|
| Idle CPU | 0%. An 8-second sample shows the app completely asleep: no timers or polling |
| Memory | 50 MB, normal for a SwiftUI app |
| Scrolling 20 long tasks | 0.5 ms per frame (fixed on this branch, was 1.7 ms with 6 ms spikes) |
| Checking off a task | ~3 ms, redraws 1 row (fixed on this branch, was ~11 ms and all rows) |
| Saving tasks | under 1 ms per change; not worth changing |

## Still slow

| Action | Now | Why |
|---|---|---|
| Paste a big screenshot (5K) | **92 ms freeze** | Image is converted to PNG on the main thread |
| First hover preview of that image | **150 ms freeze, 59 MB kept in memory** | The full 5K image is decoded to show a 120 pt preview, then cached forever |
| Switch category tab | **23 ms** | Every row built for the new tab is heavy (see below) |
| Add a task | **18 ms** | Heavy row + every row's position is animated |
| Delete a task | **15 ms** | Same |
| Open quick add (⌥⌘N) | 62 ms first time, 25 ms after | A new screen-sized window is created each time |
| Hover over the tab row | 6 ms | The hover flag lives in shared state, so the whole card redraws |

What a row costs, measured by removing parts one at a time (add/delete):

| Part of a row | Cost |
|---|---|
| "…" menu button: a full native popup button in every row, visible only on hover | **~6 ms** |
| Checkbox: a separate button, though clicking the row already checks it off | **~4 ms** |
| Right-click menu, drag and drop | 1–2 ms |
| Hover highlight, background, tap handling | ~0 ms |
| Bare minimum (the card itself + layout) | ~4 ms add, ~8 ms tab switch |

Task length makes no difference: short tasks measured the same as 200-character ones.

## What can be done, in recommended order

### 1. Build the "…" menu only when it's clicked
**Gain:** about 6 ms off adding, deleting and switching tabs; faster launch.
**Why:** each row creates a real native popup button up front, just in case
it's clicked. Replace it with a plain icon that builds the menu at the moment
you click it. The right-click menu can share the same code. A bonus: the menu
then always shows up-to-date categories and "Paste Image", so rows no longer
need to redraw when the categories or the clipboard change.
**Risk:** medium. The menu code moves from SwiftUI to an AppKit menu; it must
look and behave the same.

### 2. Make the checkbox a plain shape instead of a button
**Gain:** about 4 ms off adding, deleting and switching tabs.
**Why:** the whole row already checks the task off on click, so the inner
button adds cost without adding behavior. VoiceOver keeps working by giving
the row a "toggle" accessibility action.
**Risk:** low. The hover ring on the circle must keep working.

### 3. Paste images off the main thread, and show small previews
**Gain:** no freeze on paste (92 ms → ~0 ms felt); no freeze on first preview
(150 ms → a few ms); ~59 MB → ~0.2 MB memory per big image.
**Why:** converting a big screenshot to PNG and decoding it at full size are
slow, and both happen on the thread that draws the UI. Do the conversion in
the background, and make the 120 pt hover preview from a small thumbnail
(macOS can produce one straight from the file without decoding the whole image).
Clicking still opens the full-size original.
**Risk:** low. Option: also shrink huge images on save (e.g. max 2560 px), but
that loses quality when opening them later, so it's left out by default.

### 4. Keep the quick add window instead of recreating it
**Gain:** quick add opens in ~1–2 ms instead of 25–62 ms, so ⌥⌘N feels instant.
**Why:** each ⌥⌘N creates a new screen-sized window and a fresh SwiftUI view
tree. Create it once (at launch) and just show/hide it, resetting the text
each time.
**Risk:** low. Needs care when you switch screens (move it to the screen
with the mouse) and so focus lands in the field every time.

### 5. Keep hover flags inside the views that use them
**Gain:** ~2 ms per hover on the tab row and on the header "+" button.
**Why:** the tab row's hover flag sits in shared state, and the "+" button's
in the card's state, so hovering either one redraws the whole card. Moving
each into its own small view redraws only that view.
**Risk:** very low.

### 6. Re-check the add/delete animation after 1 and 2
**Gain:** up to 4–6 ms more on add/delete, if needed.
**Why:** adding or deleting animates every row's position. With lighter rows
this gets cheaper on its own. If it's still over budget, only the new/removed
row could animate, but the list would then jump instead of sliding, so
measure first.
**Risk:** it's a look-and-feel trade-off.

### Not measured, check by eye after the above
- **Glass effects** (header button, category tabs, soft fade at the list's
  top and bottom edges) are drawn by the GPU, which this benchmark can't see.
  If scrolling still feels heavy on screen, try turning off the soft edge fade
  first, because it re-blurs content on every scroll frame.

## Expected result after 1–5

| Action | Now | Expected |
|---|---|---|
| Add / delete a task | 18 / 15 ms | ~6–8 ms |
| Switch category tab | 23 ms | ~12 ms |
| Paste a big image | 92 ms freeze | no freeze |
| Open quick add | 25–62 ms | ~1–2 ms |
| Memory per big image | 59 MB | ~0.2 MB |

These are estimates from the measurements above; each step gets measured with
the same benchmark after it's done.

## Results after steps 1–5 (measured, same benchmark)

| Action | Before | After |
|---|---|---|
| Paste a big screenshot (UI blocked) | 92 ms | 0.2 ms (saving runs in the background, ~90 ms) |
| First hover preview of a big image | 150 ms, 59 MB | ~3 ms, 0.13 MB |
| Open quick add | 25–62 ms | 2.5 ms (first opening after launch ~33 ms) |
| Add / delete a task | 18 / 15 ms | 10 / 10 ms |
| Switch category tab | 23 ms | 16 ms |
| App memory (running test app) | 50 MB | 40 MB |
| Idle CPU | 0% | 0% (the quick add placeholder timer now runs only while it's open) |

Step 6, measured: without the add/delete slide animation, adding drops to ~6 ms
and deleting to ~5 ms. Kept on purpose: the slide looks better, and 10 ms is
only slightly over budget.
