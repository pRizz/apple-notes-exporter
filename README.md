# apple-notes-exporter

Export Apple Notes to HTML files with preserved folder structure. Recursively exports notes from a specified folder and all its subfolders, creating a mirrored directory tree.

## Features

- 🔍 **Recursive folder search**: Finds folders at any depth using breadth-first search (BFS)
- 📁 **Preserved structure**: Maintains the exact folder hierarchy in the output directory
- 📝 **HTML export**: Each note is exported as an HTML file with rich text formatting
- 🔐 **Multi-account support**: Works with iCloud, Gmail, and other Notes accounts
- 🎯 **Account specification**: Handle duplicate folder names across accounts
- 🆔 **Unique IDs**: Notes include short IDs to prevent filename conflicts

## Requirements

- macOS (AppleScript support required)
- Apple Notes app
- Automation permissions granted for the Notes app (see [Setup](#setup))

## Setup

1. Clone or download this repository
2. Grant Automation permissions:
   - Open **System Settings** > **Privacy & Security** > **Automation**
   - Ensure **Terminal** (or **Script Editor**) has permission to control **Notes**
   - If the app isn't listed, run the script once and macOS will prompt you to grant permission

## Usage

### Show Help

To see usage instructions:

```bash
osascript scripts/export_notes.applescript
```

### List Available Folders

To see all available top-level folders across all accounts:

```bash
osascript scripts/export_notes.applescript list   # or "ls"
```

This will display folders in the format: `AccountName > FolderName`

### Export a Folder

Basic usage (searches all accounts, finds first match):

```bash
osascript scripts/export_notes.applescript export "Folder Name" "/path/to/output"
```

Example:

```bash
osascript scripts/export_notes.applescript export "My Journal" "./output"
```

### Export from Specific Account

If you have duplicate folder names across accounts, specify the account:

```bash
osascript scripts/export_notes.applescript export "AccountName:FolderName" "/path/to/output"
```

Examples:

```bash
# Export from iCloud account
osascript scripts/export_notes.applescript export "iCloud:My Journal" "./output"

# Export from Google account
osascript scripts/export_notes.applescript export "Google:Work Notes" "./output"
```

## How It Works

1. **Folder Search**: The script uses breadth-first search (BFS) to find folders at any depth level-by-level
2. **Export**: Once found, it recursively exports:
   - All notes in the folder
   - All subfolders and their contents
   - Preserves the folder structure in the output directory
3. **Naming**: Each exported file is named: `Note Title -- short-id.html`

## Output Structure

The exported files maintain the same folder structure as in Notes:

```
output/
└── My Journal/
    ├── Some Note -- oaotto.html
    ├── Another Note -- oaohaa.html
    └── Subfolder/
        └── Note Title -- abc123.html
```

## Troubleshooting

### "Account Unknown" or "Access Restricted" Warnings

- Some folders from external accounts (like Gmail) may show warnings but can still be exported
- Try using the `AccountName:FolderName` format to be explicit

### Permission Errors

- Ensure Automation permissions are granted (see [Setup](#setup))
- Try quitting and reopening Terminal after granting permissions
- Run the script once to trigger the permission prompt if needed

### Folder Not Found

- Use the `list` (or `ls`) command to see all available folders with their exact names
- Folder names are case-sensitive
- If duplicates exist, use the `AccountName:FolderName` format

## Notes

- The script searches recursively through **all** folder levels, not just top-level folders
- Once a folder is found, it exports that folder and all its subfolders recursively
- HTML files preserve the rich text formatting from Notes
- Short IDs are generated to prevent filename conflicts for notes with duplicate titles

## License

See [LICENSE](LICENSE) file for details.
