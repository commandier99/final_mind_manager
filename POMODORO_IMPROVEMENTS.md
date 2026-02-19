# Pomodoro Mode Improvements

## Overview
Enhanced the Pomodoro mode behavior to enforce timer-based workflow and add check-ins between pomodoros and breaks.

## Key Changes

### 1. **New Check-in Dialogs** (`pomodoro_check_in_dialogs.dart`)
Created comprehensive check-in system with 4 dialog types:

- **Task Done Early**: Shows when user completes a task before timer ends
  - Prompts for productivity rating (1-5 stars)
  - Mood check (Great/Okay/Tired/Stressed)
  - Option to continue with another task or end pomodoro
  - If continuing: shows task selection dialog
  - If ending: starts break and collects feedback

- **Timer Done**: Shows when pomodoro timer completes before task is done
  - Prompts for productivity rating
  - Mood check
  - Pre-select next task for after break
  - Task gets paused automatically

- **Break End Confirmation**: Shows when break timer completes
  - Confirms or changes pre-selected task
  - Option to choose different task
  - Focuses on selected task and starts new pomodoro

- **Focus Switch**: Shows when user wants to change focused task mid-pomodoro
  - Warns that timer keeps running
  - Shows current and new task
  - Confirms switch intention

### 2. **Task Card UI Updates** (`task_card.dart`)
Added `isPomodoroMode` flag to change button behavior:

- **Non-focused tasks in Pomodoro**: Show checkbox + focus toggle (no pause button)
- **Focused task in Pomodoro**: Show checkbox only (no pause or focus button)
- **Other modes**: Original behavior (pause when focused, focus when not)

### 3. **Focus/Pause Logic** (`on_the_spot_task_stream.dart`)
Updated task focus and pause behavior:

- **Focus Task**:
  - In Pomodoro mode: Starts timer automatically when focusing
  - Mid-timer switch: Shows confirmation dialog
  - Keeps timer running during switch
  
- **Pause Task**:
  - In Pomodoro mode: Disabled (no manual pause)
  - Only system can pause (when timer ends)

- **Toggle Done**:
  - In Pomodoro mode with timer running: Pauses timer and shows task-done-early dialog
  - Handles continue-with-another or end-pomodoro flows
  - Marks task complete and manages focus state

### 4. **Pomodoro Section Updates** (`mind_set_pomodoro_section.dart`)
Added callback system for timer events:

- `onPomodoroComplete`: Called when focus timer ends
- `onBreakComplete`: Called when break timer ends
- These trigger check-ins in parent view

### 5. **Active Session View Integration** (`mind_set_active_session_view.dart`)
Implemented check-in handlers:

- **`_handlePomodoroComplete`**:
  - Pauses focused task
  - Shows timer-done check-in
  - Stores pre-selected task ID in session

- **`_handleBreakComplete`**:
  - Shows break-end confirmation
  - Focuses on confirmed/selected task
  - Clears pre-selected task from session

### 6. **Other Stream Widgets**
Updated `follow_through_task_stream.dart` and `go_with_flow_task_stream.dart` to pass `isPomodoroMode` flag for consistency.

## User Flow in Pomodoro Mode

### Starting a Pomodoro
1. User toggles session mode to "Pomodoro"
2. User clicks focus toggle on a task
3. Timer starts automatically
4. Task card shows checkbox only (no pause button)
5. Other tasks show checkbox + focus toggle

### Task Completed Early
1. User checks off task while timer is running
2. Timer pauses
3. Dialog shows: "Task Completed! 🎉"
4. User rates productivity and mood
5. Two options:
   - **Continue with Another**: Select next task, timer resumes on new task
   - **End Pomodoro**: Start break, select next task for after break

### Timer Completed
1. Timer reaches 00:00
2. Task automatically paused
3. Dialog shows: "Pomodoro Complete! ⏰"
4. User rates productivity and mood
5. User pre-selects next task
6. Break timer starts

### Break Ends
1. Break timer reaches 00:00
2. Dialog shows: "Break Over! ☕"
3. Shows pre-selected task
4. User can:
   - **Confirm**: Focus on pre-selected task immediately
   - **Choose Different**: Pick another task from list
5. Timer starts automatically on selected task

### Mid-Timer Switch
1. User clicks focus on different task while timer running
2. Dialog shows: "Switch Task? ⚠️"
3. Warning that timer keeps running
4. User confirms or cancels
5. If confirmed: task switches, timer continues

## Technical Notes

- Timer state managed in session stats (`pomodoroIsRunning`, `pomodoroRemainingSeconds`)
- Pre-selected task stored in `sessionActiveTaskId` during break
- Check-in data (ratings, mood) ready for future analytics
- All dialogs are non-dismissible (must make a choice)
- Checkbox visibility controlled by focus state

## Benefits

1. **Enforced Workflow**: Timer controls work intervals, not manual pause/resume
2. **Mindful Transitions**: Check-ins promote reflection between work sessions
3. **Better Planning**: Pre-selecting next task reduces decision fatigue after break
4. **Productivity Insights**: Stars and mood data ready for analytics
5. **Clear Visual Feedback**: Different UI states for focused vs non-focused tasks
