/**
 * ADR-0001: ローカルLLMの採用（セキュリティとコンプライアンス）
 *
 * Constraint: No external LLM API calls allowed.
 * All LLM inference must go through the internal Ollama service.
 * No SaaS LLM provider URLs (openai.com, api.anthropic.com, etc.) in application code.
 */

import { readFileSync, readdirSync, statSync } from "fs";
import { join, extname } from "path";

const FORBIDDEN_ENDPOINTS = [
  /api\.openai\.com/,
  /api\.anthropic\.com/,
  /generativelanguage\.googleapis\.com/,
  /api\.cohere\.ai/,
  /api\.mistral\.ai/,
  /api\.together\.xyz/,
];

const SCAN_EXTENSIONS = new Set([".py", ".ts", ".js", ".yaml", ".yml", ".tf"]);
const IGNORE_DIRS = new Set(["node_modules", ".git", ".terraform", "__pycache__", "venv", ".venv", ".rules"]);

interface Violation {
  file: string;
  line: number;
  match: string;
  rule: string;
}

function walkFiles(dir: string): string[] {
  const files: string[] = [];
  for (const entry of readdirSync(dir)) {
    if (IGNORE_DIRS.has(entry)) continue;
    const full = join(dir, entry);
    const stat = statSync(full);
    if (stat.isDirectory()) {
      files.push(...walkFiles(full));
    } else if (SCAN_EXTENSIONS.has(extname(full))) {
      files.push(full);
    }
  }
  return files;
}

function check(projectRoot: string): Violation[] {
  const violations: Violation[] = [];
  const files = walkFiles(projectRoot);

  for (const file of files) {
    const content = readFileSync(file, "utf-8");
    const lines = content.split("\n");

    for (let i = 0; i < lines.length; i++) {
      for (const pattern of FORBIDDEN_ENDPOINTS) {
        if (pattern.test(lines[i])) {
          violations.push({
            file,
            line: i + 1,
            match: lines[i].trim(),
            rule: "ADR-0001: External LLM API endpoint detected. All inference must use internal Ollama service.",
          });
        }
      }
    }
  }

  return violations;
}

// Run if executed directly
const projectRoot = process.argv[2] || process.cwd();
const violations = check(projectRoot);

if (violations.length > 0) {
  for (const v of violations) {
    console.error(
      `ERROR: ${v.rule} | ${v.file}:${v.line} | WHY: Data sovereignty — ADR-0001 | FIX: Use OLLAMA_BASE_URL (http://ollama:11434) instead`
    );
  }
  process.exit(1);
} else {
  console.log("ADR-0001: PASS — No external LLM API endpoints found");
  process.exit(0);
}

export { check, Violation };
