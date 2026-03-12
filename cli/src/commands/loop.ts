/**
 * harness loop — Auto-loop: run tickets through Claude Code autonomously.
 *
 * The core autonomous mode. Picks up tickets and feeds them to Claude Code
 * one by one until all tickets are done or a failure occurs.
 *
 * Options:
 *   --max-tickets <n>   — Stop after N tickets (default: all)
 *   --max-retries <n>   — Max retries per ticket (default: 3)
 *   --max-turns <n>     — Max Claude Code turns per ticket (default: 50)
 *   --model <model>     — Claude model to use
 *   --dry-run           — Print prompts without running
 *   --skill <name>      — Include a skill in every ticket prompt
 *   --pause             — Pause for confirmation between tickets
 */

import { Command } from "commander";
import { existsSync, readFileSync } from "fs";
import chalk from "chalk";
import inquirer from "inquirer";
import { banner, success, error, warn, info, step, printQueue, statusBadge } from "../lib/display.js";
import { getPaths, findHarnessRoot } from "../lib/paths.js";
import { readQueue, getProgress, promoteDependencies, writeQueue } from "../lib/queue.js";
import { hasClaudeCode, spawnClaudeCode, runScript } from "../lib/shell.js";

export const loopCommand = new Command("loop")
  .description("Auto-loop: run tickets through Claude Code autonomously")
  .option("--max-tickets <n>", "Stop after N tickets", parseInt)
  .option("--max-retries <n>", "Max retries per ticket (default: 3)", parseInt, 3)
  .option("--max-turns <n>", "Max Claude Code turns per ticket (default: 50)", parseInt, 50)
  .option("--model <model>", "Claude model to use")
  .option("--dry-run", "Print prompts without running Claude Code")
  .option("--skill <name>", "Include a skill in every ticket")
  .option("--pause", "Pause for confirmation between tickets")
  .option("--verbose", "Show Claude Code output in real-time")
  .action(async (opts) => {
    console.log(banner);

    const root = findHarnessRoot();
    if (!root) {
      error("No harness found. Run 'harness init' first.");
      return;
    }
    const paths = getPaths(root);

    if (!existsSync(paths.queue)) {
      error("No QUEUE.json found. Run 'harness plan' first.");
      return;
    }

    if (!opts.dryRun && !hasClaudeCode()) {
      error("Claude Code CLI not found.");
      info("Install it: npm i -g @anthropic-ai/claude-code");
      info("Or use --dry-run to see prompts without running.");
      return;
    }

    // Load skill if specified
    let skillContent = "";
    if (opts.skill) {
      const skillPath = `${paths.skills}/${opts.skill}/SKILL.md`;
      if (existsSync(skillPath)) {
        skillContent = readFileSync(skillPath, "utf-8");
        info(`Loaded skill: ${opts.skill}`);
      } else {
        warn(`Skill not found: ${opts.skill}, continuing without it.`);
      }
    }

    console.log(chalk.bold("  Starting autonomous loop...\n"));

    let ticketsCompleted = 0;
    const maxTickets = opts.maxTickets ?? Infinity;
    const startTime = Date.now();

    while (ticketsCompleted < maxTickets) {
      // Reload queue each iteration (it changes as tickets complete)
      const queue = readQueue(paths.queue);
      const progress = getProgress(queue);

      // Promote dependencies
      const promoted = promoteDependencies(queue);
      if (promoted > 0) {
        writeQueue(paths.queue, queue);
        info(`Promoted ${promoted} ticket(s) to ready.`);
      }

      // Find next ready ticket
      const nextTicket = queue.queue.find((t) => t.status === "ready");

      if (!nextTicket) {
        if (progress.done === progress.total) {
          console.log("");
          console.log(chalk.bold.green("  ╔═══════════════════════════════════╗"));
          console.log(chalk.bold.green("  ║   ALL TICKETS COMPLETE!           ║"));
          console.log(chalk.bold.green("  ╚═══════════════════════════════════╝"));
          console.log("");
          const elapsed = Math.round((Date.now() - startTime) / 1000);
          console.log(chalk.dim(`  Completed ${ticketsCompleted} ticket(s) in ${formatDuration(elapsed)}`));
        } else {
          warn("No ready tickets. Remaining tickets may be blocked.");
          printQueue(queue);
        }
        break;
      }

      // --- Assign ticket ---
      console.log("");
      console.log(chalk.bold.cyan(`  ═══ Ticket ${ticketsCompleted + 1}: ${nextTicket.id} ═══`));
      console.log(chalk.dim(`  ${nextTicket.title}`));
      console.log("");

      // Pause if requested
      if (opts.pause && ticketsCompleted > 0) {
        const { proceed } = await inquirer.prompt([
          {
            type: "confirm",
            name: "proceed",
            message: `Continue with ${nextTicket.id}?`,
            default: true,
          },
        ]);
        if (!proceed) {
          info("Loop paused by user.");
          break;
        }
      }

      // Pick up ticket via next-ticket.sh
      const nextResult = runScript(paths.bin, "next-ticket.sh", [], root);
      if (nextResult.exitCode !== 0) {
        error(`Failed to pick up ticket: ${nextResult.stderr}`);
        break;
      }

      // Read ticket content
      const ticketPath = `${paths.tickets}/${nextTicket.id}.md`;
      if (!existsSync(ticketPath)) {
        error(`Ticket file not found: ${ticketPath}`);
        break;
      }
      const ticketContent = readFileSync(ticketPath, "utf-8");

      // Load context
      const memoryContent = existsSync(paths.memoryIndex)
        ? readFileSync(paths.memoryIndex, "utf-8")
        : "";
      const conventionsPath = `${paths.memory}/conventions.md`;
      const conventions = existsSync(conventionsPath)
        ? readFileSync(conventionsPath, "utf-8")
        : "";

      // Build prompt
      const prompt = buildTicketPrompt({
        ticketId: nextTicket.id,
        ticketContent,
        memoryContent,
        conventions,
        skillContent,
        root,
      });

      if (opts.dryRun) {
        console.log(chalk.bold("\n  === DRY RUN — Prompt ===\n"));
        console.log(chalk.dim(prompt.slice(0, 500) + "...\n"));
        info("(dry-run) Would run this through Claude Code.");

        // Simulate completion for dry-run
        ticketsCompleted++;
        continue;
      }

      // --- Run through Claude Code ---
      let retries = 0;
      let ticketDone = false;

      while (retries <= opts.maxRetries && !ticketDone) {
        if (retries > 0) {
          warn(`Retry ${retries}/${opts.maxRetries} for ${nextTicket.id}`);
        }

        step(1, 2, `Running Claude Code (max ${opts.maxTurns} turns)...`);

        try {
          const exitCode = await spawnClaudeCode(prompt, {
            cwd: root,
            maxTurns: opts.maxTurns,
            onStdout: (data) => {
              if (opts.verbose) process.stdout.write(chalk.dim(data));
            },
            onStderr: (data) => {
              if (opts.verbose) process.stderr.write(chalk.red(data));
            },
          });

          if (exitCode !== 0) {
            warn(`Claude Code exited with code ${exitCode}`);
            retries++;
            continue;
          }
        } catch (err: any) {
          error(`Claude Code error: ${err.message}`);
          retries++;
          continue;
        }

        // --- Verify and mark done ---
        step(2, 2, "Verifying acceptance criteria...");
        const doneResult = runScript(paths.bin, "mark-done.sh", [nextTicket.id], root);

        if (doneResult.exitCode === 0) {
          success(`${nextTicket.id} — DONE`);
          ticketDone = true;
          ticketsCompleted++;
        } else {
          warn(`Acceptance criteria not met for ${nextTicket.id}`);
          if (opts.verbose) console.log(chalk.dim(doneResult.stdout));
          retries++;
        }
      }

      if (!ticketDone) {
        error(`Failed after ${opts.maxRetries} retries: ${nextTicket.id}`);

        // Log to bugs
        runScript(paths.bin, "update-memory.sh", [
          "bugs",
          `${nextTicket.id} failed after ${opts.maxRetries} retries in loop mode`,
        ], root);

        // Ask whether to continue
        if (!opts.dryRun) {
          const { action } = await inquirer.prompt([
            {
              type: "list",
              name: "action",
              message: "Ticket failed. What to do?",
              choices: [
                { name: "Skip and continue to next ticket", value: "skip" },
                { name: "Stop the loop", value: "stop" },
                { name: "Retry this ticket", value: "retry" },
              ],
            },
          ]);

          if (action === "stop") break;
          if (action === "retry") continue;
          // skip: move on
        }
      }
    }

    // Final summary
    console.log("");
    console.log(chalk.bold("  ═══ Loop Summary ═══"));
    const elapsed = Math.round((Date.now() - startTime) / 1000);
    console.log(chalk.dim(`  Tickets completed: ${ticketsCompleted}`));
    console.log(chalk.dim(`  Elapsed: ${formatDuration(elapsed)}`));

    const finalQueue = readQueue(paths.queue);
    printQueue(finalQueue);
  });

