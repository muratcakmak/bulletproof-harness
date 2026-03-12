#!/usr/bin/env node

/**
 * Bulletproof Harness CLI
 *
 * Autonomous ticket-driven development orchestrator for Claude Code.
 *
 * Commands:
 *   harness init [name]        — Initialize harness in current directory
 *   harness plan               — Interactive PRD/plan wizard → generates tickets
 *   harness next               — Pick up next ready ticket
 *   harness done [ticket-id]   — Verify AC + archive + advance
 *   harness status             — Show queue status + progress
 *   harness loop               — Auto-loop: run tickets through Claude Code
 *   harness prompt [ticket-id] — Print Claude Code prompt for a ticket
 *   harness memory <cmd>       — Search/update memory
 *   harness skill <cmd>        — List/run/create skills
 *   harness verify [ticket-id] — Run acceptance verification
 */

import { Command } from "commander";
import { initCommand } from "./commands/init.js";
import { planCommand } from "./commands/plan.js";
import { nextCommand } from "./commands/next.js";
import { doneCommand } from "./commands/done.js";
import { statusCommand } from "./commands/status.js";
import { loopCommand } from "./commands/loop.js";
import { promptCommand } from "./commands/prompt.js";
import { memoryCommand } from "./commands/memory.js";
import { skillCommand } from "./commands/skill.js";
import { verifyCommand } from "./commands/verify.js";

const program = new Command();

program
  .name("harness")
  .description("Bulletproof Harness — autonomous ticket-driven development with Claude Code")
  .version("0.1.0");

program.addCommand(initCommand);
program.addCommand(planCommand);
program.addCommand(nextCommand);
program.addCommand(doneCommand);
program.addCommand(statusCommand);
program.addCommand(loopCommand);
program.addCommand(promptCommand);
program.addCommand(memoryCommand);
program.addCommand(skillCommand);
program.addCommand(verifyCommand);

program.parse();
