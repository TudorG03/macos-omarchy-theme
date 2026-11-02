# Contributing

## Reporting bugs

Open an issue with your Omarchy and Hyprland versions (`omarchy version`, `hyprctl version`),
what you did, and what happened. Include the output of `hyprctl configerrors` if it isn't empty.

Check screenshots and logs for usernames, hostnames and file names before posting them.

## Making changes

1. Fork the repo and create a branch.
2. Edit the files in this repo and run `./install.sh --yes` to try them. Use a spare machine
   or VM if you can, because it changes your desktop.
3. Run `tests/check.sh`.
4. Open a pull request describing the change and how you tested it. Include a screenshot for visual changes.

`tests/check.sh` checks script syntax and plugin manifests, confirms that the hook enables every
plugin, and looks for personal paths and email addresses. `scripts/build-bangs.py` regenerates Spotlight's
bang list.

## Layout

| Path | Installed to |
|---|---|
| `theme/` | `~/.config/omarchy/themes/cupertino` |
| `plugins/` | `~/.config/omarchy/plugins` |
| `hooks/cupertino` | `~/.config/omarchy/hooks/theme-set.d/cupertino` |
| `icons/Cupertino` | `~/.local/share/icons/Cupertino` |

A new plugin must also be added to `PLUGINS` in `hooks/cupertino`.
