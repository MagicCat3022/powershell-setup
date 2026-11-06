/**
 * Rings the terminal bell when a tool call waits for approval. omp notifies only for the ask
 * tool, turn completion, and errors. On Windows Terminal omp's notification is the same BEL, so
 * the terminal's bellStyle decides whether it plays a sound or flashes the taskbar.
 */
import type { ExtensionAPI } from "@oh-my-pi/pi-coding-agent";

export default function approvalBell(pi: ExtensionAPI): void {
	pi.on("tool_approval_requested", (_event, ctx) => {
		if (ctx.hasUI) process.stdout.write("\x07");
	});
}
