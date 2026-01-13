-- Export Apple Notes recursively from a folder (including all subfolders)
-- Creates a mirrored directory tree, exports each note as .html
--
-- Usage:
--   # Show usage instructions:
--   osascript export_notes.applescript
--
--   # List all available top-level folders:
--   osascript export_notes.applescript list
--
--   # Export a folder (searches all accounts and all folder levels, finds first match):
--   osascript export_notes.applescript export "Folder Name" "/path/to/output"
--
--   # Export a folder from a specific account (recommended for duplicate folder names):
--   osascript export_notes.applescript export "AccountName:FolderName" "/path/to/output"
--
-- Notes:
--   - Folder search: Searches recursively at ALL levels (not just top-level) to find the folder
--   - Once found: Exports that folder and all its subfolders recursively
--   - Uses breadth-first search (BFS) to find folders level-by-level
--   - By default, the account name is "iCloud" (most common case)
--   - If folder name exists in multiple accounts, use "AccountName:FolderName" format
--   - Requires Automation permissions for Notes app (System Settings > Privacy & Security) depending on which app invoked the script, like Terminal or Script Editor

on run argv
  -- No arguments: show usage
  if (count of argv) is 0 then
    my print_usage()
    return
  end if

  set subcommand to item 1 of argv

  -- Handle "list" subcommand
  if subcommand is "list" then
    -- Check permissions first
    if not (my check_notes_permissions()) then
      my print_permissions_warning()
    end if
    my print_all_top_level_folders()
    return
  end if

  -- Handle "export" subcommand
  if subcommand is "export" then
    if (count of argv) < 3 then
      log "Error: 'export' requires a folder name and output directory."
      log ""
      my print_usage()
      return
    end if

    -- Check permissions first
    if not (my check_notes_permissions()) then
      my print_permissions_warning()
    end if

    set topFolderSpec to item 2 of argv
    set outRootPosix to item 3 of argv
  else
    -- Unknown subcommand
    log "Error: Unknown subcommand '" & subcommand & "'"
    log ""
    my print_usage()
    return
  end if

  -- Check if folder spec includes account name (format: "AccountName:FolderName")
  set maybeAccountName to missing value
  set topFolderName to topFolderSpec
  
  if topFolderSpec contains ":" then
    set AppleScript's text item delimiters to ":"
    set parts to text items of topFolderSpec
    if (count of parts) is 2 then
      set maybeAccountName to item 1 of parts
      set topFolderName to item 2 of parts
    end if
    set AppleScript's text item delimiters to ""
  end if

  my ensure_dir_posix(outRootPosix)

  tell application "Notes"
    set topFolder to missing value
    if maybeAccountName is not missing value then
      -- Search in specific account
      set topFolder to my find_folder_by_account_and_name(maybeAccountName, topFolderName)
      if topFolder is missing value then
        error "Could not find folder named '" & topFolderName & "' in account '" & maybeAccountName & "'"
      end if
    else
      -- Search in all accounts (finds first match)
      set topFolder to my find_folder_by_name(topFolderName)
      if topFolder is missing value then
        error "Could not find folder named: " & topFolderName
      end if
    end if

    -- Export top folder into its own directory under output root
    set topDirPosix to outRootPosix & "/" & my sanitize_path_component(topFolderName)
    my ensure_dir_posix(topDirPosix)

    my export_folder_recursive(topFolder, topDirPosix)
  end tell
end run

-- ===== Usage and help =====

on print_usage()
  log "Apple Notes Exporter"
  log ""
  log "Usage:"
  log "  osascript export_notes.applescript <command> [options]"
  log ""
  log "Commands:"
  log "  list                                  List all available top-level folders"
  log "  export <folder> <output_dir>          Export a folder recursively to HTML files"
  log ""
  log "Examples:"
  log "  osascript export_notes.applescript list"
  log "  osascript export_notes.applescript export \"My Notes\" \"./output\""
  log "  osascript export_notes.applescript export \"iCloud:Work\" \"./output\""
  log ""
  log "Notes:"
  log "  - Use \"AccountName:FolderName\" format if folder name exists in multiple accounts"
  log "  - Requires Automation permissions for Notes app"
end print_usage

on print_permissions_warning()
  log ""
  log "⚠️  Notes Automation permissions may not be properly configured."
  log "   Please grant permissions in:"
  log "   System Settings > Privacy & Security > Automation"
  log "   Ensure Terminal (or osascript) has permission to control Notes"
  log ""
