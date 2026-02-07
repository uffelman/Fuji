# Keyboard Shortcut Fix

## Problem
Global keyboard shortcuts for presets were not working when triggered from any application, including DisplayApp itself.

## Root Cause
The `RegisterEventHotKey` function was being called with `GetEventDispatcherTarget()` as the target parameter. While this seems logical for "global" hotkeys, the correct approach is to use `GetApplicationEventTarget()` when registering hotkeys, even for system-wide hotkeys.

The event handler should be installed on `GetEventDispatcherTarget()` to receive events system-wide, but the hotkeys themselves should be registered with `GetApplicationEventTarget()`.

## Changes Made

### KeyboardShortcutManager.swift

1. **Fixed hotkey registration target** (line ~140):
   - Changed from `GetEventDispatcherTarget()` to `GetApplicationEventTarget()` in `RegisterEventHotKey` call
   - Added comment explaining the correct usage

2. **Enhanced debugging output**:
   - Added success logging in `setupEventHandler()`
   - Enhanced `refreshHotKeys()` with detailed status for each preset
   - Added accessibility permission check with warning
   - Shows total count of registered hotkeys

3. **Minor improvements**:
   - Added explicit `UInt32()` cast to keyCode for clarity
   - Better structured logging

## Testing Instructions

1. **Build and run the application**
2. **Grant Accessibility permissions**:
   - Go to System Settings > Privacy & Security > Accessibility
   - Make sure DisplayApp is in the list and enabled
   - If not, the app should prompt you on first launch
   
3. **Create a test preset**:
   - Open DisplayApp settings
   - Create a new preset with a resolution configuration
   - Assign a keyboard shortcut (e.g., ⌘⌥1)
   - Save the preset

4. **Test the keyboard shortcut**:
   - Switch to another application (e.g., Safari, Finder)
   - Press the assigned keyboard shortcut
   - The resolution should change and you should see a notification
   
5. **Check the Console output**:
   - Open Console.app
   - Filter for "DisplayApp"
   - You should see messages like:
     ```
     Successfully installed event handler
     Refreshing hotkeys, found N presets
     Registering hotkey for preset 'YourPreset': ⌘⌥1
       ✓ Successfully registered
     Hotkey registration complete. Total registered: 1
     ```
   - When you press the hotkey, you should see:
     ```
     Hotkey pressed with ID: X
     Found registered hotkey: ⌘⌥1
     Found preset: YourPreset
     ```

## Additional Notes

- Accessibility permissions are **required** for global keyboard shortcuts to work
- The app will warn in the console if permissions are not granted
- Hotkeys are re-registered whenever presets are modified
- The fix ensures hotkeys work regardless of which app is in the foreground
- Hotkeys will work even when DisplayApp is running as a menu bar app (accessory)

## If It Still Doesn't Work

1. **Check Accessibility Permissions**: Make sure DisplayApp is listed and enabled
2. **Check for conflicts**: Try a different key combination to rule out conflicts with system shortcuts
3. **Restart the app**: After granting accessibility permissions, restart DisplayApp
4. **Check Console logs**: Look for error messages or failed registration attempts
5. **Verify the shortcut was saved**: Open settings and confirm the shortcut is displayed on the preset
