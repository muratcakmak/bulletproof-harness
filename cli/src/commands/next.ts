/**
 * harness next — Pick up next ready ticket.
 */

import { Command } from "commander";
import { existsSync, readFileSync } from "fs";
import { success, error, printTicket, printQueue } from "../lib/display.js";
import { banner } from "../lib/display.js";
import { getPaths, findHarnessRoot } from "../lib/paths.js";
import { runScript } from "../lib/shell.js";
import { readQueue } from "../lib/queue.js";

export const nextCommand = new Command("next")
  .description("Pick up next ready ticket")
  .action(async () => {
    const root = findHarnessRoot();
    if (!root) {
      error("No harness found. Run 'harness init' first.");
      return;
    }
    const paths = getPaths(root);

    const result = runScript(paths.bin, "next-ticket.sh", [], root);
    console.log(result.stdout);
    if (result.exitCode !== 0 && result.stderr) {
      console.error(result.stderr);
    }
  });