function buildTicketPrompt(ctx: {
  ticketId: string;
  ticketContent: string;
  memoryContent: string;
  conventions: string;
  skillContent: string;
  root: string;
}): string {
  const sections: string[] = [];

  sections.push(`You are an autonomous engineer completing ticket ${ctx.ticketId}.
Complete ALL acceptance criteria, commit your work, then call harness/bin/mark-done.sh ${ctx.ticketId}.`);

  sections.push(`## TICKET\n\n${ctx.ticketContent}`);

  if (ctx.conventions.trim()) {
    sections.push(`## CONVENTIONS\n\n${ctx.conventions}`);
  }

  if (ctx.memoryContent.trim()) {
    sections.push(`## MEMORY\n\n${ctx.memoryContent}`);
  }

  if (ctx.skillContent.trim()) {
    sections.push(`## SKILL INSTRUCTIONS\n\n${ctx.skillContent}`);
  }

  sections.push(`## RULES
1. Search memory first: harness/bin/search-memory.sh "pattern"
2. Follow conventions above
3. Test: type-check, lint, run tests
4. Update memory: harness/bin/update-memory.sh "category" "note"
5. When ALL AC pass: harness/bin/mark-done.sh ${ctx.ticketId}
6. Commit: git add -A && git commit -m "ticket-${ctx.ticketId}: description"
7. If stuck 3x: harness/bin/update-memory.sh bugs "description" then stop`);

  return sections.join("\n\n---\n\n");
}

function formatDuration(seconds: number): string {
  if (seconds < 60) return `${seconds}s`;
  const mins = Math.floor(seconds / 60);
  const secs = seconds % 60;
  if (mins < 60) return `${mins}m ${secs}s`;
  const hrs = Math.floor(mins / 60);
  const remainMins = mins % 60;
  return `${hrs}h ${remainMins}m`;
}
