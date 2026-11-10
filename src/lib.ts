import { environment } from "@raycast/api";
import { runAppleScript } from "@raycast/utils";
import { execFile } from "node:child_process";
import { existsSync } from "node:fs";
import { join } from "node:path";
import { promisify } from "node:util";

const execFileAsync = promisify(execFile);

const SCRIPT = join(environment.assetsPath, "shutdown-timer.sh");
const PLIST = "/Library/LaunchDaemons/local.shutdown-timer.plist";

// The script prints several lines; only the first one (the result) is shown.
function firstLine(output: string): string {
  return output.trim().split("\n")[0] ?? "";
}

export function hasTimer(): boolean {
  return existsSync(PLIST);
}

/** Subcommands that do not need root (status). */
export async function runScript(arg: string): Promise<string> {
  const { stdout } = await execFileAsync("/bin/bash", [SCRIPT, arg]);
  return firstLine(stdout);
}

/** Subcommands that need root (start, cancel). Opens the macOS administrator password dialog. */
export async function runScriptAsRoot(arg: string): Promise<string> {
  const output = await runAppleScript(
    `
on run argv
  do shell script "/bin/bash " & quoted form of (item 1 of argv) & " " & quoted form of (item 2 of argv) with administrator privileges
end run
`,
    [SCRIPT, arg],
    { timeout: 120_000 },
  );
  return firstLine(output);
}

/** True when the user pressed "Cancel" in the password dialog. */
export function isUserCancel(error: unknown): boolean {
  const message = error instanceof Error ? error.message : String(error);
  return message.includes("-128") || /user cancell?ed/i.test(message);
}

export function errorMessage(error: unknown): string {
  const message = error instanceof Error ? error.message : String(error);
  const match = message.match(/Error: (.*)/);
  return match ? match[1] : message;
}
