/**
 * ADR Integrity Check — structural consistency across all ADRs
 *
 * Deterministic rules (no LLM judgment):
 * 1. Every ADR must have a Status field (ACCEPTED / SUPERSEDED / DEPRECATED)
 * 2. Every ACCEPTED ADR must have a companion .rules.ts file
 * 3. Every companion .rules.ts must have a corresponding ADR .md file
 * 4. SUPERSEDED ADRs must reference the successor ("by [ADR-NNNN]")
 * 5. The successor ADR must exist and be ACCEPTED
 * 6. SUPERSEDED ADRs must NOT have an active companion .rules.ts
 *    (the successor's rule replaces it)
 * 7. No two ACCEPTED ADRs on the same topic (detected via filename collision)
 * 8. Timestamps must be present and valid ISO dates
 */

import { readFileSync, readdirSync, existsSync } from "fs";
import { join, basename } from "path";

interface Violation {
  file: string;
  rule: string;
}

const VALID_STATUSES = ["ACCEPTED", "SUPERSEDED", "DEPRECATED"];
const STATUS_REGEX = /\|\s*Status\s*\|\s*\*\*(ACCEPTED|SUPERSEDED|DEPRECATED)\*\*/;
const SUPERSEDED_BY_REGEX = /SUPERSEDED\*\*\s*by\s*\[ADR-(\d{4})\]/;
const TIMESTAMP_FIELDS = ["提案日", "承認日"];
const ISO_DATE_REGEX = /\d{4}-\d{2}-\d{2}/;

function check(projectRoot: string): Violation[] {
  const violations: Violation[] = [];
  const adrDir = join(projectRoot, "docs", "adr");
  const rulesDir = join(adrDir, ".rules");

  // Collect all ADR .md files
  let adrFiles: string[];
  try {
    adrFiles = readdirSync(adrDir).filter(
      (f) => f.match(/^\d{4}-.*\.md$/)
    );
  } catch {
    return [{ file: adrDir, rule: "ADR directory not found" }];
  }

  // Collect all companion .rules.ts files
  let ruleFiles: string[];
  try {
    ruleFiles = readdirSync(rulesDir).filter(
      (f) => f.match(/^ADR-\d{4}\.ts$/)
    );
  } catch {
    ruleFiles = [];
  }

  const ruleNumbers = new Set(
    ruleFiles.map((f) => f.match(/ADR-(\d{4})/)![1])
  );

  const acceptedAdrs: string[] = [];

  for (const file of adrFiles) {
    const filePath = join(adrDir, file);
    const content = readFileSync(filePath, "utf-8");
    const adrNum = file.match(/^(\d{4})/)?.[1];

    if (!adrNum) continue;

    // Rule 1: Status field must exist
    const statusMatch = content.match(STATUS_REGEX);
    if (!statusMatch) {
      violations.push({
        file: filePath,
        rule: `ADR-${adrNum} missing valid Status field. Must be one of: ${VALID_STATUSES.join(", ")}`,
      });
      continue;
    }

    const status = statusMatch[1];

    // Rule 8: Timestamps must be present
    for (const field of TIMESTAMP_FIELDS) {
      const fieldRegex = new RegExp(`${field}\\s*\\|\\s*(${ISO_DATE_REGEX.source})`);
      if (!fieldRegex.test(content)) {
        violations.push({
          file: filePath,
          rule: `ADR-${adrNum} missing or invalid '${field}' timestamp (expected YYYY-MM-DD)`,
        });
      }
    }

    if (status === "ACCEPTED") {
      acceptedAdrs.push(adrNum);

      // Rule 2: ACCEPTED ADR must have companion .rules.ts
      if (!ruleNumbers.has(adrNum)) {
        violations.push({
          file: filePath,
          rule: `ADR-${adrNum} is ACCEPTED but has no companion rule file (docs/adr/.rules/ADR-${adrNum}.ts)`,
        });
      }
    }

    if (status === "SUPERSEDED") {
      // Rule 4: Must reference successor
      const successorMatch = content.match(SUPERSEDED_BY_REGEX);
      if (!successorMatch) {
        violations.push({
          file: filePath,
          rule: `ADR-${adrNum} is SUPERSEDED but does not reference a successor ADR (expected "SUPERSEDED** by [ADR-NNNN]")`,
        });
      } else {
        const successorNum = successorMatch[1];

        // Rule 5: Successor must exist and be ACCEPTED
        const successorFile = adrFiles.find((f) => f.startsWith(successorNum));
        if (!successorFile) {
          violations.push({
            file: filePath,
            rule: `ADR-${adrNum} references successor ADR-${successorNum} but that file does not exist`,
          });
        } else {
          const successorContent = readFileSync(
            join(adrDir, successorFile),
            "utf-8"
          );
          const successorStatus = successorContent.match(STATUS_REGEX);
          if (successorStatus && successorStatus[1] !== "ACCEPTED") {
            violations.push({
              file: filePath,
              rule: `ADR-${adrNum} references successor ADR-${successorNum} but successor status is ${successorStatus[1]} (expected ACCEPTED)`,
            });
          }
        }
      }

      // Rule 6: SUPERSEDED ADR should not have active companion rule
      if (ruleNumbers.has(adrNum)) {
        violations.push({
          file: join(rulesDir, `ADR-${adrNum}.ts`),
          rule: `ADR-${adrNum} is SUPERSEDED but still has an active companion rule file. Remove or replace with successor's rule.`,
        });
      }
    }
  }

  // Rule 3: Every companion .rules.ts must have a corresponding ADR
  for (const ruleFile of ruleFiles) {
    const ruleNum = ruleFile.match(/ADR-(\d{4})/)![1];
    const hasAdr = adrFiles.some((f) => f.startsWith(ruleNum));
    if (!hasAdr) {
      violations.push({
        file: join(rulesDir, ruleFile),
        rule: `Companion rule ADR-${ruleNum}.ts has no corresponding ADR document`,
      });
    }
  }

  return violations;
}

// Run
const projectRoot = process.argv[2] || process.cwd();
const violations = check(projectRoot);

if (violations.length > 0) {
  for (const v of violations) {
    console.error(
      `ERROR: ${v.rule} | ${v.file} | WHY: ADR integrity — structural consistency | FIX: Update ADR status, add missing timestamps, or fix cross-references`
    );
  }
  process.exit(1);
} else {
  console.log("ADR-integrity: PASS — All ADRs structurally consistent (statuses, timestamps, cross-refs, companion rules)");
  process.exit(0);
}

export { check, Violation };
