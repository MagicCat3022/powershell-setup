/**
 * One colored status line under the status bar: path · context · remaining quota.
 *
 * - path: inside a git repo the path starts at the repo root; elsewhere home is `~`.
 *   At most the last 3 folders are kept (`…/a/b/c`).
 * - context: used tokens, and where auto-compaction fires for the active model
 *   (`ctx 276k/1M · compacts at 375k (99k left)`), colored by progress toward that point.
 * - quota: REMAINING subscription quota for the active model's provider
 *   (`left 5h 88% (2h 24m) · 7d 95% (6d 8h)`), colored by what is left.
 *
 * omp strips colors from statuses inside the bar's `status` segment and keeps them only on the
 * hook-status lines below the bar, so this needs `statusLine.showHookStatus: true` and no
 * `status` in `statusLine.leftSegments`/`rightSegments`.
 */
import type { ExtensionAPI, ExtensionContext } from "@oh-my-pi/pi-coding-agent";
import * as fs from "node:fs";
import * as os from "node:os";
import * as path from "node:path";

const MAX_DEPTH = 3;
const QUOTA_REFRESH_MS = 5 * 60_000;
const CONTEXT_REFRESH_MS = 1_500;
const FOLDER_ICON = "\uf07b";
const CLOCK_ICON = "\uf017";
const CONTEXT_ICON = "\uf1c0";
const CONFIG_PATH = path.join(os.homedir(), ".omp", "agent", "config.yml");

type Color = "success" | "warning" | "error" | "muted" | "dim" | "text" | "statusLinePath";
type Paint = (color: Color, text: string) => string;

// ── path ────────────────────────────────────────────────────────────────────

function findRepoRoot(dir: string): string | undefined {
	let current = dir;
	for (;;) {
		if (fs.existsSync(path.join(current, ".git"))) return current;
		const parent = path.dirname(current);
		if (parent === current) return undefined;
		current = parent;
	}
}

function components(relative: string): string[] {
	return relative.split(/[\\/]+/).filter(Boolean);
}

function cap(prefix: string, parts: string[]): string {
	if (parts.length > MAX_DEPTH) return `…/${parts.slice(-MAX_DEPTH).join("/")}`;
	return prefix + parts.join("/");
}

export function shortPath(cwd: string, home: string = os.homedir()): string {
	const abs = path.resolve(cwd);
	const repoRoot = findRepoRoot(abs);
	if (repoRoot) {
		return cap("", [path.basename(repoRoot), ...components(path.relative(repoRoot, abs))]);
	}
	const fromHome = path.relative(home, abs);
	if (!fromHome.startsWith("..") && !path.isAbsolute(fromHome)) {
		const parts = components(fromHome);
		return parts.length === 0 ? "~" : cap("~/", parts);
	}
	const root = path.parse(abs).root;
	return cap(root.replaceAll("\\", "/"), components(abs.slice(root.length)));
}

// ── quota ───────────────────────────────────────────────────────────────────

interface QuotaLimit {
	scope?: { windowId?: string; modelId?: string; tier?: string };
	amount?: { usedFraction?: number; remainingFraction?: number };
	window?: { durationMs?: number; resetsAt?: number };
}
interface QuotaReport {
	provider?: string;
	limits?: QuotaLimit[];
}

const HOUR_MS = 3_600_000;
const DAY_MS = 24 * HOUR_MS;
/** Display order and matching rules mirror the built-in `usage` segment. */
const WINDOWS = [
	{ label: "5h", ids: ["5h"], durationMs: 5 * HOUR_MS, resetUnit: "m" },
	{ label: "1d", ids: ["daily", "24h", "1d"], durationMs: DAY_MS, resetUnit: "m" },
	{ label: "7d", ids: ["7d"], durationMs: 7 * DAY_MS, resetUnit: "h" },
] as const;

function formatReset(resetsAt: number, unit: "m" | "h", now: number): string {
	if (unit === "m") {
		const minutes = Math.max(0, Math.round((resetsAt - now) / 60_000));
		if (minutes < 60) return `${minutes}m`;
		const mins = minutes % 60;
		return mins > 0 ? `${Math.floor(minutes / 60)}h ${mins}m` : `${Math.floor(minutes / 60)}h`;
	}
	const hours = Math.max(0, Math.round((resetsAt - now) / HOUR_MS));
	if (hours < 24) return `${hours}h`;
	const rest = hours % 24;
	return rest > 0 ? `${Math.floor(hours / 24)}d ${rest}h` : `${Math.floor(hours / 24)}d`;
}

