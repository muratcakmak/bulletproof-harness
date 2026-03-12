/**
 * harness plan — Interactive PRD/plan wizard.
 *
 * Two modes:
 *   1. Interactive: asks questions about the project, generates a plan using Claude Code
 *   2. File: reads an existing _plan.md and generates tickets from it
 */

import { Command } from "commander";
import chalk from "chalk";
import inquirer from "inquirer";
import { readFileSync, writeFileSync, existsSync } from "fs";
import { banner, success, error, info, warn, step } from "../lib/display.js";
import { runScript, hasClaudeCode, runClaudeCode } from "../lib/shell.js";
import { getPaths, findHarnessRoot } from "../lib/paths.js";

export const planCommand = new Command("plan")
  .description("Generate tickets from a plan (interactive or from _plan.md)")
  .option("--from-file", "Skip wizard, generate directly from tickets/_plan.md")
  .option("--prd <file>", "Generate plan from a PRD document")
  .action(async (opts: { fromFile?: boolean; prd?: string }) => {
    console.log(banner);

    const root = findHarnessRoot();
    if (!root) {
      error("No harness found. Run 'harness init' first.");
      return;
    }
    const paths = getPaths(root);

    // --- Mode 1: Generate from existing _plan.md ---
    if (opts.fromFile) {
      if (!existsSync(paths.plan)) {
        error("No tickets/_plan.md found. Create one first.");
        return;
      }
      info("Generating tickets from _plan.md...");
      const result = runScript(paths.bin, "generate-tickets.sh", [], root);
      console.log(result.stdout);
      if (result.exitCode !== 0) {
        error("Ticket generation failed:");
        console.error(result.stderr);
      }
      return;
    }

    // --- Mode 2: Generate from PRD file ---
    if (opts.prd) {
      if (!existsSync(opts.prd)) {
        error(`PRD file not found: ${opts.prd}`);
        return;
      }
      const prdContent = readFileSync(opts.prd, "utf-8");
      info(`Reading PRD from: ${opts.prd}`);

      if (!hasClaudeCode()) {
        error("Claude Code CLI not found. Install it first: npm i -g @anthropic-ai/claude-code");
        console.log(chalk.dim("  Alternatively, manually create tickets/_plan.md and run: harness plan --from-file"));
        return;
      }

      step(1, 3, "Sending PRD to Claude Code for plan generation...");

      const prompt = `You are a project planner. Read this PRD and create a build plan in the exact format below.

OUTPUT FORMAT (output ONLY this, no other text):

### Task 1: [Title]
Summary: [What to build, 1-2 sentences]
Files: [comma-separated list of files to create/modify]
AC: [comma-separated: build, api, unit_test, visual, functional]
Depends: none
Size: Small|Medium|Large
---
### Task 2: [Title]
...

RULES:
- Break the project into 5-15 tasks
- Each task should be completable in 1-3 hours
- Dependencies use task numbers (e.g., "Depends: 1, 2")
- Task 1 should always be project setup with no dependencies
- AC types: build (compiles), api (endpoints work), unit_test (tests pass), visual (UI renders), functional (flows work)
- Order tasks so dependencies flow forward (task N only depends on tasks < N)

PRD:
${prdContent}`;

      const result = runClaudeCode(prompt, {
        cwd: root,
        print: true,
        model: "sonnet",
      });

      if (result.exitCode !== 0) {
        error("Claude Code failed to generate plan:");
        console.error(result.stderr);
        return;
      }

      step(2, 3, "Writing plan to tickets/_plan.md...");
      const planContent = `# Build Plan\n\n${result.stdout.trim()}\n`;
      writeFileSync(paths.plan, planContent);
      success("Plan written to tickets/_plan.md");

      step(3, 3, "Generating ticket files...");
      const genResult = runScript(paths.bin, "generate-tickets.sh", [], root);
      console.log(genResult.stdout);

      if (genResult.exitCode === 0) {
        success("Plan complete! Run 'harness next' to start.");
      }
      return;
    }

    // --- Mode 3: Interactive wizard ---
    console.log(chalk.bold("  Project Plan Wizard"));
    console.log(chalk.dim("  Answer a few questions and we'll generate your build plan.\n"));

    const answers = await inquirer.prompt([
      {
        type: "input",
        name: "description",
        message: "What are you building? (1-2 sentences)",
        validate: (v: string) => v.length > 10 || "Tell me more!",
      },
      {
        type: "input",
        name: "stack",
        message: "Tech stack? (e.g., TypeScript, React, Node.js, PostgreSQL)",
        default: "TypeScript, React, Node.js",
      },
      {
        type: "list",
        name: "size",
        message: "How big is this project?",
        choices: [
          { name: "Small (5-8 tickets, 1-2 days)", value: "small" },
          { name: "Medium (8-15 tickets, 3-5 days)", value: "medium" },
          { name: "Large (15-25 tickets, 1-2 weeks)", value: "large" },
        ],
      },
      {
        type: "input",
        name: "features",
        message: "Key features? (comma-separated)",
        validate: (v: string) => v.length > 5 || "List at least one feature",
      },
      {
        type: "input",
        name: "deadline",
        message: "Deadline? (optional, e.g., March 16, 2026)",
        default: "",
      },
      {
        type: "confirm",
        name: "hasApi",
        message: "Does it have a backend API?",
        default: true,
      },
      {
        type: "confirm",
        name: "hasFrontend",
        message: "Does it have a frontend UI?",
        default: true,
      },
      {
        type: "confirm",
        name: "hasDb",
        message: "Does it have a database?",
        default: true,
      },
    ]);

    const ticketRange = answers.size === "small" ? "5-8" : answers.size === "medium" ? "8-15" : "15-25";

    if (!hasClaudeCode()) {
      // Fallback: generate a template plan without AI
      warn("Claude Code not found — generating template plan.");
      info("Install Claude Code for AI-powered plan generation.");

      const templatePlan = generateTemplatePlan(answers);
      writeFileSync(paths.plan, templatePlan);
      success("Template plan written to tickets/_plan.md");
      console.log(chalk.dim("  Edit it, then run: harness plan --from-file"));
      return;
    }

    step(1, 3, "Generating plan with Claude Code...");

    const prompt = `You are a project planner. Generate a build plan for the following project.

PROJECT:
- Description: ${answers.description}
- Tech Stack: ${answers.stack}
- Key Features: ${answers.features}
- Has Backend API: ${answers.hasApi}
- Has Frontend UI: ${answers.hasFrontend}
- Has Database: ${answers.hasDb}
- Target: ${ticketRange} tickets
${answers.deadline ? `- Deadline: ${answers.deadline}` : ""}

OUTPUT FORMAT (output ONLY this, no other text):

### Task 1: [Title]
Summary: [What to build, 1-2 sentences]
Files: [comma-separated files]
AC: [comma-separated: build, api, unit_test, visual, functional]
Depends: none
Size: Small|Medium|Large
---
### Task 2: [Title]
...

RULES:
- Break into ${ticketRange} tasks
- Task 1 = project setup (no deps)
- Dependencies flow forward only
- Each task completable in 1-3 hours
- AC types: build, api, unit_test, visual, functional`;

    const result = runClaudeCode(prompt, {
      cwd: root,
      print: true,
      model: "sonnet",
    });

    if (result.exitCode !== 0 || !result.stdout.trim()) {
      error("Claude Code failed. Generating template plan instead.");
      const templatePlan = generateTemplatePlan(answers);
      writeFileSync(paths.plan, templatePlan);
      info("Edit tickets/_plan.md, then run: harness plan --from-file");
      return;
    }

    step(2, 3, "Writing plan...");
    writeFileSync(paths.plan, `# Build Plan\n\n${result.stdout.trim()}\n`);
    success("Plan written to tickets/_plan.md");

    step(3, 3, "Generating tickets...");
    const genResult = runScript(paths.bin, "generate-tickets.sh", [], root);
    console.log(genResult.stdout);

    if (genResult.exitCode === 0) {
      console.log("");
      success("Ready! Run 'harness next' to start working.");
    }
  });

