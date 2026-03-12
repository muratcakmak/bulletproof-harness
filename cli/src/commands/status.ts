/**
 * harness status — Show queue status + progress.
 */

import { Command } from "commander";
import { existsSync, readFileSync } from "fs";
import chalk from "chalk";
import { banner, printQueue, error, info } from "../lib/display.js";
import { getPaths, findHarnessRoot } from "../lib/paths.js";
import { readQueue, getProgress } from "../lib/queue.js";

export const statusCommand = new Command("status")
  .description("Show queue status, progress, and memory summary")
  .option("--json", "Output as JSON")
  .option("--memory", "Include memory summary")
  .action(async (opts: { json?: boolean; memory?: boolean }) => {
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

    const queue = readQueue(paths.queue);
    const progress = getProgress(queue);

    if (opts.json) {
      console.log(JSON.stringify({ progress, queue }, null, 2));
      return;
    }

    console.log(banner);
    printQueue(queue);

    // Show memory summary if requested
    if (opts.memory && existsSync(paths.memoryIndex)) {
      console.log(chalk.bold.cyan("  Memory Index:"));
      const content = readFileSync(paths.memoryIndex, "utf-8");
      const lines = content.split("\n").slice(0, 15);
      for (const line of lines) {
        console.log(chalk.dim(`  ${line}`));
      }
      console.log("");
    }

    // Show recent progress
    const progressFile = `${paths.memory}/progress.md`;
    if (existsSync(progressFile)) {
      const content = readFileSync(progressFile, "utf-8");
      const completedLines = content
        .split("\n")
        .filter((l) => l.startsWith("- [x]") || l.startsWith("- ["))
        .slice(-5);

      if (completedLines.length > 0) {
        console.log(chalk.bold("  Recent Activity:"));
        for (const line of completedLines) {
          console.log(chalk.dim(`  ${line}`));
        }
        console.log("");
      }
    }
  });
