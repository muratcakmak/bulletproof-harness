/**
 * QUEUE.json reader/writer.
 * Single source of truth for ticket state machine.
 */

import { readFileSync, writeFileSync } from "fs";

export interface QueueTicket {
  id: string;
  title: string;
  status: "backlog" | "ready" | "in_progress" | "verifying" | "done";
  depends_on?: string[];
  assigned_at?: string;
  completed_at?: string;
  archived?: boolean;
}

export interface Queue {
  current_ticket: string | null;
  queue: QueueTicket[];
}

export function readQueue(queuePath: string): Queue {
  const raw = readFileSync(queuePath, "utf-8");
  return JSON.parse(raw) as Queue;
}

export function writeQueue(queuePath: string, queue: Queue): void {
  writeFileSync(queuePath, JSON.stringify(queue, null, 2) + "\n");
}

export function getTicket(queue: Queue, id: string): QueueTicket | undefined {
  return queue.queue.find((t) => t.id === id);
}

export function getNextReady(queue: Queue): QueueTicket | undefined {
  return queue.queue.find((t) => t.status === "ready");
}

export function getDoneIds(queue: Queue): Set<string> {
  return new Set(queue.queue.filter((t) => t.status === "done").map((t) => t.id));
}

/**
 * Extracts the numeric prefix from a ticket ID (e.g., "0001-setup" → 1)
 */
function ticketNum(id: string): number {
  const match = id.match(/^(\d+)/);
  return match ? parseInt(match[1], 10) : -1;
}

/**
 * Promote backlog tickets whose dependencies are all done.
 * Dependencies can be stored as "1", "0001", or "0001-full-name".
 */
export function promoteDependencies(queue: Queue): number {
  const doneNums = new Set(
    queue.queue
      .filter((t) => t.status === "done")
      .map((t) => ticketNum(t.id))
  );

  let promoted = 0;
  for (const ticket of queue.queue) {
    if (ticket.status !== "backlog") continue;

    const deps = ticket.depends_on ?? [];
    if (deps.length === 0) {
      ticket.status = "ready";
      promoted++;
      continue;
    }

    const allMet = deps.every((dep) => {
      const depNum = parseInt(dep.replace(/^0+/, "") || "0", 10);
      return doneNums.has(depNum);
    });

    if (allMet) {
      ticket.status = "ready";
      promoted++;
    }
  }

  return promoted;
}

export function getProgress(queue: Queue): {
  done: number;
  inProgress: number;
  ready: number;
  backlog: number;
  total: number;
} {
  const counts = { done: 0, inProgress: 0, ready: 0, backlog: 0, total: queue.queue.length };
  for (const t of queue.queue) {
    if (t.status === "done") counts.done++;
    else if (t.status === "in_progress" || t.status === "verifying") counts.inProgress++;
    else if (t.status === "ready") counts.ready++;
    else counts.backlog++;
  }
  return counts;
}
