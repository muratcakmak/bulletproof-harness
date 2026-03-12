/**
 * harness skill <subcommand>
 *
 * Skills are reusable capabilities stored in harness/skills/.
 * Each skill is a directory containing:
 *   - SKILL.md        — Instructions/prompt template for Claude Code
 *   - run.sh          — (optional) Executable script
 *   - config.json     — (optional) Metadata: name, description, triggers
 *
 * Subcommands:
 *   harness skill list              — List available skills
 *   harness skill run <name> [args] — Run a skill (via Claude Code or script)
 *   harness skill create <name>     — Scaffold a new skill
 *   harness skill info <name>       — Show skill details
 */

import { Command } from "commander";
import { existsSync, readFileSync, mkdirSync, writeFileSync, readdirSync } from "fs";
import chalk from "chalk";
import { error, success, info, banner } from "../lib/display.js";
import { getPaths, findHarnessRoot } from "../lib/paths.js";
import { hasClaudeCode, runClaudeCode, run } from "../lib/shell.js";

interface SkillConfig {
  name: string;
  description: string;
  type: "prompt" | "script" | "hybrid";
  triggers?: string[];
  model?: string;
  maxTurns?: number;
}

function loadSkills(skillsDir: string): Map<string, SkillConfig> {
  const skills = new Map<string, SkillConfig>();
  if (!existsSync(skillsDir)) return skills;

  for (const entry of readdirSync(skillsDir, { withFileTypes: true })) {
    if (!entry.isDirectory()) continue;
    const configPath = `${skillsDir}/${entry.name}/config.json`;
    const skillMdPath = `${skillsDir}/${entry.name}/SKILL.md`;

    if (existsSync(configPath)) {
      try {
        const config = JSON.parse(readFileSync(configPath, "utf-8")) as SkillConfig;
        skills.set(entry.name, config);
      } catch {
        // Fallback to defaults
        skills.set(entry.name, {
          name: entry.name,
          description: existsSync(skillMdPath) ? "Prompt-based skill" : "Unknown",
          type: existsSync(`${skillsDir}/${entry.name}/run.sh`) ? "script" : "prompt",
        });
      }
    } else if (existsSync(skillMdPath)) {
      // Read first line as description
      const firstLine = readFileSync(skillMdPath, "utf-8").split("\n")[0].replace(/^#\s*/, "");
      skills.set(entry.name, {
        name: entry.name,
        description: firstLine,
        type: existsSync(`${skillsDir}/${entry.name}/run.sh`) ? "hybrid" : "prompt",
      });
    }
  }

  return skills;
}

export const skillCommand = new Command("skill")
  .description("Manage and run skills")
  .addCommand(
    new Command("list")
      .description("List available skills")
      .action(async () => {
        const root = findHarnessRoot();
        if (!root) { error("No harness found."); return; }
        const paths = getPaths(root);
        const skills = loadSkills(paths.skills);

        if (skills.size === 0) {
          info("No skills found. Create one with: harness skill create <name>");
          return;
        }

        console.log(banner);
        console.log(chalk.bold("  Available Skills:\n"));

        for (const [name, config] of skills) {
          const typeTag = config.type === "prompt"
            ? chalk.blue("[prompt]")
            : config.type === "script"
              ? chalk.green("[script]")
              : chalk.magenta("[hybrid]");
          console.log(`  ${typeTag} ${chalk.white(name)} — ${chalk.dim(config.description)}`);
        }
        console.log("");
      })
  )
  .addCommand(
    new Command("run")
      .description("Run a skill")
      .argument("<name>", "Skill name")
      .argument("[args...]", "Additional arguments passed to the skill")
      .option("--dry-run", "Print the prompt without running Claude Code")
      .action(async (name: string, args: string[], opts: { dryRun?: boolean }) => {
        const root = findHarnessRoot();
        if (!root) { error("No harness found."); return; }
        const paths = getPaths(root);

        const skillDir = `${paths.skills}/${name}`;
        if (!existsSync(skillDir)) {
          error(`Skill not found: ${name}`);
          info(`Available: ${Array.from(loadSkills(paths.skills).keys()).join(", ") || "none"}`);
          return;
        }

        const skillMdPath = `${skillDir}/SKILL.md`;
        const runShPath = `${skillDir}/run.sh`;
        const configPath = `${skillDir}/config.json`;

        let config: SkillConfig = {
          name,
          description: "",
          type: "prompt",
        };
        if (existsSync(configPath)) {
          try { config = JSON.parse(readFileSync(configPath, "utf-8")); } catch {}
        }

        // --- Run script-based skill ---
        if (existsSync(runShPath) && (config.type === "script" || config.type === "hybrid")) {
          info(`Running script: ${name}/run.sh ${args.join(" ")}`);
          const result = run(`bash "${runShPath}" ${args.join(" ")}`, root);
          console.log(result.stdout);
          if (result.exitCode !== 0) console.error(result.stderr);

          // If hybrid, also run prompt part
          if (config.type !== "hybrid" || !existsSync(skillMdPath)) return;
        }

        // --- Run prompt-based skill ---
        if (existsSync(skillMdPath)) {
          const skillContent = readFileSync(skillMdPath, "utf-8");
          const argsStr = args.length > 0 ? `\n\nUser input: ${args.join(" ")}` : "";

          const prompt = `${skillContent}${argsStr}

Context:
- Working directory: ${root}
- Harness scripts available in harness/bin/
- Memory searchable with: harness/bin/search-memory.sh "query"`;

          if (opts.dryRun) {
            console.log(chalk.bold("\n  === PROMPT (dry run) ===\n"));
            console.log(prompt);
            return;
          }

          if (!hasClaudeCode()) {
            error("Claude Code not found. Use --dry-run to see the prompt.");
            return;
          }

          info(`Running skill: ${name} via Claude Code...`);
          const result = runClaudeCode(prompt, {
            cwd: root,
            print: true,
            model: config.model,
            maxTurns: config.maxTurns,
          });

          console.log(result.stdout);
          if (result.exitCode !== 0) console.error(result.stderr);
        }
      })
  )
  .addCommand(
    new Command("create")
      .description("Scaffold a new skill")
      .argument("<name>", "Skill name (kebab-case)")
      .option("--type <type>", "Skill type: prompt, script, hybrid", "prompt")
      .action(async (name: string, opts: { type: string }) => {
        const root = findHarnessRoot();
        if (!root) { error("No harness found."); return; }
        const paths = getPaths(root);

        const skillDir = `${paths.skills}/${name}`;
        if (existsSync(skillDir)) {
          error(`Skill already exists: ${name}`);
          return;
        }

        mkdirSync(skillDir, { recursive: true });

        // config.json
        const config: SkillConfig = {
          name,
          description: `[EDIT] Describe what ${name} does`,
          type: opts.type as SkillConfig["type"],
          triggers: [name],
        };
        writeFileSync(`${skillDir}/config.json`, JSON.stringify(config, null, 2) + "\n");

        // SKILL.md (prompt template)
        writeFileSync(
          `${skillDir}/SKILL.md`,
          `# ${name}

## Purpose
[EDIT: What this skill does]

## Instructions
[EDIT: Step-by-step instructions for Claude Code to follow]

## Inputs
[EDIT: What arguments/context this skill expects]

## Output
[EDIT: What this skill produces]

## Example
[EDIT: Example usage and expected result]
`
        );

        // run.sh (if script or hybrid)
        if (opts.type === "script" || opts.type === "hybrid") {
          writeFileSync(
            `${skillDir}/run.sh`,
            `#!/usr/bin/env bash
set -euo pipefail

# ${name} — [EDIT: description]
# Usage: harness skill run ${name} [args...]

PROJECT_ROOT="$(cd "$(dirname "\${BASH_SOURCE[0]}")/../../.." && pwd)"

echo "[${name}] Running..."

# Your logic here
echo "[${name}] Done."
`
          );
          run(`chmod +x "${skillDir}/run.sh"`);
        }

        success(`Skill created: ${skillDir}/`);
        console.log(chalk.dim(`  Files:`));
        console.log(chalk.dim(`    config.json — Skill metadata`));
        console.log(chalk.dim(`    SKILL.md    — Prompt template for Claude Code`));
        if (opts.type === "script" || opts.type === "hybrid") {
          console.log(chalk.dim(`    run.sh      — Executable script`));
        }
        console.log("");
        console.log(chalk.dim(`  Edit the files, then run: harness skill run ${name}`));
      })
  )
  .addCommand(
    new Command("info")
      .description("Show skill details")
      .argument("<name>", "Skill name")
      .action(async (name: string) => {
        const root = findHarnessRoot();
        if (!root) { error("No harness found."); return; }
        const paths = getPaths(root);

        const skillDir = `${paths.skills}/${name}`;
        if (!existsSync(skillDir)) {
          error(`Skill not found: ${name}`);
          return;
        }

        const configPath = `${skillDir}/config.json`;
        if (existsSync(configPath)) {
          console.log(chalk.bold(`\n  Skill: ${name}\n`));
          const config = JSON.parse(readFileSync(configPath, "utf-8"));
          console.log(chalk.dim(`  Type:        ${config.type}`));
          console.log(chalk.dim(`  Description: ${config.description}`));
          if (config.triggers) console.log(chalk.dim(`  Triggers:    ${config.triggers.join(", ")}`));
          if (config.model) console.log(chalk.dim(`  Model:       ${config.model}`));
          console.log("");
        }

        const skillMdPath = `${skillDir}/SKILL.md`;
        if (existsSync(skillMdPath)) {
          console.log(chalk.bold("  SKILL.md:"));
          const content = readFileSync(skillMdPath, "utf-8");
          for (const line of content.split("\n").slice(0, 20)) {
            console.log(chalk.dim(`  ${line}`));
          }
          console.log("");
        }
      })
  );
