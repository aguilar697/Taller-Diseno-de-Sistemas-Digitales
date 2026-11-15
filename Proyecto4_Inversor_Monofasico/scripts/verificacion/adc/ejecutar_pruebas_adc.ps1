# Compila cada test desde fuentes del repositorio y regenera el IP en build/adc.
param(
    [string]$VivadoHome = $env:VIVADO_HOME,
    [string[]]$Tops = @('tb_adc_control','tb_adc_top','tb_adc_axi_lite','tb_adc_concurrency','tb_adc_system_axi','tb_adc_read_coherence'),
    [ValidatePattern('^[A-Za-z0-9_-]+$')][string]$RunName = (Get-Date -Format 'yyyyMMdd_HHmmss'),
    [switch]$NegativeUnknown
)
$ErrorActionPreference = 'Stop'
if (!$VivadoHome) { throw 'Indique -VivadoHome o defina VIVADO_HOME con la carpeta de Vivado 2026.1.' }
$allowed = @('tb_adc_control','tb_adc_top','tb_adc_axi_lite','tb_adc_concurrency','tb_adc_system_axi','tb_adc_read_coherence')
if (!$Tops.Count -or @($Tops | Where-Object { $_ -notin $allowed }).Count) { throw 'Lista de testbenches no valida.' }
if ($NegativeUnknown -and ($Tops.Count -ne 1 -or $Tops[0] -ne 'tb_adc_axi_lite')) { throw 'NegativeUnknown requiere solo tb_adc_axi_lite.' }
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$sourceDir = Join-Path $projectRoot 'src/design/adc'
$testDir = Join-Path $projectRoot 'src/testbench/adc'
$stimulus = Join-Path $testDir 'stimuli/design.txt'
$xci = Join-Path $sourceDir 'ip/xadc_wiz_0/xadc_wiz_0.xci'
$runRoot = Join-Path $projectRoot "build/adc/$RunName"
foreach ($executable in @('vivado.bat','xvlog.bat','xelab.bat','xsim.bat')) {
    if (!(Test-Path -LiteralPath (Join-Path $VivadoHome "bin/$executable"))) { throw "Falta $executable en VivadoHome." }
}
if (Test-Path -LiteralPath $runRoot) { throw "La ejecucion ya existe: $runRoot. Use otro RunName." }
New-Item -ItemType Directory -Path $runRoot -Force | Out-Null
$ipFile = $null
# El IP se importa en un proyecto descartable; no se necesitan wrappers versionados.
if (@($Tops | Where-Object { $_ -in @('tb_adc_top','tb_adc_system_axi','tb_adc_read_coherence') }).Count) {
    $xciHash = (Get-FileHash -LiteralPath $xci -Algorithm SHA256).Hash
    Push-Location -LiteralPath $runRoot
    try {
        & (Join-Path $VivadoHome 'bin/vivado.bat') -mode batch -nojournal -log 'generate_ip.log' -source (Join-Path $PSScriptRoot 'preparar_ip.tcl') -tclargs (Join-Path $runRoot 'ip') *> 'generate_ip.stdout.txt'
        if ($LASTEXITCODE -ne 0) { throw "No se pudo regenerar XADC; revisar $runRoot/generate_ip.log" }
    } finally { Pop-Location }
    if ((Get-FileHash -LiteralPath $xci -Algorithm SHA256).Hash -ne $xciHash) { throw 'Se modifico el XCI versionado.' }
    $ipFile = (Get-Content -LiteralPath (Join-Path $runRoot 'ip/wrapper.txt') -Raw).Trim()
    if ((Get-Content -LiteralPath $ipFile -Raw) -notmatch 'SIM_MONITOR_FILE\("design.txt"\)') { throw 'SIM_MONITOR_FILE distinto; revisar sin modificar el IP.' }
}
$summary = @()
foreach ($top in $Tops) {
    $work = Join-Path $runRoot $top
    New-Item -ItemType Directory -Path $work | Out-Null
    $sources = @()
    if ($top -in @('tb_adc_control','tb_adc_top','tb_adc_system_axi','tb_adc_concurrency','tb_adc_read_coherence')) { $sources += (Join-Path $sourceDir 'adc_control.sv') }
    if ($top -in @('tb_adc_top','tb_adc_system_axi','tb_adc_read_coherence')) {
        Copy-Item -LiteralPath $stimulus -Destination (Join-Path $work 'design.txt')
        if ((Get-FileHash -LiteralPath $stimulus).Hash -ne (Get-FileHash -LiteralPath (Join-Path $work 'design.txt')).Hash) { throw 'Copia analogica diferente.' }
        $sources += (Join-Path $sourceDir 'adc_top.sv'), $ipFile, (Join-Path $VivadoHome 'data/verilog/src/glbl.v')
    }
    if ($top -in @('tb_adc_axi_lite','tb_adc_system_axi','tb_adc_read_coherence')) { $sources += (Join-Path $sourceDir 'adc_axi_lite.sv') }
    if ($top -in @('tb_adc_system_axi','tb_adc_read_coherence')) { $sources += (Join-Path $sourceDir 'adc_system_axi.sv') }
    $sources += (Join-Path $testDir "$top.sv")
    $hashInputs = @($sources) + @($PSCommandPath, (Join-Path $PSScriptRoot 'preparar_ip.tcl'))
    if ($top -in @('tb_adc_axi_lite','tb_adc_system_axi','tb_adc_read_coherence')) { $hashInputs += (Join-Path $testDir 'adc_axi_tb_tasks.svh') }
    if ($top -in @('tb_adc_top','tb_adc_system_axi','tb_adc_read_coherence')) { $hashInputs += $stimulus, $xci }
    $hashInputs | ForEach-Object { Get-FileHash -Algorithm SHA256 -LiteralPath $_ } |
        Select-Object Path,Hash | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $work 'inputs.json') -Encoding UTF8
    $commands = @()
    Push-Location -LiteralPath $work
    try {
        $argsCompile = @('--sv','-i',$testDir) + $sources + @('-log','compile.log')
        $commands += ('xvlog ' + (($argsCompile | ForEach-Object { '"' + $_ + '"' }) -join ' '))
        & (Join-Path $VivadoHome 'bin/xvlog.bat') @argsCompile *> 'compile.stdout.txt'
        if ($LASTEXITCODE -ne 0) { throw "xvlog fallo en $work" }
        $argsElab = @('--debug','typical','-L','unisims_ver','-L','secureip','--snapshot',$top,"work.$top")
        if ($top -in @('tb_adc_top','tb_adc_system_axi','tb_adc_read_coherence')) { $argsElab += 'work.glbl' }
        $argsElab += @('-log','elaborate.log')
        $commands += ('xelab ' + (($argsElab | ForEach-Object { '"' + $_ + '"' }) -join ' '))
        & (Join-Path $VivadoHome 'bin/xelab.bat') @argsElab *> 'elaborate.stdout.txt'
        if ($LASTEXITCODE -ne 0) { throw "xelab fallo en $work" }
        $argsSim = @($top,'-runall','-log','simulate.log')
        if ($NegativeUnknown) { $argsSim += @('-testplusarg','INJECT_X') }
        $commands += ('xsim ' + ($argsSim -join ' '))
        & (Join-Path $VivadoHome 'bin/xsim.bat') @argsSim *> 'simulate.stdout.txt'
        $exitSim = $LASTEXITCODE
        $log = Get-Content -LiteralPath 'simulate.log' -Raw
        $passed = $exitSim -eq 0 -and $log -match 'TEST PASSED' -and $log -notmatch '(?im)^\s*(Fatal:|Error:|ERROR:|FATAL:)'
        $negativePassed = $NegativeUnknown -and $log -match 'UNKNOWN_BUS_DETECTED' -and $log -notmatch 'TEST PASSED'
        $commands | Set-Content -LiteralPath 'commands.txt' -Encoding UTF8
        $state = if ($negativePassed) { 'EXPECTED_FAIL_X' } elseif ($passed -and !$NegativeUnknown) { 'PASS' } else { 'FAIL' }
        $warnings = @(Select-String -Path 'compile.log','elaborate.log','simulate.log' -Pattern '^\s*WARNING:').Count
        $summary += [pscustomobject]@{top=$top;state=$state;exitCode=$exitSim;warnings=$warnings;log=(Join-Path $work 'simulate.log')}
        $summary | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $runRoot 'summary.json') -Encoding UTF8
        Write-Output "$top : $state : $work"
        if ($state -eq 'FAIL') { throw "Prueba fallida; revisar $work/simulate.log" }
    } finally { Pop-Location }
}