end print_permissions_warning

-- ===== Core recursion =====

on export_folder_recursive(theFolder, outDirPosix)
  my export_notes_in_folder(theFolder, outDirPosix)
  my export_subfolders_recursive(theFolder, outDirPosix)
end export_folder_recursive

on export_notes_in_folder(theFolder, outDirPosix)
  tell application "Notes"
    try
      set ns to notes of theFolder
    on error errMsg
      my log_folder_access_error(theFolder, errMsg, "notes")
      return
    end try

    repeat with n in ns
      try
        my export_note(n, outDirPosix)
      on error errMsg
        log "Error exporting note: " & errMsg
      end try
    end repeat
  end tell
end export_notes_in_folder

on export_subfolders_recursive(theFolder, outDirPosix)
  tell application "Notes"
    try
      set subs to folders of theFolder
    on error errMsg
      my log_folder_access_error(theFolder, errMsg, "subfolders")
      return
    end try

    repeat with sf in subs
      try
        set subName to name of sf
        set subDirPosix to outDirPosix & "/" & my sanitize_path_component(subName)
        my ensure_dir_posix(subDirPosix)
        my export_folder_recursive(sf, subDirPosix)
      on error errMsg
        log "Error processing subfolder: " & errMsg
      end try
    end repeat
  end tell
end export_subfolders_recursive

on log_folder_access_error(theFolder, errMsg, context)
  if errMsg contains "type specifier" or errMsg contains "Can't make" then
    set folderName to my get_folder_name_safe(theFolder)
    log "⚠️  Permission error accessing " & context & " in folder '" & folderName & "'"
    log "   This may require Automation permissions. Check:"
    log "   System Settings > Privacy & Security > Automation"
    log "   Ensure Terminal (or osascript) has permission to control Notes"
  else
    log "Could not access " & context & " of folder: " & errMsg
  end if
end log_folder_access_error

on get_folder_name_safe(theFolder)
  try
    tell application "Notes"
      return name of theFolder
    end tell
  on error
    return "unknown"
  end try
end get_folder_name_safe

on export_note(n, outDirPosix)
  tell application "Notes"
    set noteTitle to name of n
    set noteBody to body of n -- HTML-ish rich text
  end tell
  set safeTitle to my sanitize_filename(noteTitle)

  -- Short id: derived from Note's internal id if available; otherwise from date + random
  set sid to my short_id_for_note(n)

  set fileName to safeTitle & " -- " & sid & ".html"
  set outFilePosix to outDirPosix & "/" & fileName

  my write_text_file_posix(outFilePosix, noteBody)
end export_note

-- ===== Finding folders =====

on get_all_top_level_folders()
  -- Returns a list of all top-level folders across all accounts
  -- Each item is a record with: {accountName: account name, folderRef: folder reference, folderName: folder name}
  set folderList to {}
  tell application "Notes"
    repeat with acc in accounts
      set maybeAccName to missing value
      try
        set maybeAccName to name of acc
      on error errMsg
        log "Warning: Could not access account: " & errMsg
      end try

      -- Only process folders if we successfully got the account name
      if maybeAccName is not missing value then
        try
          set accFolders to folders of acc
          repeat with f in accFolders
            try
              set folderName to name of f
              set end of folderList to {accountName:maybeAccName, folderRef:f, folderName:folderName}
            on error errMsg
              log "Warning: Could not access folder in account '" & maybeAccName & "': " & errMsg
            end try
          end repeat
        on error errMsg
          log "Warning: Could not access folders in account '" & maybeAccName & "': " & errMsg
        end try
      end if
    end repeat
  end tell
  return folderList
end get_all_top_level_folders

on check_notes_permissions()
  -- Checks if we have permission to access Notes properties
  -- Returns true if permissions seem OK, false otherwise
  -- This is a best-effort check; some accounts may still have restrictions
  tell application "Notes"
    try
      set accList to accounts
      if (count of accList) is 0 then
        return false
      end if

      -- Try to access folders from at least one account
      repeat with acc in accList
        try
          set accFolders to folders of acc
          if (count of accFolders) > 0 then
            -- Try to access notes from first folder to verify full permissions
            set firstFolder to item 1 of accFolders
            try
              set folderNotes to notes of firstFolder
              -- If we can access notes, permissions are good
              return true
            on error
              -- Can access folders but not notes - partial permission, but might still work
              -- Don't fail the check, as some folders might work
            end try
          end if
        on error
          -- This account might not be accessible, try next one
        end try
      end repeat

      -- If we got here, we could at least access accounts
      -- Return true to avoid false warnings (individual operations will handle errors)
      return true
    on error
      return false
    end try
  end tell
