/**
 * harness memory <subcommand>
 *
 * Subcommands:
 *   harness memory search <query>    — Search across all memory files
 *   harness memory update <cat> <note> — Add a note to memory
 *   harness memory show               — Print current memory index
 */

import { Command } from "commander";
import { existsSync, readFileSync } from "fs";
import chalk from "chalk";
import { error, info } from "../lib/display.js";
import { getPaths, findHarnessRoot } from "../lib/paths.js";
import { runScript } from "../lib/shell.js";

export const memoryCommand = new Command("memory")
  .description("Search, update, or view memory")
  .addCommand(
    new Command("search")
      .description("Search memory files for a pattern")
      .argument("<query>", "Search pattern")
      .action(async (query: string) => {
        const root = findHarnessRoot();
        if (!root) { error("No harness found."); return; }
        const paths = getPaths(root);
        const result = runScript(paths.bin, "search-memory.sh", [query], root);
        console.log(result.stdout);
      })
  )
  .addCommand(
    new Command("update")
      .description("Add a note to memory (categories: decision, bug, convention, log, architecture)")
      .argument("<category>", "Memory category")
      .argument("<note>", "Note to add")
      .action(async (category: string, note: string) => {
        const root = findHarnessRoot();
        if (!root) { error("No harness found."); return; }
        const paths = getPaths(root);
        const result = runScript(paths.bin, "update-memory.sh", [category, note], root);
        console.log(result.stdout);
      })
  )
  .addCommand(
    new Command("show")
      .description("Print current memory index")
      .action(async () => {
        const root = findHarnessRoot();
        if (!root) { error("No harness found."); return; }
        const paths = getPaths(root);
        if (!existsSync(paths.memoryIndex)) {
          error("No MEMORY.md found.");
          return;
        }
        console.log(readFileSync(paths.memoryIndex, "utf-8"));
      })
  );
