import { fileURLToPath } from "node:url";
import { readdir } from "node:fs/promises";
import { execFileSync } from "node:child_process";
for (const file of await readdir(new URL("../public/", import.meta.url))) {
  if (file.endsWith(".js"))
    execFileSync(
      process.execPath,
      ["--check", fileURLToPath(new URL("../public/" + file, import.meta.url))],
      { stdio: "inherit" },
    );
}
console.log("All application modules passed syntax checks.");
