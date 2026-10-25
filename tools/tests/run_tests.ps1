# Solid Procedural - automatic tests (development tool, not shipped in the .rbz).
#
# Deploys the plugin of the project into each SketchUp, starts SketchUp with
# -RubyStartup tools/tests/run_tests.rb, waits for the report written in
# tools/tests/results/latest-<major>.txt, closes SketchUp and prints the report.
#
#   powershell -File tools\tests\run_tests.ps1                  # 2021 then 2017
#   powershell -File tools\tests\run_tests.ps1 -Versions 2017
#   powershell -File tools\tests\run_tests.ps1 -NoDeploy        # test what is installed
#   powershell -File tools\tests\run_tests.ps1 -Versions 2017 -Manual
#       manual test of onActivePathChanged: double-click "SP Test - open me",
#       then exit it (results/manual-<major>.txt)
#
# SketchUp must be closed: the tests never touch an open session.

param(
    [string[]]$Versions = @('2021', '2017'),
    [int]$Timeout = 300,
    [switch]$NoDeploy,
    [switch]$Manual
)

$ErrorActionPreference = 'Stop'
$tests = $PSScriptRoot
$project = Split-Path -Parent (Split-Path -Parent $tests)
$results = Join-Path $tests 'results'

# SketchUp executables (installation folders of this PC) and major versions.
$executables = @{
    '2021' = 'C:\Program Files\SketchUp\SketchUp 2021\SketchUp.exe'
    '2017' = 'C:\SketchUp 2017\SketchUp.exe'
}
$majors = @{ '2021' = '21'; '2017' = '17' }

if (Get-Process SketchUp -ErrorAction SilentlyContinue) {
    Write-Host 'SketchUp is running: close it first (the tests never touch an open session).'
    exit 2
}
New-Item -ItemType Directory -Force $results | Out-Null

$failed = 0
foreach ($version in $Versions) {
    $exe = $executables[$version]
    if (-not $exe -or -not (Test-Path $exe)) { Write-Host "SketchUp $version not found ($exe)"; $failed++; continue }

    if (-not $NoDeploy) {
        $plugins = Join-Path $env:APPDATA "SketchUp\SketchUp $version\SketchUp\Plugins"
        Copy-Item (Join-Path $project 'solid_procedural.rb') $plugins -Force
        # Mirror: files removed from the project are removed from the plugin too.
        robocopy (Join-Path $project 'solid_procedural') (Join-Path $plugins 'solid_procedural') /MIR /NJH /NJS /NFL /NDL /NP | Out-Null
        if ($LASTEXITCODE -ge 8) { Write-Host "Deployment to SketchUp $version failed"; $failed++; continue }
    }

    # The welcome screen blocks -RubyStartup until it is closed. 2021: it is
    # switched off for the run and switched back on after. 2017 (Make): no
    # such setting, click its button by hand.
    $prefs = Join-Path $env:LOCALAPPDATA "SketchUp\SketchUp $version\SketchUp\PrivatePreferences.json"
    $welcomeOn = '("WelcomeDialog":\s*\{\s*"ShowOnStartup":\s*)true'
    $welcomeOff = '("WelcomeDialog":\s*\{\s*"ShowOnStartup":\s*)false'
    $welcomeSwitched = $false
    if ((Test-Path $prefs) -and ((Get-Content $prefs -Raw) -match $welcomeOn)) {
        [IO.File]::WriteAllText($prefs, ((Get-Content $prefs -Raw) -replace $welcomeOn, '${1}false'))
        $welcomeSwitched = $true
    }

    $kind = if ($Manual) { 'manual' } else { 'latest' }
    $report = Join-Path $results ("{0}-{1}.txt" -f $kind, $majors[$version])
    $startup = Join-Path $tests $(if ($Manual) { 'manual_open.rb' } else { 'run_tests.rb' })
    $start = Get-Date
    Write-Host "SketchUp $version — tests running..."
    if (-not $welcomeSwitched) { Write-Host "  If the welcome screen of SketchUp $version shows, click its start button." }
    if ($Manual) { Write-Host "  Double-click 'SP Test - open me', then exit it (click outside it, or Escape)." }
    $process = Start-Process $exe -ArgumentList '-RubyStartup', ('"{0}"' -f $startup) -PassThru
    $done = $false
    while (((Get-Date) - $start).TotalSeconds -lt $Timeout) {
        Start-Sleep -Seconds 2
        if ((Test-Path $report) -and (Get-Item $report).LastWriteTime -gt $start) {
            if ($Manual -or (Get-Content $report -Encoding UTF8 -Raw) -match '(?m)^DONE ') { $done = $true; break }
        }
        if ($process.HasExited) { break }
    }
    Get-Process SketchUp -ErrorAction SilentlyContinue | Stop-Process -Force
    Start-Sleep -Seconds 2
    if ($welcomeSwitched -and (Test-Path $prefs)) {
        [IO.File]::WriteAllText($prefs, ((Get-Content $prefs -Raw) -replace $welcomeOff, '${1}true'))
    }

    if ($done) {
        $text = Get-Content $report -Encoding UTF8
        $text | ForEach-Object { Write-Host $_ }
        if (-not $Manual -and ($text | Select-Object -Last 1) -notmatch 'failed=0 ') { $failed++ }
    } else {
        Write-Host "SketchUp $version — no report after $Timeout s (or SketchUp closed)"
        $failed++
    }
    Write-Host ''
}
exit $failed
