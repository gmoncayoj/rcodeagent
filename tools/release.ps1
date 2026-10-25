param([string]$RBin = 'R.exe', [string]$Rscript = 'Rscript.exe', [switch]$SkipSourceTests, [switch]$AsCran)
$ErrorActionPreference = 'Stop'
$rgRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
Set-Location -LiteralPath $rgRoot
foreach ($rgDir in @('.local/release-temp', '.local/validation', '.local/library', 'dist')) {
  New-Item -ItemType Directory -Force -Path $rgDir | Out-Null
}
$env:LC_ALL = 'English_United States.utf8'
$env:TEMP = (Resolve-Path '.local/release-temp').Path
$env:TMP = $env:TEMP
$rgVersion = @(& $Rscript --vanilla -e 'cat(read.dcf("DESCRIPTION", fields = "Version")[[1L]])') -join ''
if ($LASTEXITCODE -ne 0 -or $rgVersion -notmatch '^\d+(\.\d+)+$') {
  throw 'Cannot resolve a valid package version from DESCRIPTION.'
}
# R CMD check sanitizes user-library settings on some Windows installations.
# Reuse the paths visible to Rscript as site libraries for this check process.
$rgLibraries = @(& $Rscript --vanilla -e 'cat(.libPaths(), sep = "\n")')
if ($LASTEXITCODE -ne 0) { throw 'Cannot resolve the R runtime library paths.' }
$rgLibraries = @($rgLibraries | Where-Object { Test-Path -LiteralPath $_ -PathType Container })
if (!$rgLibraries.Count) { throw 'No existing R runtime libraries found.' }
$env:R_LIBS_SITE = $rgLibraries -join [IO.Path]::PathSeparator
if (!$SkipSourceTests) {
  & $Rscript --vanilla -e 'testthat::test_local(".")' *> .local/validation/tests.txt
  if ($LASTEXITCODE -ne 0) { throw 'Source tests failed; inspect .local/validation/tests.txt' }
}
$rgTar = Join-Path $rgRoot "dist/rcodeagent_$rgVersion.tar.gz"
if (Test-Path -LiteralPath $rgTar) { throw 'Final archive exists; preserve it before rebuilding.' }
$rgStage = Join-Path $rgRoot '.local/build/rcodeagent'
if (Test-Path -LiteralPath $rgStage) { throw 'Build stage exists; preserve it before rebuilding.' }
New-Item -ItemType Directory -Path $rgStage -Force | Out-Null
foreach ($rgName in @('R','tests','inst','man','DESCRIPTION','NAMESPACE','.Rbuildignore','NEWS.md')) {
  Copy-Item -LiteralPath (Join-Path $rgRoot $rgName) -Destination (Join-Path $rgStage $rgName) -Recurse
}
Push-Location dist
try { & $RBin CMD build $rgStage *> ../.local/validation/build.txt }
finally { Pop-Location }
if ($LASTEXITCODE -ne 0) { throw 'Build failed; inspect .local/validation/build.txt' }
& $Rscript --vanilla tools/verify-package.R *> .local/validation/install.txt
if ($LASTEXITCODE -ne 0) { throw 'Installed verification failed; inspect .local/validation/install.txt' }
$rgCheckArgs = @(if ($AsCran) { '--as-cran' } else { '--no-manual'; '--no-vignettes' })
& $RBin CMD check @rgCheckArgs --output=.local/validation $rgTar *> .local/validation/check.txt
if ($LASTEXITCODE -ne 0) { throw 'Check failed; inspect .local/validation/check.txt' }
Get-Content .local/validation/check.txt -Tail 15
Get-FileHash -LiteralPath $rgTar -Algorithm SHA256 | Select-Object Path, Hash | ConvertTo-Json
