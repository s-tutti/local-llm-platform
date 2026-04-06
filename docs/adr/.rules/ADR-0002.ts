/**
 * ADR-0002: ハイブリッドデプロイメント戦略
 *
 * Constraint: K8s manifests must use Kustomize overlay pattern.
 * - Base manifests in k8s/base/ must NOT contain environment-specific values
 * - Environment differences must be handled via overlays (local, production)
 * - No hardcoded node selectors, GPU resources, or replica counts in base
 */

import { readFileSync, readdirSync, statSync } from "fs";
import { join, extname } from "path";

interface Violation {
  file: string;
  line: number;
  match: string;
  rule: string;
}

const ENV_SPECIFIC_PATTERNS = [
  { pattern: /nvidia\.com\/gpu/, desc: "GPU resource request (should be in production overlay)" },
  { pattern: /replicas:\s*[3-9]\d*/, desc: "High replica count (should be in production overlay)" },
  { pattern: /capacity_type\s*=\s*"SPOT"/i, desc: "Spot instance reference (Terraform, not K8s base)" },
  { pattern: /nodeSelector:/, desc: "nodeSelector (should be in overlay patch)" },
];

function check(projectRoot: string): Violation[] {
  const violations: Violation[] = [];
  const baseDir = join(projectRoot, "k8s", "base");

  let files: string[];
  try {
    files = walkYaml(baseDir);
  } catch {
    // k8s/base doesn't exist yet — nothing to check
    return [];
  }

  for (const file of files) {
    // Skip kustomization.yaml itself
    if (file.endsWith("kustomization.yaml")) continue;

    const content = readFileSync(file, "utf-8");
    const lines = content.split("\n");

    for (let i = 0; i < lines.length; i++) {
      for (const { pattern, desc } of ENV_SPECIFIC_PATTERNS) {
        if (pattern.test(lines[i])) {
          violations.push({
            file,
            line: i + 1,
            match: lines[i].trim(),
            rule: `ADR-0002: Environment-specific config in base — ${desc}`,
          });
        }
      }
    }
  }

  // Also verify overlay directories exist
  const requiredOverlays = ["local", "production"];
  for (const overlay of requiredOverlays) {
    const overlayDir = join(projectRoot, "k8s", "overlays", overlay);
    try {
      statSync(overlayDir);
    } catch {
      violations.push({
        file: overlayDir,
        line: 0,
        match: "",
        rule: `ADR-0002: Required Kustomize overlay directory missing: k8s/overlays/${overlay}/`,
      });
    }
  }

  return violations;
}

function walkYaml(dir: string): string[] {
  const files: string[] = [];
  for (const entry of readdirSync(dir)) {
    const full = join(dir, entry);
    const stat = statSync(full);
    if (stat.isDirectory()) {
      files.push(...walkYaml(full));
    } else if (extname(full) === ".yaml" || extname(full) === ".yml") {
      files.push(full);
    }
  }
  return files;
}

const projectRoot = process.argv[2] || process.cwd();
const violations = check(projectRoot);

if (violations.length > 0) {
  for (const v of violations) {
    const loc = v.line > 0 ? `${v.file}:${v.line}` : v.file;
    console.error(
      `ERROR: ${v.rule} | ${loc} | WHY: Environment parity — ADR-0002 | FIX: Move to k8s/overlays/<env>/patches/`
    );
  }
  process.exit(1);
} else {
  console.log("ADR-0002: PASS — Base manifests are environment-neutral, overlays present");
  process.exit(0);
}

export { check, Violation };
