# wow-casc

`wow-casc` reads, searches, verifies, and extracts files from a local World of Warcraft CASC installation. One shared CASC core powers three entry points:

- the CLI, for Codex, Claude Code, and other agents with a Shell;
- the repository Agent Skill, which guides correct CLI use;
- the MCP adapter, for hosts without a Shell, fine-grained authorization, or existing MCP callers.

The MCP adapter retains the compatible `casc_open`, `casc_find`, `casc_read`, and `casc_close` tools. The CLI and MCP do not call each other.

## CLI quick start

Run the CLI from the repository root:

```powershell
node scripts/wow-casc.js info `
  --storage '<WoW>\Data' `
  --json
```

After installing dependencies, npm can also expose the local `wow-casc` bin through normal npm workflows. This repository is not published as an npm package.

## Agent Skill

The root [`SKILL.md`](SKILL.md) teaches an agent to prefer exact `read` operations, use narrow verified searches when paths are unknown, write binary data directly to files, and use `extract` for batches. It intentionally links here for detailed parameters instead of duplicating the CLI reference.

Skill discovery depends on the host. A Shell-capable host should use the CLI. Fall back to the `wow-casc` MCP server only when the current host has no Shell and exposes that MCP integration.

## MCP compatibility entry point

Start the stdio server with:

```powershell
node index.js
```

Example MCP configuration:

```json
{
  "mcpServers": {
    "wow-casc": {
      "type": "stdio",
      "command": "node",
      "args": ["X:\\Tools\\wow-casc\\index.js"]
    }
  }
}
```

MCP server metadata is `wow-casc` version `1.4.0`. Handles expire after 10 minutes and should still be closed explicitly with `casc_close`.

## Commands

### info

```powershell
node scripts/wow-casc.js info `
  --storage '<WoW>\Data' `
  --json
```

Returns `codeName`, `buildNumber`, `localFileCount`, and the normalized storage path.

### find

```powershell
node scripts/wow-casc.js find `
  --storage '<WoW>\Data' `
  --mask 'interface/addons/blizzard_*/mainline/*.lua' `
  --branch retail `
  --verify `
  --max-results 20 `
  --json
```

Wildcards are case-insensitive: `*` matches any characters and `?` matches one character. Branch values include `retail`/`mainline`, `ptr`, `classic`, `vanilla`, `tbc`, `wrath`, `cata`, and `mists`. `--environment`, `--flavor`, `--product-flavor`, and `--client-flavor` are accepted aliases for the branch input. Use `--listfile <file>` to override the cached community listfile.

The default result limit is 200 and the maximum is 1000. Output includes the active build, candidate and returned counts, pagination metadata, verification state, and listfile source.

### read

Text files can be returned directly:

```powershell
node scripts/wow-casc.js read `
  --storage '<WoW>\Data' `
  --path 'interface/addons/blizzard_uiparent/mainline/uiparent.lua' `
  --json
```

Binary files must be written to disk:

```powershell
node scripts/wow-casc.js read `
  --storage '<WoW>\Data' `
  --path 'interface/tooltips/chatbubble.blp' `
  --output '.\ChatBubble.blp' `
  --json
```

Existing files are protected unless `--force` is supplied. The JSON result includes the build, CASC path, output path, byte size, encoding, and SHA-256.

### extract

```powershell
node scripts/wow-casc.js extract `
  --storage '<WoW>\Data' `
  --manifest '.\paths.txt' `
  --output-dir '.\extracted' `
  --json
```

Repeat `--path` for explicit paths, or provide a manifest with one CASC path per line. Blank lines and lines beginning with `#` are ignored. CASC-relative directories are preserved. Absolute paths, `..`, drive-qualified paths, and other output-directory escapes are rejected. All files are reported; any failure produces a nonzero exit code. Existing outputs require `--force`.

## Listfile candidates versus current-build files

The community listfile contains names collected across products and versions. A listfile match is only a candidate. It does not prove that the active client build contains or can read the path.

Use `find --verify` to test returned candidates, or use an exact `read` as the stronger proof. Verification applies only to returned candidates, not every matching listfile row. The listfile is cached for one day; a failed refresh falls back to an older cache when available, and downloaded size is validated before replacement.

## buildNumber

Every evidence record should include `buildNumber`. Blizzard can move, replace, or remove CASC resources between client builds, so a path or hash without its build is incomplete provenance.

## Binary output

The CLI writes original binary bytes directly to `--output` and does not inherit MCP's transport limits. It never prints a large binary as base64 by default. The compatibility MCP adapter continues to return binary as base64 and retains the existing 100 KB text and 500 KB binary response truncation behavior.

## Installation and dependencies

Requirements:

- Node.js 18 or newer;
- a local World of Warcraft installation;
- dependencies installed from the lockfile.

Install explicitly when needed:

```powershell
npm ci
```

The CLI and Skill never run dependency installation automatically. Use the WoW root `Data` directory, such as `<WoW>\Data`; do not use `_retail_\Data`.

## Tests

Offline unit and protocol tests do not require WoW:

```powershell
npm test
```

Run real-client tests with an environment-scoped storage path:

```powershell
$env:WOW_CASC_DATA = '<WoW>\Data'
npm run test:live
```

Maintainers can additionally set `WOW_CASC_BASELINE_BLP` to a pre-refactor `ChatBubble.blp` artifact from the same build. The live test then compares its byte length and SHA-256 with both the CLI and MCP results without hard-coding either value.

## Version

Version `1.4.0` adds the CLI and Agent Skill, extracts the shared CASC core, preserves the four MCP tools, supports direct binary output and batch extraction, and renames the project to `wow-casc`.

This repository currently has no `LICENSE` file.