export function formatQuota(
	reports: unknown,
	provider: string,
	modelId: string | undefined,
	paint: Paint,
	now = Date.now(),
): string {
	if (!Array.isArray(reports)) return "";
	const activeModel = modelId?.trim().toLowerCase();
	// Per window: [priority, limit]. Exact-model limits outrank provider-wide ones; untiered outrank tiered.
	const best = new Map<string, [number, QuotaLimit]>();
	const report = (reports as QuotaReport[]).find(r => r?.provider === provider && Array.isArray(r.limits));
	for (const limit of report?.limits ?? []) {
		const scopedModel = limit.scope?.modelId?.trim().toLowerCase();
		if (scopedModel && scopedModel !== activeModel) continue;
		const windowId = limit.scope?.windowId;
		const duration = limit.window?.durationMs;
		const match = WINDOWS.find(
			w =>
				(windowId !== undefined && (w.ids as readonly string[]).includes(windowId)) ||
				(duration !== undefined && Math.abs(duration - w.durationMs) <= 60_000),
		);
		if (!match) continue;
		const priority = (scopedModel ? 0 : 2) + (limit.scope?.tier?.trim() ? 1 : 0);
		const current = best.get(match.label);
		if (!current || priority < current[0]) best.set(match.label, [priority, limit]);
	}
	const parts: string[] = [];
	for (const w of WINDOWS) {
		const limit = best.get(w.label)?.[1];
		const amount = limit?.amount;
		const used = amount?.usedFraction ?? (amount?.remainingFraction !== undefined ? 1 - amount.remainingFraction : undefined);
		if (used === undefined) continue;
		const left = Math.max(0, Math.min(100, Math.round((1 - used) * 100)));
		const color: Color = left <= 20 ? "error" : left <= 50 ? "warning" : "success";
		const resetsAt = limit?.window?.resetsAt;
		const reset = resetsAt !== undefined ? paint("muted", ` (${formatReset(resetsAt, w.resetUnit, now)})`) : "";
		parts.push(`${paint("text", w.label)} ${paint(color, `${left}%`)}${reset}`);
	}
	if (parts.length === 0) return "";
	return `${paint("muted", `${CLOCK_ICON} left`)} ${parts.join(paint("dim", " · "))}`;
}

// ── context and auto-compaction ─────────────────────────────────────────────

// Mirrors omp's compaction trigger (`resolveThresholdTokens` in pi-agent-core and the
// `compaction.modelThresholds` matching in coding-agent), read from the global config.yml.
const DEFAULT_RESERVE_TOKENS = 16_384;

interface CompactionConfig {
	enabled?: boolean;
	strategy?: string;
	thresholdPercent?: number;
	thresholdTokens?: number;
	reserveTokens?: number | null;
	modelThresholdsEnabled?: boolean;
	modelThresholds?: Record<string, unknown>;
}

let configCache: { mtimeMs: number; compaction: CompactionConfig } | undefined;

function readCompactionConfig(): CompactionConfig {
	try {
		const { mtimeMs } = fs.statSync(CONFIG_PATH);
		if (configCache?.mtimeMs !== mtimeMs) {
			// omp validates config.yml before this extension runs, so the compaction block has omp's shape.
			const parsed: unknown = Bun.YAML.parse(fs.readFileSync(CONFIG_PATH, "utf8"));
			const compaction =
				parsed && typeof parsed === "object" && "compaction" in parsed && parsed.compaction && typeof parsed.compaction === "object"
					? (parsed.compaction as CompactionConfig)
					: {};
			configCache = { mtimeMs, compaction };
		}
		return configCache.compaction;
	} catch {
		return {};
	}
}

function matchModelEntry(thresholds: Record<string, unknown> | undefined, selector: string): unknown {
	if (!thresholds) return undefined;
	if (Object.hasOwn(thresholds, selector)) return thresholds[selector];
	let bestKey: string | undefined;
	for (const key of Object.keys(thresholds)) {
		if (!key.endsWith("*") || !selector.startsWith(key.slice(0, -1))) continue;
		if (!bestKey || key.length > bestKey.length) bestKey = key;
	}
	return bestKey === undefined ? undefined : thresholds[bestKey];
}

function promptBudgetTokens(window: number, reserveTokens: number | undefined): number {
	const proportional = Math.max(1, Math.floor(window * 0.15));
	const effective = Math.max(Math.floor(window * 0.15), reserveTokens ?? DEFAULT_RESERVE_TOKENS);
	const impossibleDefault = reserveTokens === undefined && effective >= window - proportional;
	const reserve = impossibleDefault || effective >= window ? proportional : effective;
	return Math.max(0, Math.min(window - 1, window - reserve));
}

