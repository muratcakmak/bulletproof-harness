/**
 * Display helpers — colored output, progress bars, tables.
 */

import chalk from "chalk";
import type { Queue, QueueTicket } from "./queue.js";
import { getProgress } from "./queue.js";

export const banner = `
${chalk.bold.cyan("┌─────────────────────────────────────────┐")}
${chalk.bold.cyan("│")}  ${chalk.bold.white("⚡ Bulletproof Harness")}                  ${chalk.bold.cyan("│")}
${chalk.bold.cyan("│")}  ${chalk.dim("Autonomous dev with Claude Code")}        ${chalk.bold.cyan("│")}
${chalk.bold.cyan("└─────────────────────────────────────────┘")}
`;

export function statusBadge(status: string): string {
  switch (status) {
    case "done":
      return chalk.green("✓ done");
    case "in_progress":
      return chalk.yellow("▶ in_progress");
    case "verifying":
      return chalk.magenta("? verifying");
    case "ready":
      return chalk.blue("● ready");
    case "backlog":
      return chalk.dim("○ backlog");
    default:
      return chalk.dim(status);
  }
}

export function printQueue(queue: Queue): void {
  const progress = getProgress(queue);
  const pct = progress.total > 0 ? Math.round((progress.done / progress.total) * 100) : 0;

  // Progress bar
  const barWidth = 30;
  const filled = Math.round((pct / 100) * barWidth);
  const bar = chalk.green("█".repeat(filled)) + chalk.dim("░".repeat(barWidth - filled));

  console.log("");
  console.log(`  ${bar} ${chalk.bold(`${pct}%`)} (${progress.done}/${progress.total})`);
  console.log("");

  // Ticket list
  for (const ticket of queue.queue) {
    const badge = statusBadge(ticket.status);
    const deps = ticket.depends_on?.length
      ? chalk.dim(` ← depends: ${ticket.depends_on.join(", ")}`)
      : "";
    console.log(`  ${badge}  ${chalk.white(ticket.id)}${deps}`);
  }

  console.log("");

  if (queue.current_ticket) {
    console.log(`  ${chalk.bold("Current:")} ${chalk.yellow(queue.current_ticket)}`);
  }

  // Summary line
  const parts: string[] = [];
  if (progress.inProgress > 0) parts.push(chalk.yellow(`${progress.inProgress} active`));
  if (progress.ready > 0) parts.push(chalk.blue(`${progress.ready} ready`));
  if (progress.backlog > 0) parts.push(chalk.dim(`${progress.backlog} backlog`));
  if (parts.length) {
    console.log(`  ${parts.join(" · ")}`);
  }
  console.log("");
}

export function printTicket(ticket: QueueTicket, content: string): void {
  console.log("");
  console.log(chalk.bold.cyan(`  ╔══ ${ticket.id} ══╗`));
  console.log(`  ${statusBadge(ticket.status)}  ${chalk.white(ticket.title)}`);
  console.log("");
  // Print first 20 lines of content
  const lines = content.split("\n").slice(0, 30);
  for (const line of lines) {
    console.log(`  ${chalk.dim("│")} ${line}`);
  }
  if (content.split("\n").length > 30) {
    console.log(`  ${chalk.dim("│")} ${chalk.dim("... (truncated)")}`);
  }
  console.log("");
}

export function success(msg: string): void {
  console.log(chalk.green(`  ✓ ${msg}`));
}

export function error(msg: string): void {
  console.error(chalk.red(`  ✗ ${msg}`));
}

export function warn(msg: string): void {
  console.log(chalk.yellow(`  ⚠ ${msg}`));
}

export function info(msg: string): void {
  console.log(chalk.blue(`  ℹ ${msg}`));
}

export function step(n: number, total: number, msg: string): void {
  console.log(chalk.dim(`  [${n}/${total}]`) + ` ${msg}`);
}
