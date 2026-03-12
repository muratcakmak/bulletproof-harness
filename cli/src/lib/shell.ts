/**
 * Shell execution helpers.
 * Runs harness scripts and Claude Code commands.
 */

import { execSync, spawn, type SpawnOptions } from "child_process";
import { existsSync } from "fs";

export interface ExecResult {
  stdout: string;
  stderr: string;
  exitCode: number;
}

/**
 * Run a shell command synchronously, capturing output.
 */
export function run(cmd: string, cwd?: string): ExecResult {
  try {
    const stdout = execSync(cmd, {
      cwd,
      encoding: "utf-8",
      timeout: 120_000,
      stdio: ["pipe", "pipe", "pipe"],
    });
    return { stdout, stderr: "", exitCode: 0 };
  } catch (err: any) {
    return {
      stdout: err.stdout ?? "",
      stderr: err.stderr ?? err.message,
      exitCode: err.status ?? 1,
    };
  }
}

/**
 * Run a harness script from harness/bin/.
 */
export function runScript(binDir: string, script: string, args: string[] = [], cwd?: string): ExecResult {
  const scriptPath = `${binDir}/${script}`;
  if (!existsSync(scriptPath)) {
    return { stdout: "", stderr: `Script not found: ${scriptPath}`, exitCode: 1 };
  }
  const cmd = `bash "${scriptPath}" ${args.map((a) => `"${a}"`).join(" ")}`;
  return run(cmd, cwd || binDir.replace(/\/harness\/bin$/, ""));
}

/**
 * Check if Claude Code CLI is available.
 */
export function hasClaudeCode(): boolean {
  const result = run("which claude 2>/dev/null || command -v claude 2>/dev/null");
  return result.exitCode === 0 && result.stdout.trim().length > 0;
}

/**
 * Run Claude Code with a prompt. Returns the output.
 * Uses --print for non-interactive mode.
 */
export function runClaudeCode(
  prompt: string,
  opts: {
    cwd?: string;
    print?: boolean;      // --print mode (non-interactive, returns output)
    model?: string;        // model override
    maxTurns?: number;     // limit turns
    allowedTools?: string[];
  } = {}
): ExecResult {
  const args: string[] = [];

  if (opts.print) {
    args.push("--print");
  }
  if (opts.model) {
    args.push("--model", opts.model);
  }
  if (opts.maxTurns) {
    args.push("--max-turns", String(opts.maxTurns));
  }
  if (opts.allowedTools?.length) {
    for (const tool of opts.allowedTools) {
      args.push("--allowedTools", tool);
    }
  }

  // Escape prompt for shell
  const escapedPrompt = prompt.replace(/'/g, "'\\''");
  const cmd = `claude ${args.join(" ")} -p '${escapedPrompt}'`;

  return run(cmd, opts.cwd);
}

/**
 * Spawn Claude Code interactively (for loop mode).
 * Returns a promise that resolves when the process exits.
 */
export function spawnClaudeCode(
  prompt: string,
  opts: {
    cwd?: string;
    maxTurns?: number;
    onStdout?: (data: string) => void;
    onStderr?: (data: string) => void;
  } = {}
): Promise<number> {
  return new Promise((resolve, reject) => {
    const args: string[] = ["--print", "-p", prompt];
    if (opts.maxTurns) {
      args.push("--max-turns", String(opts.maxTurns));
    }

    const spawnOpts: SpawnOptions = {
      cwd: opts.cwd,
      stdio: ["pipe", "pipe", "pipe"],
      shell: true,
    };

    const child = spawn("claude", args, spawnOpts);

    child.stdout?.on("data", (data: Buffer) => {
      const text = data.toString();
      opts.onStdout?.(text);
    });

    child.stderr?.on("data", (data: Buffer) => {
      const text = data.toString();
      opts.onStderr?.(text);
    });

    child.on("close", (code) => resolve(code ?? 0));
    child.on("error", (err) => reject(err));
  });
}
