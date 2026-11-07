# Windows Terminal Theme Manager

A lightweight PowerShell GUI for choosing, creating, editing, saving,
and applying color themes for **Windows Terminal**.

The application provides a visual editor for terminal colors, a live
preview, a small collection of built-in themes, and a local library for
themes you create yourself. It updates the Windows Terminal
`settings.json` file so the selected color scheme becomes the default
profile's scheme.

## Features

-   **Choose an existing theme** from the included themes or your saved
    custom themes.
-   **Create your own theme** with a name, application appearance (light
    or dark), and custom HEX colors.
-   Customize the terminal background, foreground, cursor, selection
    background, and all 16 ANSI palette colors.
-   Preview background and foreground changes while editing.
-   Save custom themes locally, then reopen and edit them later.
-   Delete custom themes from the theme library.
-   Apply a theme to Windows Terminal's default profile.
-   Back up `settings.json` before applying changes.
-   Detect invalid theme colors and malformed saved theme entries.
-   Open the Windows Terminal settings file directly from the
    application.

## Included themes

  Theme            Appearance   Description
  ---------------- ------------ --------------------------------------------
  Pure White       Light        White background with black text
  One Half Light   Light        Soft off-white background and muted colors
  Campbell         Dark         Classic Windows terminal color scheme
  Tango Light      Light        White background with a colorful palette
  Vintage          Dark         Black background with muted grey text

## Requirements

-   Windows 10 or Windows 11
-   Windows Terminal installed and opened at least once
-   Windows PowerShell 5.1 (the application uses WPF for its graphical
    interface)

The script does not require third-party PowerShell modules.

## Run

1.  Download `TerminalThemeSwitcher.ps1`.
2.  Open Windows PowerShell.
3.  Change directory to the folder containing the script.
4.  Run:

``` powershell
powershell.exe -ExecutionPolicy Bypass -File .\TerminalThemeSwitcher.ps1
```

This command bypasses the execution policy for this process only. It
does not permanently change your machine's execution policy.

## Using the application

### Choose an existing theme

1.  Select **Choose existing theme**.
2.  Pick a built-in or saved custom theme from the dropdown.
3.  Review its colors in the editor and preview.
4.  Select **Apply to Terminal** to apply it.

### Create a custom theme

1.  Select **Create a new theme**.
2.  Enter a theme name.
3.  Choose the Windows Terminal application appearance: Light or Dark.
4.  Enter HEX values for the background, foreground, cursor, and
    selection colors.
5.  Customize the 16 ANSI palette colors.
6.  Select **Save custom theme** to keep it in your local theme library.
7.  Select **Apply to Terminal** when you want to use it.

HEX values must use the `#RRGGBB` format, for example `#FFFFFF` or
`#202020`.

The ANSI palette fields are ordered as follows:

1.  Black
2.  Red
3.  Green
4.  Yellow
5.  Blue
6.  Purple
7.  Cyan
8.  White
9.  Bright black
10. Bright red
11. Bright green
12. Bright yellow
13. Bright blue
14. Bright purple
15. Bright cyan
16. Bright white

### Edit or delete a custom theme

Select the saved custom theme from the dropdown, change its values, and
select **Save custom theme** to update it. Use **Delete custom** to
remove a saved custom theme. Built-in themes cannot be deleted.

## Where settings are stored

Custom themes are saved separately from Windows Terminal's
configuration:

``` text
%LOCALAPPDATA%\TerminalThemeSwitcher\themes.json
```

The application looks for Windows Terminal's `settings.json` in the
standard package or user-local locations. It applies the selected color
scheme to `profiles.defaults.colorScheme` and sets the application theme
to Light or Dark.

Before applying a theme, the application creates a timestamped backup
alongside `settings.json`, for example:

``` text
settings.json.backup-20261107-123000
```

The application retains the 10 newest backups it finds in that settings
directory.

After applying a theme, close and reopen Windows Terminal to see the
full change.

## Important notes

-   Applying a theme changes the **default profile**. A profile with its
    own `colorScheme` setting can override the default.
-   The application changes Windows Terminal's application appearance
    setting to Light or Dark. This is separate from the terminal pane's
    color scheme.
-   Windows Terminal settings support comments, but the script parses
    and serializes the JSON when applying a theme. **Comments and
    original formatting in `settings.json` may not be preserved.** A
    timestamped backup is created before the file is changed; use it to
    restore the previous configuration if needed.
-   This is a Windows Terminal configuration editor, not a replacement
    terminal emulator. It does not modify PowerShell itself or change
    the Windows-wide theme.

## Project status

This project is a PowerShell/WPF utility. The current version provides
built-in themes and local custom-theme management. It does not currently
provide a dedicated import/export workflow for sharing individual theme
files.

## License

Add your chosen open-source license before publishing this project. For
example, include an `MIT` license file if you intend to distribute it
under the MIT License.
