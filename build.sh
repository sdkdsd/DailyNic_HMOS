#!/usr/bin/env bash
# Build only; never installs tools, generates keys, changes the target or connects a phone.
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"
if [[ -f /workspace/.cloud-tools/dailynic/activate.sh ]]; then
  source /workspace/.cloud-tools/dailynic/activate.sh
fi
if [[ ${1:-} == --check ]]; then
  exec python3 scripts/check_environment.py
fi
HVIGOR_BIN="${HVIGORW:-}"
if [[ -z "$HVIGOR_BIN" ]]; then HVIGOR_BIN="$(command -v hvigorw || true)"; fi
if [[ -z "$HVIGOR_BIN" && -n ${DEVECO_HOME:-} ]]; then
  for candidate in "$DEVECO_HOME/tools/hvigor/bin/hvigorw" "$DEVECO_HOME/tools/hvigor/bin/hvigorw.bat"; do
    if [[ -f "$candidate" ]]; then HVIGOR_BIN="$candidate"; break; fi
  done
fi
if [[ -z "$HVIGOR_BIN" || ! -f "$HVIGOR_BIN" ]]; then
  echo '构建未执行：找不到 Hvigor。请加载已部署工具链，或设置 HVIGORW 为已有工具的完整路径。' >&2
  exit 2
fi
if [[ ! -f build-profile.json5 ]]; then
  echo '构建未执行：缺少本地 build-profile.json5。将 .bak 复制为此文件可配置未签名构建；不会自动生成签名。' >&2
  exit 2
fi
if [[ -z ${DEVECO_SDK_HOME:-} || ! -d "$DEVECO_SDK_HOME" ]]; then
  echo '构建未执行：DEVECO_SDK_HOME 未指向已有 HarmonyOS SDK。' >&2
  exit 2
fi
"$HVIGOR_BIN" --no-daemon --no-parallel "$@" --mode module -p module=entry@default -p product=default -p debuggable=true assembleHap
python3 scripts/inspect_hap.py
