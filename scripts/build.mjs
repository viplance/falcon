import { mkdir, rm, cp, writeFile, access, readFile } from "node:fs/promises";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { spawn, execSync } from "node:child_process";

const __dirname = dirname(fileURLToPath(import.meta.url));
const root = resolve(__dirname, "..");
const appName = "FalconShot";
const buildDir = join(root, "build");
const appBundle = join(buildDir, `${appName}.app`);

const { version } = JSON.parse(await readFile(join(root, "package.json"), "utf8"));
const BUNDLE_ID = "enotix.FalconShot";

function run(command, args, options = {}) {
  return new Promise((res, rej) => {
    const child = spawn(command, args, { cwd: root, stdio: "inherit", ...options });
    child.on("exit", (code) => (code === 0 ? res() : rej(new Error(`${command} ${args.join(" ")} exited ${code}`))));
    child.on("error", rej);
  });
}

const LSREG = "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister";

console.log("Stopping any running instance...");
try { execSync(`pkill -x ${appName}`, { stdio: "pipe" }); } catch { /* not running */ }

console.log("Sweeping stale LaunchServices registrations...");
try {
  const dump = execSync(`${LSREG} -dump`, { stdio: ["pipe", "pipe", "pipe"], maxBuffer: 256 * 1024 * 1024 }).toString();
  const blocks = dump.split(/\n(?=path:\s)/);
  const stalePaths = new Set();
  for (const block of blocks) {
    if (!block.includes(`identifier:                 ${BUNDLE_ID}`)) continue;
    const m = block.match(/^path:\s+(.+?)(?:\s+\(0x[0-9a-f]+\))?$/m);
    if (!m) continue;
    const p = m[1].trim();
    if (p === appBundle) continue;
    stalePaths.add(p);
  }
  for (const p of stalePaths) {
    try {
      execSync(`${LSREG} -u "${p}"`, { stdio: "pipe" });
      console.log(`  unregistered: ${p}`);
    } catch { /* already gone */ }
  }
  if (stalePaths.size === 0) console.log("  (none found)");
} catch (e) {
  console.warn(`  Warning: LaunchServices sweep failed: ${e.message}`);
}

console.log("Cleaning build dir...");
await rm(buildDir, { recursive: true, force: true });
await mkdir(buildDir, { recursive: true });

console.log(`Building with xcodebuild (version ${version})...`);
await run("xcodebuild", [
  "-project", `${appName}.xcodeproj`,
  "-scheme", appName,
  "-configuration", "Release",
  "-derivedDataPath", join(buildDir, "DerivedData"),
  "CONFIGURATION_BUILD_DIR=" + buildDir,
  `MARKETING_VERSION=${version}`,
  "build",
]);

console.log("Done. App bundle:", appBundle);