end check_notes_permissions

on print_all_top_level_folders()
  -- Prints all available top-level folders to the log
  log "=== Available Top-Level Folders ==="
  set allFolders to my get_all_top_level_folders()
  
  if (count of allFolders) is 0 then
    log "No folders found"
    log "===================================="
    return
  end if

  set skippedCount to 0
  repeat with folderInfo in allFolders
    set maybeResult to my print_folder_info_safe(folderInfo)
    if maybeResult is "skipped" then
      set skippedCount to skippedCount + 1
    end if
  end repeat

  if skippedCount > 0 then
    log ""
    log "Note: " & skippedCount & " folder(s) could not be fully accessed (may be from external accounts)"
  end if
  log "===================================="
end print_all_top_level_folders

on print_folder_info_safe(folderInfo)
  set accName to missing value
  set folderName to missing value
  
  -- Try to get account name from record (using new field name)
  try
    set accName to accountName of folderInfo
  on error
    -- Couldn't access account from record - will try folder reference if needed
  end try
  
  -- Try to get folder name from record first (using new field name)
  try
    set folderName to folderName of folderInfo
  on error
    -- If record access fails, try to get it from folder reference
    try
      set folderRef to folderRef of folderInfo
      tell application "Notes"
        set folderName to name of folderRef
      end tell
    on error
    end try
  end try
  
  -- Print result
  if accName is not missing value and folderName is not missing value then
    log accName & " > " & folderName
    return "success"
  else if folderName is not missing value then
    -- We have the folder name but not the account - this suggests the record
    -- might be from an external account or there was an issue accessing account info
    -- But since we CAN access the folder name, it's not really "restricted"
    -- Just show it without the account name
    log "[Account Unknown] > " & folderName
    return "success"
  else
    log "⚠️  [Access Restricted] > [Unknown Folder]"
    return "skipped"
  end if
end print_folder_info_safe

on find_folder_by_name(targetName)
  -- Searches all accounts and returns the first matching folder found
  -- 
  -- Search algorithm: Performs an unbounded breadth-first search (BFS) across:
  --   1. All accounts (in the order returned by the Notes API)
  --   2. All folders at each level before proceeding to the next level
  --   3. Searches level-by-level (top-level first, then second-level, etc.)
  --
  -- Returns: The first folder with a matching name found, or missing value if not found
  -- Use find_folder_by_account_and_name if you need to specify the account
  tell application "Notes"
    -- Initialize queue with all top-level folders from all accounts
    set folderQueue to {}
    repeat with acc in accounts
      try
        set accFolders to folders of acc
        repeat with f in accFolders
          set end of folderQueue to f
        end repeat
      on error
        -- Skip accounts that can't be accessed
      end try
    end repeat
    
    -- Process queue level by level (BFS)
    return my search_folders_bfs(folderQueue, targetName)
  end tell
end find_folder_by_name

on find_folder_by_account_and_name(accountName, targetFolderName)
  -- Searches for a folder in a specific account by name
  --
  -- Search algorithm: Performs an unbounded breadth-first search (BFS) within:
  --   1. The specified account only
  --   2. All folders at each level before proceeding to the next level
  --   3. Searches level-by-level (top-level first, then second-level, etc.)
  --
  -- Returns: The first folder with a matching name found in the account, or missing value if not found
  tell application "Notes"
    repeat with acc in accounts
      try
        set accName to name of acc
        if accName is accountName then
          -- Found the account, initialize queue with top-level folders
          try
            set folderQueue to folders of acc
            -- Process queue level by level (BFS)
            return my search_folders_bfs(folderQueue, targetFolderName)
          on error
            -- Couldn't access folders in this account
            return missing value
          end try
        end if
      on error
        -- Skip accounts that can't be accessed
      end try
    end repeat
  end tell
  return missing value
end find_folder_by_account_and_name

