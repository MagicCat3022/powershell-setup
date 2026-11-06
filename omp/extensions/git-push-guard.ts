/**
 * Asks before a bash `git push` that force-pushes, deletes a remote branch, pushes every
 * branch, or targets dev/main/master. The rules live in Claude Code's PreToolUse hook,
 * ~/.claude/hooks/guard_git_push.py, which install-claude.ps1 installs; this extension
 * feeds it the same JSON Claude Code sends and turns its "ask" into a confirm dialog.
 * Without a UI (subagents, print mode) a flagged push is blocked.
 */
import type { ExtensionAPI } from "@oh-my-pi/pi-coding-agent";
import { spawn } from "node:child_process";
import * as fs from "node:fs";
import * as os from "node:os";
import * as path from "node:path";

const SCRIPT = path.join(os.homedir(), ".claude", "hooks", "guard_git_push.py");

async function runGuard(command: string, cwd: string): Promise<string | undefined> {
	const { promise, resolve, reject } = Promise.withResolvers<void>();
	const child = spawn("python", [SCRIPT], { stdio: ["pipe", "pipe", "inherit"], windowsHide: true });
	let stdout = "";
	child.stdout.on("data", chunk => {
		stdout += chunk;
	});
	child.on("error", reject);
	child.on("close", () => resolve());
	child.stdin.end(JSON.stringify({ tool_input: { command }, cwd }));
	await promise;
	if (!stdout.trim()) return undefined;
	const reason = JSON.parse(stdout)?.hookSpecificOutput?.permissionDecisionReason;
	return typeof reason === "string" ? reason : undefined;
}

export default function gitPushGuard(pi: ExtensionAPI): void {
	pi.on("session_start", (_event, ctx) => {
		if (!fs.existsSync(SCRIPT)) {
			ctx.ui.notify(`git-push-guard: ${SCRIPT} is missing; run install-claude.ps1. Pushes are not checked.`, "warning");
		}
	});

	pi.on("tool_call", async (event, ctx) => {
		if (event.toolName !== "bash") return;
		const command = event.input.command;
		if (typeof command !== "string" || !command.includes("push") || !fs.existsSync(SCRIPT)) return;
		const cwd = typeof event.input.cwd === "string" ? path.resolve(ctx.cwd, event.input.cwd) : ctx.cwd;
		const reason = await runGuard(command, cwd);
		if (!reason) return;
		if (!ctx.hasUI) return { block: true, reason: `${reason} Blocked: no UI to confirm.` };
		process.stdout.write("\x07");
		const ok = await ctx.ui.confirm("git push", `${reason}\n\n${command}`);
		if (!ok) return { block: true, reason: "The user declined the push." };
	});
}
