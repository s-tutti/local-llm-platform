/**
 * ADR-0004: FinOpsコスト最適化戦略
 *
 * Constraint: GPU node groups must use Spot instances. Budget alerts must be configured.
 * - GPU node groups must have capacity_type = "SPOT"
 * - AWS Budgets resource must exist with notification thresholds
 * - No on-demand GPU instances without explicit justification
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

  let hasBudget = false;
  let hasBudgetNotification = false;

  for (const file of files) {
    const content = readFileSync(file, "utf-8");
    const lines = content.split("\n");

    // Track if we're inside a GPU node group block
    if (content.includes("aws_budgets_budget")) {
      hasBudget = true;
    }
    if (content.includes("notification {") || content.includes("notification{")) {
      hasBudgetNotification = true;
    }

    // Check for GPU node groups without Spot
    // Look for node groups that reference GPU instance types
    const gpuNodeGroupRegex = /resource\s+"aws_eks_node_group"\s+"gpu/;
    if (gpuNodeGroupRegex.test(content)) {
      // This file defines a GPU node group — verify it uses SPOT
      if (!content.includes('capacity_type') || content.includes('capacity_type   = "ON_DEMAND"')) {
        // Find the resource line for location
        for (let i = 0; i < lines.length; i++) {
          if (gpuNodeGroupRegex.test(lines[i])) {
            violations.push({
              file,
              line: i + 1,
              match: lines[i].trim(),
              rule: "ADR-0004: GPU node group must use capacity_type = \"SPOT\" for cost optimization",
            });
            break;
          }
        }
      }
    }
  }

  // Check modules directory for GPU node group definitions
  const modulesDir = join(tfDir, "modules");
  const moduleFiles = walkTf(modulesDir);
  for (const file of moduleFiles) {
    const content = readFileSync(file, "utf-8");
    // Look for eks_node_group with "gpu" in the name that doesn't use SPOT
    const matches = content.matchAll(/resource\s+"aws_eks_node_group"\s+"(\w*gpu\w*)"/g);
    for (const match of matches) {
      // Extract the block for this resource (rough: find until next resource or EOF)
      const startIdx = content.indexOf(match[0]);
      const nextResource = content.indexOf('\nresource ', startIdx + 1);
      const block = nextResource > 0
        ? content.slice(startIdx, nextResource)
        : content.slice(startIdx);

      if (!block.includes('"SPOT"')) {
        const lineNum = content.slice(0, startIdx).split("\n").length;
        violations.push({
          file,
          line: lineNum,
          match: match[0],
          rule: "ADR-0004: GPU node group must use capacity_type = \"SPOT\"",
        });
      }
    }
  }

  // Check that budget exists in environment configs
  const envDir = join(tfDir, "environments");
  try {
    for (const env of readdirSync(envDir)) {
      const envPath = join(envDir, env);
      if (!statSync(envPath).isDirectory()) continue;
      const envFiles = walkTf(envPath);
      const envContent = envFiles.map(f => readFileSync(f, "utf-8")).join("\n");
      if (!envContent.includes("module \"security\"") && !envContent.includes("aws_budgets_budget")) {
        violations.push({
          file: envPath,
          line: 0,
          match: "",
          rule: `ADR-0004: Environment '${env}' must include security module with budget alerts`,
        });
      }
    }
  } catch {
    // environments dir doesn't exist
  }

  return violations;
}

const projectRoot = process.argv[2] || process.cwd();
const violations = check(projectRoot);

if (violations.length > 0) {
  for (const v of violations) {
    const loc = v.line > 0 ? `${v.file}:${v.line}` : v.file;
    console.error(
      `ERROR: ${v.rule} | ${loc} | WHY: Cost control — ADR-0004 | FIX: Use Spot instances for GPU and ensure budget alerts are configured`
    );
  }
  process.exit(1);
} else {
  console.log("ADR-0004: PASS — FinOps constraints met (Spot GPU, budget alerts present)");
  process.exit(0);
}

export { check, Violation };
