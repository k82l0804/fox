#!/usr/bin/env bash
# Fox CLI Port Script - Phase 1: Fork from Kilo Code CLI
# 
# This script copies the Kilo Code CLI source into fox-code-cli/
# with the right inclusion/exclusion lists.
#
# Run from: /home/k82l0804/workarea/fox/
set -euo pipefail

KILO_ROOT="ext-repo/agent-cli/kilocode"
FOX_CLI="fox-code-cli"

echo "=== Phase 1: Fork Kilo Code CLI → Fox Code CLI ==="
echo ""

# --- 1. Prepare fox-code-cli directory ---
echo "[1/6] Preparing $FOX_CLI directory..."
mkdir -p "$FOX_CLI/src"
mkdir -p "$FOX_CLI/bin"
mkdir -p "$FOX_CLI/test"

# --- 2. Copy the main opencode package source ---
echo "[2/6] Copying packages/opencode/src/ → $FOX_CLI/src/ ..."

# Copy everything first, then remove what we don't want
rsync -a --exclude='*.test.ts' \
  "$KILO_ROOT/packages/opencode/src/" \
  "$FOX_CLI/src/"

# --- 3. Copy required workspace packages as internal modules ---
echo "[3/6] Copying required workspace packages..."

# core - essential (session, permission, schema, database, etc.)
mkdir -p "$FOX_CLI/packages/core"
rsync -a "$KILO_ROOT/packages/core/src/" "$FOX_CLI/packages/core/src/"
cp "$KILO_ROOT/packages/core/package.json" "$FOX_CLI/packages/core/"
cp "$KILO_ROOT/packages/core/tsconfig.json" "$FOX_CLI/packages/core/"
[ -f "$KILO_ROOT/packages/core/drizzle.config.ts" ] && cp "$KILO_ROOT/packages/core/drizzle.config.ts" "$FOX_CLI/packages/core/"

# codemode - confined script execution
mkdir -p "$FOX_CLI/packages/codemode"
rsync -a "$KILO_ROOT/packages/codemode/src/" "$FOX_CLI/packages/codemode/src/"
cp "$KILO_ROOT/packages/codemode/package.json" "$FOX_CLI/packages/codemode/"
[ -f "$KILO_ROOT/packages/codemode/tsconfig.json" ] && cp "$KILO_ROOT/packages/codemode/tsconfig.json" "$FOX_CLI/packages/codemode/"

# llm - LLM provider abstractions (ai-sdk wrappers)
mkdir -p "$FOX_CLI/packages/llm"
rsync -a "$KILO_ROOT/packages/llm/src/" "$FOX_CLI/packages/llm/src/"
cp "$KILO_ROOT/packages/llm/package.json" "$FOX_CLI/packages/llm/"
[ -f "$KILO_ROOT/packages/llm/tsconfig.json" ] && cp "$KILO_ROOT/packages/llm/tsconfig.json" "$FOX_CLI/packages/llm/"

# protocol - ACP protocol types
mkdir -p "$FOX_CLI/packages/protocol"
rsync -a "$KILO_ROOT/packages/protocol/src/" "$FOX_CLI/packages/protocol/src/"
cp "$KILO_ROOT/packages/protocol/package.json" "$FOX_CLI/packages/protocol/"
[ -f "$KILO_ROOT/packages/protocol/tsconfig.json" ] && cp "$KILO_ROOT/packages/protocol/tsconfig.json" "$FOX_CLI/packages/protocol/"

# schema - shared schema utilities
mkdir -p "$FOX_CLI/packages/schema"
rsync -a "$KILO_ROOT/packages/schema/src/" "$FOX_CLI/packages/schema/src/"
cp "$KILO_ROOT/packages/schema/package.json" "$FOX_CLI/packages/schema/"
[ -f "$KILO_ROOT/packages/schema/tsconfig.json" ] && cp "$KILO_ROOT/packages/schema/tsconfig.json" "$FOX_CLI/packages/schema/"

# server - REST API server
mkdir -p "$FOX_CLI/packages/server"
rsync -a "$KILO_ROOT/packages/server/src/" "$FOX_CLI/packages/server/src/"
cp "$KILO_ROOT/packages/server/package.json" "$FOX_CLI/packages/server/"
[ -f "$KILO_ROOT/packages/server/tsconfig.json" ] && cp "$KILO_ROOT/packages/server/tsconfig.json" "$FOX_CLI/packages/server/"

# plugin - plugin system
mkdir -p "$FOX_CLI/packages/plugin"
rsync -a "$KILO_ROOT/packages/plugin/src/" "$FOX_CLI/packages/plugin/src/"
cp "$KILO_ROOT/packages/plugin/package.json" "$FOX_CLI/packages/plugin/"
[ -f "$KILO_ROOT/packages/plugin/tsconfig.json" ] && cp "$KILO_ROOT/packages/plugin/tsconfig.json" "$FOX_CLI/packages/plugin/"