/** Token count at which auto-compaction fires for `selector` on `window`, or undefined when it is off. */
export function compactionTriggerTokens(config: CompactionConfig, selector: string, window: number): number | undefined {
	if (config.enabled === false || config.strategy === "off" || !(window > 0)) return undefined;
	let thresholdPercent = config.thresholdPercent ?? -1;
	let thresholdTokens = config.thresholdTokens ?? -1;
	let baseWindow: number | undefined;
	const reserveTokens = config.reserveTokens ?? undefined;
	const entry = config.modelThresholdsEnabled === false ? undefined : matchModelEntry(config.modelThresholds, selector);
	if (typeof entry === "number" && Number.isSafeInteger(entry) && entry > 0) {
		thresholdTokens = -1;
		baseWindow = entry;
	} else if (typeof entry === "string") {
		const text = entry.trim();
		const fixed = /^f(\d+)$/i.exec(text);
		const percent = /^(\d+(?:\.\d+)?)%$/.exec(text);
		if (fixed) {
			thresholdPercent = -1;
			thresholdTokens = Number(fixed[1]);
		} else if (percent && Number(percent[1]) > 0 && Number(percent[1]) <= 100) {
			thresholdPercent = Number(percent[1]);
			thresholdTokens = -1;
		}
	}
	if (thresholdTokens > 0) {
		if (thresholdTokens >= window) return promptBudgetTokens(window, reserveTokens);
		return Math.min(window - 1, Math.max(1, thresholdTokens));
	}
	const scaled = baseWindow !== undefined && baseWindow > 0 ? Math.min(window, baseWindow) : window;
	if (!(thresholdPercent > 0)) return promptBudgetTokens(scaled, reserveTokens);
	return Math.floor(scaled * (Math.min(99, Math.max(1, thresholdPercent)) / 100));
}

function formatTokens(tokens: number): string {
	if (tokens >= 999_500) return `${Number((tokens / 1_000_000).toFixed(2))}M`;
	if (tokens >= 1_000) return `${Math.round(tokens / 1_000)}k`;
	return `${tokens}`;
}

function formatContext(ctx: ExtensionContext, paint: Paint): string {
	const usage = ctx.getContextUsage();
	if (!usage || !(usage.contextWindow > 0)) return "";
	const { tokens, contextWindow } = usage;
	const used = `${CONTEXT_ICON} ${formatTokens(tokens)}/${formatTokens(contextWindow)}`;
	const selector = ctx.model ? `${ctx.model.provider}/${ctx.model.id}` : "";
	const trigger = compactionTriggerTokens(readCompactionConfig(), selector, contextWindow);
	if (trigger === undefined) {
		const share = tokens / contextWindow;
		const color: Color = share >= 0.9 ? "error" : share >= 0.7 ? "warning" : "text";
		return `${paint(color, used)} ${paint("muted", "(auto-compact off)")}`;
	}
	const progress = tokens / trigger;
	const color: Color = progress >= 0.9 ? "error" : progress >= 0.7 ? "warning" : "success";
	const left = Math.max(0, trigger - tokens);
	return `${paint(color, used)} ${paint("muted", `· compacts at ${formatTokens(trigger)}`)} ${paint(color, `(${formatTokens(left)} left)`)}`;
}

// ── wiring ──────────────────────────────────────────────────────────────────

export default function (pi: ExtensionAPI) {
	pi.setLabel("Status line: path, context, remaining quota");
	let quota = "";

	const publish = (ctx: ExtensionContext) => {
		const paint: Paint = (color, text) => ctx.ui.theme.fg(color, text);
		const parts = [
			paint("statusLinePath", `${FOLDER_ICON} ${shortPath(ctx.cwd)}`),
			formatContext(ctx, paint),
			quota,
		].filter(Boolean);
		ctx.ui.setStatus("statusline", parts.join(paint("dim", "  │  ")));
	};

	const refreshQuota = async (ctx: ExtensionContext) => {
		const model = ctx.model;
		const usage = ctx.modelRegistry.authStorage.usage;
		if (!model || !usage.reports) {
			quota = "";
		} else {
			try {
				const reports = await usage.reports({
					baseUrlResolver: (provider: string) => ctx.modelRegistry.getProviderBaseUrl(provider),
				});
				quota = formatQuota(reports, model.provider, model.id, (color, text) => ctx.ui.theme.fg(color, text));
			} catch {
				// Keep the last value; the next refresh retries.
			}
		}
		publish(ctx);
	};

	const refresh = (_event: unknown, ctx: ExtensionContext) => {
		publish(ctx);
		void refreshQuota(ctx);
	};
	pi.on("session_start", (event, ctx) => {
		refresh(event, ctx);
		ctx.setInterval(() => void refreshQuota(ctx), QUOTA_REFRESH_MS);
		// Context grows inside a turn; setStatus ignores an unchanged value, so polling is cheap.
		ctx.setInterval(() => publish(ctx), CONTEXT_REFRESH_MS);
	});
	pi.on("session_switch", refresh);
	// Turn ends pick up /move, model switches, and fresh quota.
	pi.on("turn_end", refresh);
	pi.on("session_compact", (_event, ctx) => publish(ctx));
}