function generateTemplatePlan(answers: Record<string, any>): string {
  const tasks: string[] = [];
  let n = 1;

  tasks.push(`### Task ${n}: Project Setup
Summary: Initialize project with ${answers.stack}, configure build tools and development environment
Files: package.json, tsconfig.json, .gitignore, .env.example
AC: build
Depends: none
Size: Small`);
  n++;

  if (answers.hasDb) {
    tasks.push(`### Task ${n}: Database Schema
Summary: Design and implement database schema and migration setup
Files: src/db/schema.ts, src/db/migrations/
AC: build, unit_test
Depends: 1
Size: Medium`);
    n++;
  }

  if (answers.hasApi) {
    tasks.push(`### Task ${n}: API Foundation
Summary: Set up API server with routing, middleware, and health check
Files: src/api/index.ts, src/api/routes/health.ts
AC: build, api
Depends: 1
Size: Medium`);
    n++;
  }

  if (answers.hasFrontend) {
    tasks.push(`### Task ${n}: Frontend Scaffold
Summary: Set up frontend framework with routing and base layout
Files: src/app/App.tsx, src/app/layout/
AC: build, visual
Depends: 1
Size: Medium`);
    n++;
  }

  // Add feature tasks
  const features = answers.features.split(",").map((f: string) => f.trim());
  for (const feature of features) {
    const deps = [1];
    if (answers.hasApi) deps.push(answers.hasDb ? 3 : 2);

    tasks.push(`### Task ${n}: ${feature}
Summary: Implement ${feature.toLowerCase()} feature
Files: [EDIT: add files]
AC: build, ${answers.hasApi ? "api, " : ""}${answers.hasFrontend ? "visual, functional" : "unit_test"}
Depends: ${deps.join(", ")}
Size: Medium`);
    n++;
  }

  // Integration + polish
  tasks.push(`### Task ${n}: Integration & Polish
Summary: Wire everything together, add error handling, test full flow
Files: [EDIT: add files]
AC: build, ${answers.hasApi ? "api, " : ""}${answers.hasFrontend ? "visual, functional" : "unit_test"}
Depends: ${Array.from({ length: n - 1 }, (_, i) => i + 1).join(", ")}
Size: Large`);

  return `# Build Plan\n\n${tasks.join("\n---\n")}\n`;
}
