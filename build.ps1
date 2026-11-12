param(
  [string]$DevEcoHome = $env:DEVECO_HOME,
  [switch]$Clean
)
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
if (-not $DevEcoHome) { throw 'Pass -DevEcoHome pointing to an existing DevEco Studio installation.' }
$node = Join-Path $DevEcoHome 'tools/node/node.exe'
$hvigor = Join-Path $DevEcoHome 'tools/hvigor/hvigor/bin/hvigor.js'
foreach ($path in @($node, $hvigor, 'build-profile.json5', 'oh_modules',
  'node_modules/@ohos/hvigor', 'node_modules/@ohos/hvigor-ohos-plugin')) {
  if (-not (Test-Path -LiteralPath $path)) { throw "Missing build prerequisite: $path" }
}
# Process-scoped paths; no machine settings, signing changes, or tool installation.
$env:DEVECO_SDK_HOME = Join-Path $DevEcoHome 'sdk'
$env:JAVA_HOME = Join-Path $DevEcoHome 'jbr'
$env:NODE_HOME = Join-Path $DevEcoHome 'tools/node'
$env:PATH = "$env:NODE_HOME;$env:JAVA_HOME/bin;$env:PATH"
$env:NODE_PATH = Join-Path $PSScriptRoot 'node_modules'
$env:HVIGOR_USER_HOME = Join-Path $PSScriptRoot '.hvigor/local-user-home'
$tasks = @()
if ($Clean) { $tasks += 'clean' }
$tasks += @('--no-daemon', '--no-parallel', '--mode', 'module', '-p', 'module=entry@default',
  '-p', 'product=default', '-p', 'debuggable=true', 'assembleHap')
& $node $hvigor @tasks
if ($LASTEXITCODE -ne 0) { throw "Hvigor failed: $LASTEXITCODE" }
python scripts/inspect_hap.py
if ($LASTEXITCODE -ne 0) { throw 'HAP inspection failed' }
