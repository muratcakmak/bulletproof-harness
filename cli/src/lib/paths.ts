/**
 * Path resolution for harness files.
 * Walks up from cwd to find harness root (directory containing CLAUDE.md + harness/).
 */

import { existsSync } from "fs";
import { join, resolve, dirname } from "path";

export interface HarnessPaths {
  root: string;
  claudeMd: string;
  memory: string;
  memoryIndex: string;
  tickets: string;
  queue: string;
  plan: string;
  completed: string;
  harness: string;
  bin: string;
  acceptance: string;
  skills: string;
  settings: string;
}

export function findHarnessRoot(from?: string): string | null {
  let dir = resolve(from || process.cwd());
  const root = dirname(dir);

  while (dir !== root) {
    if (
      existsSync(join(dir, "CLAUDE.md")) &&
      existsSync(join(dir, "harness"))
    ) {
      return dir;
    }
    dir = dirname(dir);
  }
  return null;
}

export function getPaths(rootOverride?: string): HarnessPaths {
  const root = rootOverride || findHarnessRoot() || process.cwd();
  return {
    root,
    claudeMd: join(root, "CLAUDE.md"),
    memory: join(root, "memory"),
    memoryIndex: join(root, "memory", "MEMORY.md"),
    tickets: join(root, "tickets"),
    queue: join(root, "tickets", "QUEUE.json"),
    plan: join(root, "tickets", "_plan.md"),
    completed: join(root, "tickets", "completed"),
    harness: join(root, "harness"),
    bin: join(root, "harness", "bin"),
    acceptance: join(root, "harness", "acceptance"),
    skills: join(root, "harness", "skills"),
    settings: join(root, ".claude", "settings.json"),
  };
}