# sdk - REST client SDK (used by ACP command)
mkdir -p "$FOX_CLI/packages/sdk"
rsync -a "$KILO_ROOT/packages/sdk/js/src/" "$FOX_CLI/packages/sdk/src/"
cp "$KILO_ROOT/packages/sdk/js/package.json" "$FOX_CLI/packages/sdk/"
[ -f "$KILO_ROOT/packages/sdk/js/tsconfig.json" ] && cp "$KILO_ROOT/packages/sdk/js/tsconfig.json" "$FOX_CLI/packages/sdk/"

# --- 4. Remove cloud-only modules ---
echo "[4/6] Removing cloud-only modules..."

# Kilo cloud services (send code/data to cloud)
rm -rf "$FOX_CLI/src/kilocode/cloud"
rm -rf "$FOX_CLI/src/kilocode/console"
rm -rf "$FOX_CLI/src/kilocode/marketplace"
rm -rf "$FOX_CLI/src/kilocode/memory"
rm -rf "$FOX_CLI/src/kilocode/anaconda-desktop"
rm -rf "$FOX_CLI/src/kilocode/review"
rm -rf "$FOX_CLI/src/kilocode/presence"

# Cloud auth & accounts
rm -rf "$FOX_CLI/src/auth"
rm -rf "$FOX_CLI/src/account"
rm -rf "$FOX_CLI/src/control-plane"
rm -rf "$FOX_CLI/src/sync"
rm -rf "$FOX_CLI/src/share"

# Kilo session features (cloud sync, import/export to cloud)
rm -f  "$FOX_CLI/src/kilocode/cloud-session.ts"
rm -rf "$FOX_CLI/src/kilocode/session-export"
rm -rf "$FOX_CLI/src/kilocode/session-import"
rm -rf "$FOX_CLI/src/kilocode/session-portability"

# Kilo-specific UI components (we'll use our own ACP client)
rm -rf "$FOX_CLI/src/kilocode/components"
rm -rf "$FOX_CLI/src/kilocode/tui"
rm -rf "$FOX_CLI/src/kilocode/board"

# Cloud event services
rm -rf "$FOX_CLI/src/kilocode/event-service"

# Kilo-specific server handlers for cloud
rm -f "$FOX_CLI/src/kilocode/server/httpapi/handlers/kilo-gateway.ts" 2>/dev/null || true
rm -f "$FOX_CLI/src/kilocode/server/httpapi/handlers/telemetry.ts" 2>/dev/null || true
rm -f "$FOX_CLI/src/kilocode/server/import-cloud-session-in-process.ts" 2>/dev/null || true

# --- 5. Copy build config ---
echo "[5/6] Copying build configuration..."
cp "$KILO_ROOT/packages/opencode/tsconfig.json" "$FOX_CLI/tsconfig.json"
cp "$KILO_ROOT/packages/opencode/package.json" "$FOX_CLI/package.json.kilo-original"
[ -d "$KILO_ROOT/packages/opencode/migration" ] && rsync -a "$KILO_ROOT/packages/opencode/migration/" "$FOX_CLI/migration/"

# Copy the root tsconfig for path references
cp "$KILO_ROOT/tsconfig.json" "$FOX_CLI/tsconfig.base.json"

# --- 6. Summary ---
echo "[6/6] Counting results..."
echo ""
echo "=== Fork Complete ==="
TOTAL_FILES=$(find "$FOX_CLI/src" "$FOX_CLI/packages" -name "*.ts" -o -name "*.tsx" -o -name "*.txt" 2>/dev/null | wc -l)
TOTAL_LINES=$(find "$FOX_CLI/src" "$FOX_CLI/packages" \( -name "*.ts" -o -name "*.tsx" -o -name "*.txt" \) 2>/dev/null | xargs wc -l 2>/dev/null | tail -1)
echo "  Source files: $TOTAL_FILES"
echo "  Total lines:  $TOTAL_LINES"
echo ""
echo "  Copied packages:"
for pkg in core codemode llm protocol schema server plugin sdk; do
  count=$(find "$FOX_CLI/packages/$pkg" -name "*.ts" 2>/dev/null | wc -l)
  echo "    - $pkg: $count files"
done
echo ""
echo "Next steps:"
echo "  1. Create fox-code-cli/package.json (strip cloud deps from package.json.kilo-original)"
echo "  2. Stub broken imports from stripped modules"
echo "  3. Get TypeScript compilation passing"
