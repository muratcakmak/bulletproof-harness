/**
 * harness init [name] — Initialize harness in current directory.
 * Delegates to harness/bin/init-harness.sh
 */

import { Command } from "commander";
import chalk from "chalk";
import { banner, success, error } from "../lib/display.js";
import { runScript } from "../lib/shell.js";
import { getPaths } from "../lib/paths.js";
import { existsSync } from "fs";
import { basename } from "path";

export const initCommand = new Command("init")
  .description("Initialize harness in current directory")
  .argument("[name]", "Project name", basename(process.cwd()))
  .option("--force", "Overwrite existing harness files")
  .action(async (name: string, opts: { force?: boolean }) => {
    console.log(banner);

    const cwd = process.cwd();
    const paths = getPaths(cwd);

    if (existsSync(paths.claudeMd) && !opts.force) {
      console.log(chalk.yellow("  Harness already initialized in this directory."));
      console.log(chalk.dim("  Use --force to reinitialize."));
      return;
    }

    console.log(chalk.dim(`  Initializing harness for: ${chalk.white(name)}`));
    console.log(chalk.dim(`  Directory: ${cwd}`));
    console.log("");

    const result = runScript(paths.bin, "init-harness.sh", [name], cwd);

    if (result.exitCode === 0) {
      success("Harness initialized!");
      console.log("");
      console.log(chalk.dim("  Next steps:"));
      console.log(`    1. Edit ${chalk.cyan("CLAUDE.md")} with your project details`);
      console.log(`    2. Edit ${chalk.cyan("memory/conventions.md")} with your code style`);
      console.log(`    3. Write your build plan in ${chalk.cyan("tickets/_plan.md")}`);
      console.log(`    4. Run: ${chalk.green("harness plan")} to generate tickets`);
      console.log(`    5. Run: ${chalk.green("harness next")} to start working`);
    } else {
      error("Initialization failed:");
      console.error(result.stderr);
    }
  });
