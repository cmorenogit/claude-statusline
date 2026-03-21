#!/usr/bin/env node

const fs = require("fs");
const path = require("path");
const { execSync } = require("child_process");

// ── Colors ──────────────────────────────────────────────
const blue = "\x1b[38;2;0;153;255m";
const green = "\x1b[38;2;0;175;80m";
const red = "\x1b[38;2;255;85;85m";
const dim = "\x1b[2m";
const reset = "\x1b[0m";

const CLAUDE_DIR = path.join(process.env.HOME, ".claude");
const SETTINGS_FILE = path.join(CLAUDE_DIR, "settings.json");
const STATUSLINE_FILE = path.join(CLAUDE_DIR, "statusline-command.sh");
const BACKUP_FILE = path.join(CLAUDE_DIR, "statusline-command.sh.backup");
const SOURCE_FILE = path.join(__dirname, "statusline.sh");
const THEMES_SRC = path.join(__dirname, "..", "themes");
const THEMES_DEST = path.join(CLAUDE_DIR, "statusline-themes");

function log(icon, msg) {
  console.log(`  ${icon} ${msg}`);
}

function header() {
  console.log();
  console.log(`  ${blue}Claude Statusline Installer${reset}`);
  console.log(`  ${dim}${"─".repeat(27)}${reset}`);
  console.log();
}

function checkDeps() {
  const deps = ["jq", "curl", "git"];
  const missing = deps.filter((d) => {
    try {
      execSync(`command -v ${d}`, { stdio: "ignore" });
      return false;
    } catch {
      return true;
    }
  });

  if (missing.length > 0) {
    log(`${red}✗${reset}`, `Missing dependencies: ${missing.join(", ")}`);
    process.exit(1);
  }
  log(`${green}✓${reset}`, `Dependencies found (${deps.join(", ")})`);
}

function detectBash() {
  // Prefer bash 4+ for mapfile support
  const candidates = [
    "/opt/homebrew/bin/bash",
    "/usr/local/bin/bash",
    "/usr/bin/bash",
    "/bin/bash",
  ];

  for (const candidate of candidates) {
    try {
      const version = execSync(`${candidate} --version 2>/dev/null`, {
        encoding: "utf-8",
      });
      const match = version.match(/version (\d+)/);
      if (match && parseInt(match[1]) >= 4) {
        return candidate;
      }
    } catch {}
  }

  // Fallback: check env bash
  try {
    const version = execSync("bash --version 2>/dev/null", {
      encoding: "utf-8",
    });
    const match = version.match(/version (\d+)/);
    if (match && parseInt(match[1]) >= 4) {
      return "bash";
    }
  } catch {}

  log(
    `${red}✗${reset}`,
    "Bash 4+ required (for mapfile). Install with: brew install bash"
  );
  process.exit(1);
}

function install() {
  header();
  checkDeps();

  const bashPath = detectBash();
  log(`${green}✓${reset}`, `Bash 4+ found at ${dim}${bashPath}${reset}`);

  // Ensure .claude directory exists
  if (!fs.existsSync(CLAUDE_DIR)) {
    fs.mkdirSync(CLAUDE_DIR, { recursive: true });
  }

  // Backup existing statusline
  if (fs.existsSync(STATUSLINE_FILE)) {
    fs.copyFileSync(STATUSLINE_FILE, BACKUP_FILE);
    log(`${green}✓${reset}`, `Backed up existing statusline to ${dim}${BACKUP_FILE}${reset}`);
  }

  // Read source and patch shebang with detected bash
  let script = fs.readFileSync(SOURCE_FILE, "utf-8");
  script = script.replace(/^#!.*\n/, `#!${bashPath}\n`);

  // Write statusline script
  fs.writeFileSync(STATUSLINE_FILE, script, { mode: 0o755 });
  log(`${green}✓${reset}`, `Installed statusline to ${dim}${STATUSLINE_FILE}${reset}`);

  // Install themes
  if (fs.existsSync(THEMES_SRC)) {
    if (!fs.existsSync(THEMES_DEST)) {
      fs.mkdirSync(THEMES_DEST, { recursive: true });
    }
    const themes = fs.readdirSync(THEMES_SRC).filter((f) => f.endsWith(".sh"));
    for (const theme of themes) {
      fs.copyFileSync(path.join(THEMES_SRC, theme), path.join(THEMES_DEST, theme));
    }
    log(`${green}✓${reset}`, `Installed ${themes.length} themes to ${dim}${THEMES_DEST}${reset}`);
  }

  // Update settings.json
  let settings = {};
  if (fs.existsSync(SETTINGS_FILE)) {
    try {
      settings = JSON.parse(fs.readFileSync(SETTINGS_FILE, "utf-8"));
    } catch {}
  }

  settings.statusLine = {
    type: "command",
    command: `${bashPath} "${STATUSLINE_FILE}"`,
  };

  fs.writeFileSync(SETTINGS_FILE, JSON.stringify(settings, null, 2) + "\n");
  log(`${green}✓${reset}`, `Updated ${dim}settings.json${reset} with statusLine config`);

  console.log();
  log(`${green}Done!${reset}`, "Restart Claude Code to see your new status line.");
  console.log();
}

function uninstall() {
  header();

  // Restore backup if exists
  if (fs.existsSync(BACKUP_FILE)) {
    fs.copyFileSync(BACKUP_FILE, STATUSLINE_FILE);
    fs.unlinkSync(BACKUP_FILE);
    log(`${green}✓${reset}`, "Restored previous statusline from backup");
  } else if (fs.existsSync(STATUSLINE_FILE)) {
    fs.unlinkSync(STATUSLINE_FILE);
    log(`${green}✓${reset}`, "Removed statusline script");
  }

  // Remove themes
  if (fs.existsSync(THEMES_DEST)) {
    fs.rmSync(THEMES_DEST, { recursive: true });
    log(`${green}✓${reset}`, "Removed themes directory");
  }

  // Remove statusLine from settings
  if (fs.existsSync(SETTINGS_FILE)) {
    try {
      const settings = JSON.parse(fs.readFileSync(SETTINGS_FILE, "utf-8"));
      delete settings.statusLine;
      fs.writeFileSync(
        SETTINGS_FILE,
        JSON.stringify(settings, null, 2) + "\n"
      );
      log(`${green}✓${reset}`, "Removed statusLine config from settings.json");
    } catch {}
  }

  console.log();
  log(`${green}Done!${reset}`, "Statusline uninstalled. Restart Claude Code.");
  console.log();
}

// ── Main ──────────────────────────────────────────────
if (process.argv.includes("--uninstall")) {
  uninstall();
} else {
  install();
}
