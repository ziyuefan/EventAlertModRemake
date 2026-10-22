---
name: wow-casc
description: Read, search, verify, and extract files from a local World of Warcraft CASC installation. Use for Blizzard UI source, BLP textures, audio, FileDataID, CASC paths, or current client build verification. Do not use for ordinary files under the live AddOns directory.
---

# Use wow-casc

Set the working directory to this Skill's repository and invoke the CLI with repository-relative paths such as `node scripts/wow-casc.js ...`. Do not hard-code this repository's machine-specific absolute path.

Follow this workflow:

1. Use `read` directly when the exact CASC path is known.
2. Use `find` only when the path is unknown. Specify the likely branch and a small `--max-results` value.
3. Treat every listfile match as a candidate. Prove current-build readability with `--verify` or an exact `read`.
4. Record `buildNumber` with every source or artifact used as evidence.
5. Write binary files with `--output`; do not put base64 binary data into model context.
6. Use `extract` for batches instead of running dozens of single-file reads.
7. Respect the caller's workspace, privacy, and managed ResearchWorkspace rules.
8. Do not install dependencies automatically. If dependencies are missing, ask the user to run `npm ci`.

Use the `wow-casc` MCP only when the current host has no Shell and exposes that MCP server. Close every MCP handle with `casc_close` when finished.

See [README.md](README.md) for command parameters, examples, candidate-versus-readable semantics, and testing instructions.
