# Simple helper to run Flutter with Impeller enabled by default.
# Usage:
#   ./tool/run_impeller.ps1 -Device R5CX22CF1XT      # Android device id from `flutter devices`
#   ./tool/run_impeller.ps1 -Device chrome -Verbose  # Web

param(
  [string]$Device = "",
  [switch]$Verbose
)

$argsList = @("run", "--enable-impeller")
if ($Device -ne "") {
  $argsList += @("-d", $Device)
}
if ($Verbose.IsPresent) {
  $argsList += "-v"
}

Write-Host "flutter $($argsList -join ' ')" -ForegroundColor Cyan

$proc = Start-Process -FilePath "flutter" `
  -ArgumentList $argsList `
  -NoNewWindow `
  -Wait `
  -PassThru

exit $proc.ExitCode