on search_folders_bfs(folderQueue, targetName)
  -- Breadth-first search helper function
  -- Processes folders level by level using a queue
  --
  -- Algorithm: 
  --   1. Check each folder in the current level queue
  --   2. If match found, return it
  --   3. Otherwise, add all subfolders to the next level queue
  --   4. Continue until queue is empty or match is found
  --
  -- Returns: The first folder with a matching name, or missing value if not found
  tell application "Notes"
    repeat while (count of folderQueue) > 0
      -- Process all folders at current level
      set nextLevelQueue to {}
      
      repeat with f in folderQueue
        try
          -- Check if current folder matches
          if name of f is targetName then
            return f
          end if
          
          -- Add all subfolders to next level queue
          try
            set subFolders to folders of f
            repeat with sf in subFolders
              set end of nextLevelQueue to sf
            end repeat
          on error
            -- Folder might not have subfolders, continue
          end try
        on error
          -- Skip folders that can't be accessed
        end try
      end repeat
      
      -- Move to next level
      set folderQueue to nextLevelQueue
    end repeat
  end tell
  return missing value
end search_folders_bfs

-- ===== Duplicate-title helper =====

on short_id_for_note(n)
  -- Prefer the note's internal id (more stable) if the Notes scripting interface exposes it.
  -- Some macOS versions support "id of n". If it errors, fall back.
  tell application "Notes"
    try
      set rawId to id of n
      return my short_hash(rawId)
    on error
      -- Fallback: timestamp + a little randomness
      set d to (current date)
      set t to (time of d) as integer
      set r to (random number from 1000 to 9999) as integer
      return (t as text) & "-" & (r as text)
    end try
  end tell
end short_id_for_note

on short_hash(s)
  -- Make a small, filename-safe id from an arbitrary string.
  -- This is not cryptographic; it’s a simple rolling hash -> base36-ish.
  set h to 0
  set n to length of s
  repeat with i from 1 to n
    set c to (ASCII number of character i of s)
    set h to (h * 131 + c) mod 2147483647
  end repeat
  return my to_base36(h)
end short_hash

on to_base36(x)
  if x is 0 then return "0"
  set digits to "0123456789abcdefghijklmnopqrstuvwxyz"
  set v to x
  set out to ""
  repeat while v > 0
    set r to v mod 36
    set out to (character (r + 1) of digits) & out
    set v to v div 36
  end repeat
  return out
end to_base36

-- ===== Filesystem helpers =====

on ensure_dir_posix(dirPosix)
  -- mkdir -p
  do shell script "mkdir -p " & quoted form of dirPosix
end ensure_dir_posix

on write_text_file_posix(pathPosix, contentsText)
  -- write UTF-8 using AppleScript's native file writing
  -- This safely handles HTML, special characters, quotes, newlines, etc. without shell escaping
  --
  -- Note: The "CFURLGetFSRef was passed a URL which has no scheme" warning is benign.
  -- It's an internal AppleScript/Foundation issue that doesn't affect functionality.
  -- File writing will succeed regardless of this warning.
  
  set theFile to POSIX file pathPosix
  try
    set fileRef to open for access theFile with write permission
    set eof fileRef to 0 -- truncate file
    write contentsText to fileRef as «class utf8»
    close access fileRef
  on error errMsg
    try
      close access fileRef
    end try
    error "Failed to write file: " & errMsg
  end try
end write_text_file_posix

-- ===== Sanitizers =====

on sanitize_filename(s)
  -- For filenames: keep it readable but safe.
  set out to my sanitize_path_component(s)
  if out is "" then set out to "untitled"
  return out
end sanitize_filename

on sanitize_path_component(s)
  -- Remove / replace characters that are problematic across filesystems.
  set badChars to {":", "/", "\\", "*", "?", "\"", "<", ">", "|", return, linefeed, tab}
  set out to s

  repeat with c in badChars
    set AppleScript's text item delimiters to c
    set parts to text items of out
    set AppleScript's text item delimiters to "-"
    set out to parts as text
  end repeat
  set AppleScript's text item delimiters to ""

  -- Trim whitespace-ish runs
  set out to my trim(out)

  -- Avoid trailing dot/space (can be annoying on some systems)
  repeat while out ends with " " or out ends with "."
    set out to text 1 thru ((length of out) - 1) of out
  end repeat

  return out
end sanitize_path_component

on trim(s)
  set t to s
  repeat while t begins with " "
    if (length of t) is 1 then return ""
    set t to text 2 thru -1 of t
  end repeat
  repeat while t ends with " "
    if (length of t) is 1 then return ""
    set t to text 1 thru -2 of t
  end repeat
  return t
end trim
