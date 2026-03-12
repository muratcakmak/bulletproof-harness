/**
 * harness prompt [ticket-id] — Print the Claude Code prompt for a ticket.
 *
 * Generates a fully self-contained prompt that can be pasted into Claude Code.
 * Includes: ticket content, relevant memory, conventions, and instructions.
 */

import { Command } from "commander";
import { existsSync, readFileSync } from "fs";
import chalk from "chalk";
import { error, info } from "../lib/display.js";
import { getPaths, findHarnessRoot } from "../lib/paths.js";
import { readQueue } from "../lib/queue.js";

export const promptCommand = new Command("prompt")
  .description("Print Claude Code prompt for a ticket (copy-paste into Claude)")
  .argument("[ticket-id]", "Ticket ID (defaults to current)")
  .option("--skill <name>", "Include a skill in the prompt")
  .option("--clipboard", "Copy to clipboard (requires xclip or pbcopy)")
  .action(async (ticketId?: string, opts?: { skill?: string; clipboard?: boolean }) => {
    const root = findHarnessRoot();
    if (!root) {
      error("No harness found. Run 'harness init' first.");
      return;
    }
    const paths = getPaths(root);
    const queue = readQueue(paths.queue);

    // Resolve ticket ID
    const id = ticketId || queue.current_ticket;
    if (!id) {
      error("No ticket specified and no current ticket. Run 'harness next' first.");
      return;
    }

    // Find ticket file
    const ticketPath = `${paths.tickets}/${id}.md`;
    if (!existsSync(ticketPath)) {
      error(`Ticket file not found: ${ticketPath}`);
      return;
    }

    const ticketContent = readFileSync(ticketPath, "utf-8");

    // Load memory context
    const memoryContent = existsSync(paths.memoryIndex)
      ? readFileSync(paths.memoryIndex, "utf-8")
      : "";
    const conventionsPath = `${paths.memory}/conventions.md`;
    const conventions = existsSync(conventionsPath)
      ? readFileSync(conventionsPath, "utf-8")
      : "";

    // Load skill if specified
    let skillContent = "";
    if (opts?.skill) {
      const skillPath = `${paths.skills}/${opts.skill}/SKILL.md`;
      if (existsSync(skillPath)) {
        skillContent = readFileSync(skillPath, "utf-8");
      } else {
        error(`Skill not found: ${opts.skill}`);
      }
    }

    // Build the prompt
    const prompt = buildPrompt({
      ticketId: id,
      ticketContent,
      memoryContent,
      conventions,
      skillContent,
      root,
    });

    if (opts?.clipboard) {
      // Try to copy to clipboard
      try {
        const { execSync } = await import("child_process");
        if (process.platform === "darwin") {
          execSync("pbcopy", { input: prompt });
        } else {
          execSync("xclip -selection clipboard", { input: prompt });
        }
        info("Prompt copied to clipboard!");
      } catch {
        error("Could not copy to clipboard. Printing instead:");
        console.log(prompt);
      }
    } else {
      console.log(prompt);
    }
  });

function buildPrompt(ctx: {
  ticketId: string;
  ticketContent: string;
  memoryContent: string;
  conventions: string;
  skillContent: string;
  root: string;
}): string {
  const sections: string[] = [];

  sections.push(`# TASK: ${ctx.ticketId}

You are working on ticket ${ctx.ticketId} in an autonomous harness-driven workflow.
Complete ALL acceptance criteria below, then run: harness/bin/mark-done.sh ${ctx.ticketId}

---`);

  sections.push(`## TICKET\n\n${ctx.ticketContent}`);

  if (ctx.conventions) {
    sections.push(`## CONVENTIONS\n\n${ctx.conventions}`);
  }

  if (ctx.memoryContent) {
    sections.push(`## MEMORY CONTEXT\n\n${ctx.memoryContent}`);
  }

  if (ctx.skillContent) {
    sections.push(`## SKILL INSTRUCTIONS\n\n${ctx.skillContent}`);
  }

  sections.push(`## WORKFLOW RULES

1. Read the ticket above carefully
2. Search memory before writing code: harness/bin/search-memory.sh "pattern"
3. Follow conventions in memory/conventions.md
4. Test your work (type-check, lint, run tests)
5. Update memory with findings: harness/bin/update-memory.sh "category" "note"
6. When all AC are verified, run: harness/bin/mark-done.sh ${ctx.ticketId}
7. Commit: git add -A && git commit -m "ticket-${ctx.ticketId}: brief description"
8. If stuck after 3 retries: harness/bin/update-memory.sh bugs "description" and move on`);

  return sections.join("\n\n---\n\n");
}
