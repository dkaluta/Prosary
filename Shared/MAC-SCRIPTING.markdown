# Prosary AppleScript on Mac

The native Mac app exposes four commands in its scripting dictionary: `list prayers`,
`open prayer`, `open library`, and `open readings`. Script Editor can open the Prosary
dictionary. The commands work through Cocoa scripting and the app's normal window
routes; they do not require Accessibility UI scripting.

## Commands

| Command | Result | Behavior |
| --- | --- | --- |
| `list prayers` | List of `prayer information` records | Read saved copies from the existing preset store, ordered by localized name and then UUID. Gallery templates without saved copies are absent. |
| `open prayer "reference"` | The saved copy's UUID as text | Resolve a UUID first, otherwise an exact unique saved name. Open its normal prayer window, reusing an existing window for that UUID. |
| `open library` | No result | Open or activate the native Library. |
| `open readings` | No result | Open Daily Readings in the native Library, retaining its browsed civil date. |

Each `prayer information` record contains:

| Property | Type | Meaning |
| --- | --- | --- |
| `id` | Text | Stable saved-copy UUID. Use this for durable scripts; renaming a prayer preserves it. |
| `name` | Text | The exact saved name, including its spaces and Unicode characters. |
| `prayer kind` | Text | `rosary`, `jesusPrayer`, or `custom`. |
| `language code` | Text | Raw saved language preference. An empty string follows app settings. |
| `devotion id` | Text | Custom devotion bundle ID, or an empty string for the other kinds. |
| `is default` | Boolean | Whether this is the devotion's default saved copy. |

Listing and opening do not create or edit saved prayers, reminder definitions, or prayer
bookmarks. Opening uses the saved configuration and the ordinary Continue/Restart and
Choose on Launch behavior. Existing prayer windows retain their active position. Their
configured playback behavior continues to belong to the normal app interface; these
commands expose no advance, finish, restart, delete, or preset-setting operation.

Library and Readings requests wait while a Library editor or another modal view is open.
They use the existing queued destination handling, so scripting does not replace an editor's
parent navigation stack. Closing the Library does not close prayer windows; scripting can
bring the Library back or open a saved prayer while the app remains running.

## Examples

Inspect the saved copies:

```applescript
tell application id "com.dkaluta.prosary"
    set savedCopies to list prayers
    repeat with savedCopy in savedCopies
        log {id of savedCopy, name of savedCopy, prayer kind of savedCopy}
    end repeat
end tell
```

Open one of the returned IDs:

```applescript
tell application id "com.dkaluta.prosary"
    set savedCopies to list prayers
    if (count savedCopies) > 0 then
        open prayer (id of item 1 of savedCopies)
    end if
end tell
```

Open a uniquely named saved copy, or show the reference pages:

```applescript
tell application id "com.dkaluta.prosary"
    open prayer "Evening Prayer"
    open library
    open readings
end tell
```

Replace `Evening Prayer` with an actual saved name. Matching is case-sensitive and does not
trim leading or trailing spaces. An empty or whitespace-only reference is invalid. A
parseable UUID is always an ID lookup, even if another saved copy has that text as its name.
Names can repeat; use the listed UUID when they do.

## Errors

| Error | Number | Resolution |
| --- | --- | --- |
| Invalid reference | `-1700` | Supply text containing a saved UUID or name. |
| Saved prayer not found | `-1728` | Run `list prayers` and use the current ID or exact name. |
| Ambiguous name | `-10000` | More than one saved copy has that name; use its UUID. |

Persistence failures propagate as scripting errors instead of reporting an empty replacement
library. A saved copy whose custom pack is unavailable retains the app's normal unavailable
content behavior. Localized error messages are for people; automation should use the error
number and stable UUIDs.

## Implementation and verification

`iOS/Prosary/Prosary.sdef` defines the Mac dictionary. `Support/MacScripting.swift` reads
the authoritative `PresetStore`, returns native Cocoa arrays and dictionaries, and routes
only `.prayer(id:)` for a saved copy. The app's Mac SDK build sets `NSAppleScriptEnabled`
and `OSAScriptingDefinition`; phone and widget-extension settings remain separate.

The Cocoa command handler suspends the event and returns before asynchronously reading
the store and resuming the reply. SwiftData access and window routing stay on the main
actor. A blocking wait on the main thread would prevent that work from completing. Apple
documents the suspension/return ordering and the matching resume requirement in
[NSScriptCommand](https://developer.apple.com/documentation/foundation/nsscriptcommand)
and [suspendExecution](https://developer.apple.com/documentation/foundation/nsscriptcommand/suspendexecution%28%29).
The dictionary's native records use
[NSAppleEventDescriptor](https://developer.apple.com/documentation/foundation/nsappleeventdescriptor).

The unit suite in `iOS/ProsaryTests/MacScriptingTests.swift` checks the packaged dictionary,
typed metadata, ID/name resolution, duplicate-name errors and read-only store behavior. Native
acceptance also needs the built Mac app and real Apple events:

1. Inspect the built dictionary in Script Editor or with `sdef`; verify all four commands
   and all six record properties, then execute the examples against that exact app build.
2. Check an empty Library and copies with Hebrew/Arabic names, spaces, quotes, duplicate
   names and renamed UUIDs. Invalid and missing references must return the documented errors.
3. Test a cold launch, a running app with every window closed, and repeated opening of a
   saved UUID. Confirm the existing prayer window and its position are reused.
4. With a Library editor open, request Library/Readings and dismiss the editor; confirm
   navigation was deferred and the selected reading date was retained.
5. With fixture auto-advance off, compare presets, reminders and bookmarks before and after
   listing, opening and error paths. Confirm Continue/Restart and Choose on Launch remain
   user choices, and sibling prayer windows retain their state.

Unit tests, a successful Mac build, and an available scripting dictionary do not by
themselves establish that real Apple event execution or store distribution has been verified.

### Verified on 7 October 2026

The Mac unit run completed 652 XCTest cases with no failures (the opt-in child-process
diagnostic was skipped), plus two Swift Testing cases. The iPhone simulator build passed;
its app has neither the Mac scripting keys nor the dictionary resource.

A uniquely identified standalone debug copy, launched with in-memory storage, received
real AppleScript commands. Empty listing returned a list of zero records. Four disposable
saved copies then verified all six typed fields, UUID opening, an exact Hebrew/Syriac/emoji
name, repeated UUID opening, Library/Readings commands, and the three documented error
numbers. Listing retained all four copies after these operations. Debug fixture injection
is available only in an already-isolated test process and is absent from Release builds.

The sandboxed test host blocks its child client's outgoing Apple events; that opt-in
diagnostic is not counted as native execution verification. The standalone commands above
provide that evidence without changing sandbox permissions. This pass does not certify
physical screen-reader traversal or every modal/window-restoration combination.
