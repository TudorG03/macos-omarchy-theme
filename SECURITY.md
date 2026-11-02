# Security

This theme runs unsandboxed as your user: plugins inside the Omarchy shell, plus `install.sh`, a theme
hook and Hyprland Lua. Read them before installing. The installer needs `sudo` only to install missing
packages, and it verifies the cursor download against a pinned SHA-256 checksum. It also compiles the hyprbars plugin from upstream source, and that plugin runs inside Hyprland itself.

To report a vulnerability privately, use GitHub's
[security advisory form](https://github.com/TudorG03/macos-omarchy-theme/security/advisories/new)
rather than a public issue.
