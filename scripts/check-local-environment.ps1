# Read-only on the user's Windows computer. Does not install or change settings.
$ErrorActionPreference = 'Stop'
Write-Output ('OS: ' + [Environment]::OSVersion.VersionString)
foreach ($tool in @('node', 'java', 'ohpm', 'hvigorw', 'hdc')) {
  $found = Get-Command $tool -ErrorAction SilentlyContinue
  Write-Output ($tool + ': ' + $(if ($found) { 'found on PATH' } else { 'not found on PATH' }))
}
foreach ($setting in @('DEVECO_HOME', 'DEVECO_SDK_HOME', 'JAVA_HOME')) {
  $value = [Environment]::GetEnvironmentVariable($setting)
  Write-Output ($setting + ': ' + $(if ($value -and (Test-Path -LiteralPath $value)) { 'existing path' } else { 'unset or missing' }))
}
Write-Output 'IDE-managed tools may exist outside PATH. Check their versions in DevEco Studio without exporting signing settings.'
Write-Output 'No device access, signing, installation or settings changes were performed.'
