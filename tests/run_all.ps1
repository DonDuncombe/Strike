# Runs every tests/*_test.gd headless. Set GODOT_BIN to the Godot 4.7.1 console executable.
param([string]$Godot = $(if ($env:GODOT_BIN) { $env:GODOT_BIN } else { "godot" }))

$project = Split-Path -Parent $PSScriptRoot
$failed = @()
foreach ($test in Get-ChildItem -Path $PSScriptRoot -Filter "*_test.gd") {
	Write-Host "=== $($test.BaseName)"
	& $Godot --headless --path $project --script "res://tests/$($test.Name)"
	if ($LASTEXITCODE -ne 0) { $failed += $test.BaseName }
}
if ($failed.Count -gt 0) {
	Write-Host "FAILED: $($failed -join ', ')"
	exit 1
}
Write-Host "All test suites passed."
