# Security Policy

## Scope

Open Godot MCP is a local development bridge: the Godot plugin runs a WebSocket server bound to **localhost only** (`127.0.0.1:6505`) and the Rust server connects to it from the same machine. It is designed for single-user, local use.

Please be aware of what the bridge can do by design:

- Any connected MCP client gets **full control of the Godot editor**, including `execute_editor_script`, which can run arbitrary GDScript — and therefore read/write files, make network requests, and execute OS commands.
- There is no authentication on the WebSocket: any local process can connect to `127.0.0.1:6505` while the editor is open.

**Recommendations**: only connect AI clients you trust, do not expose port 6505 to any network (firewall rules, SSH tunnels, shared machines, containers), and review AI-proposed destructive operations before approving them.

## Supported versions

Security fixes are applied to the latest release only.

| Version | Supported |
| ------- | --------- |
| latest  | ✅        |

## Reporting a vulnerability

Please do **not** open a public issue for security reports. Instead:

- Use [GitHub private vulnerability reporting](https://github.com/OneStepAt4time/open-godot-mcp/security/advisories/new), or
- Email: manudis2395@gmail.com

We aim to acknowledge reports within 72 hours.
