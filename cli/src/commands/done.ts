/**
 * harness done [ticket-id] — Mark ticket done after AC verification.
 */

import { Command } from "commander";
import { error } from "../lib/display.js";
import { getPaths, findHarnessRoot } from "../lib/paths.js";
import { runScript } from "../lib/shell.js";

export const doneCommand = new Command("done")
  .description("Verify acceptance criteria and mark ticket done")
  .argument("[ticket-id]", "Ticket ID (defaults to current)")
  .action(async (ticketId?: string) => {
    const root = findHarnessRoot();
    if (!root) {
      error("No harness found. Run 'harness init' first.");
      return;
    }
    const paths = getPaths(root);
    const args = ticketId ? [ticketId] : [];

    const result = runScript(paths.bin, "mark-done.sh", args, root);
    console.log(result.stdout);
    if (result.exitCode !== 0) {
      console.error(result.stderr);
    }
  });
