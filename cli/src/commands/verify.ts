/**
 * harness verify [ticket-id] — Run acceptance verification for a ticket.
 */

import { Command } from "commander";
import { error } from "../lib/display.js";
import { getPaths, findHarnessRoot } from "../lib/paths.js";
import { runScript } from "../lib/shell.js";
import { readQueue } from "../lib/queue.js";

export const verifyCommand = new Command("verify")
  .description("Run acceptance verification for a ticket")
  .argument("[ticket-id]", "Ticket ID (defaults to current)")
  .action(async (ticketId?: string) => {
    const root = findHarnessRoot();
    if (!root) {
      error("No harness found. Run 'harness init' first.");
      return;
    }
    const paths = getPaths(root);

    const id = ticketId || readQueue(paths.queue).current_ticket;
    if (!id) {
      error("No ticket specified and no current ticket.");
      return;
    }

    const result = runScript(paths.acceptance, "verify-all.sh", [id], root);
    console.log(result.stdout);
    if (result.exitCode !== 0) {
      console.error(result.stderr);
      process.exit(result.exitCode);
    }
  });
