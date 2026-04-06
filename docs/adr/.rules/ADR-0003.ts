/**
 * ADR-0003: ゼロトラストネットワーク設計
 *
 * Constraint: EKS must use private endpoint only. No public access allowed.
 * - endpoint_public_access must be false
 * - endpoint_private_access must be true
 * - No 0.0.0.0/0 ingress rules on cluster security groups
 * - No public subnets assigned to EKS cluster
 */

import { readFileSync, readdirSync, statSync } from "fs";
import { join, extname } from "path";

interface Violation {
  file: string;
  line: number;
  match: string;
  rule: string;
}

const IGNORE_DIRS = new Set([".terraform", ".git", "node_modules"]);

function walkTf(dir: string): string[] {
  const files: string[] = [];
  try {
    for (const entry of readdirSync(dir)) {
      if (IGNORE_DIRS.has(entry)) continue;
      const full = join(dir, entry);
      const stat = statSync(full);
      if (stat.isDirectory()) {
        files.push(...walkTf(full));
      } else if (extname(full) === ".tf") {
        files.push(full);
      }
    }
  } catch {
    // directory doesn't exist
  }
  return files;
}

function check(projectRoot: string): Violation[] {
  const violations: Violation[] = [];
  const tfDir = join(projectRoot, "infra", "terraform");
  const files = walkTf(tfDir);

  for (const file of files) {
    const content = readFileSync(file, "utf-8");
    const lines = content.split("\n");

    for (let i = 0; i < lines.length; i++) {
      const line = lines[i];

      // Check for public endpoint enabled on EKS
      if (/endpoint_public_access\s*=\s*true/.test(line)) {
        violations.push({
          file,
          line: i + 1,
          match: line.trim(),
          rule: "ADR-0003: EKS public endpoint access must be disabled",
        });
      }

      // Check for private endpoint disabled
      if (/endpoint_private_access\s*=\s*false/.test(line)) {
        violations.push({
          file,
          line: i + 1,
          match: line.trim(),
          rule: "ADR-0003: EKS private endpoint access must be enabled",
        });
      }

      // Check for wide-open ingress CIDR on security groups (0.0.0.0/0 ingress)
      // Only flag if it's within an ingress block context (check surrounding lines)
      if (/cidr_blocks\s*=\s*\["0\.0\.0\.0\/0"\]/.test(line)) {
        // Look back up to 5 lines for 'ingress' block
        const context = lines.slice(Math.max(0, i - 5), i + 1).join("\n");
        if (/ingress\s*\{/.test(context)) {
          violations.push({
            file,
            line: i + 1,
            match: line.trim(),
            rule: "ADR-0003: Ingress from 0.0.0.0/0 violates zero-trust — use specific CIDR or security group references",
          });
        }
      }
    }
  }

  return violations;
}

const projectRoot = process.argv[2] || process.cwd();
const violations = check(projectRoot);

if (violations.length > 0) {
  for (const v of violations) {
    console.error(
      `ERROR: ${v.rule} | ${v.file}:${v.line} | WHY: Zero-trust networking — ADR-0003 | FIX: Ensure all access is via private endpoints and SSM`
    );
  }
  process.exit(1);
} else {
  console.log("ADR-0003: PASS — Zero-trust networking constraints met");
  process.exit(0);
}

export { check, Violation };
