import { execSync } from "node:child_process";
import { dirname } from "node:path";

export default async function globalTeardown() {
  const SUT = process.env.SUT;
  execSync(`docker compose -f ../system_under_test/${SUT}/docker-compose.yaml down -v`, {
    stdio: "inherit",
    cwd: dirname("."),
  });
}
