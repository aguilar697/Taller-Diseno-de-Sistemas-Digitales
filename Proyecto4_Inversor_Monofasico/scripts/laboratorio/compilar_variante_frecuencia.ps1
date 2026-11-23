<#
Compila el software para otra frecuencia de conmutacion sin modificar el repositorio.
Copia scripts/ y software/ a SALIDA/fuente, ajusta parametros.h y compila en SALIDA/sw con build_integrated.py.
Ejemplos (Vitis 2026.1):
  20 kHz con lazo cerrado (Ts = 100 us, dos periodos PWM por control):
    .\compilar_variante_frecuencia.ps1 -Xsa C:/hw/inversor_integrado.xsa -Salida C:/var20 -FreqSel 1 -FswHz 20000 -TriggerPhase 2500 -NPwmPorControl 2
  25 kHz, solo para diagnostico_integrado en lazo abierto:
    .\compilar_variante_frecuencia.ps1 -Xsa C:/hw/inversor_integrado.xsa -Salida C:/var25 -FreqSel 2 -FswHz 25000 -TriggerPhase 2000 -NPwmPorControl 2
#>
param(
    [Parameter(Mandatory)] [string] $Xsa,
    [Parameter(Mandatory)] [string] $Salida,
    [Parameter(Mandatory)] [int] $FreqSel,
    [Parameter(Mandatory)] [int] $FswHz,
    [Parameter(Mandatory)] [int] $TriggerPhase,
    [Parameter(Mandatory)] [int] $NPwmPorControl,
    [string] $Xilinx = 'C:\AMDDesignTools\2026.1'
)
$ErrorActionPreference = 'Stop'
$proyecto = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$fuente = Join-Path $Salida 'fuente\Proyecto4_Inversor_Monofasico'
if (Test-Path $Salida) { throw "La salida ya existe: $Salida" }
New-Item -ItemType Directory -Force $fuente | Out-Null
foreach ($d in 'scripts', 'software') { Copy-Item -Recurse (Join-Path $proyecto $d) (Join-Path $fuente $d) }
Get-ChildItem $fuente -Recurse -Directory -Filter __pycache__ | Remove-Item -Recurse -Force

$p = Join-Path $fuente 'software\embedded\control\parametros.h'
$t = [IO.File]::ReadAllText($p)
$valores = [ordered]@{ FREQ_SEL = "${FreqSel}u"; F_SW_HZ = "${FswHz}u"; TRIGGER_PHASE = "${TriggerPhase}u"; N_PWM_POR_CONTROL = "${NPwmPorControl}u" }
foreach ($k in $valores.Keys) {
    $patron = "(?m)^#define $k\s+\S+"
    if ($t -notmatch $patron) { throw "No se encontro $k en parametros.h" }
    $t = [regex]::Replace($t, $patron, ("#define {0,-19} {1}" -f $k, $valores[$k]))
}
[IO.File]::WriteAllText($p, $t)
$m = Join-Path $fuente 'software\embedded\integration\main.c'
[IO.File]::WriteAllText($m, ([IO.File]::ReadAllText($m) -replace 'PWM 10 kHz', ("PWM {0} kHz" -f ($FswHz / 1000))))

$env:Path = "$Xilinx\Vivado\bin;$Xilinx\gnu\riscv\nt\bin;$env:Path"
$ws = ($Salida -replace '\\', '/') + '/sw'
Push-Location $fuente
try {
    cmd /c "`"$Xilinx\Vitis\bin\vitis.bat`" -s scripts/vitis/build_integrated.py $Xsa $ws --incluir-laboratorio > `"$Salida\build.log`" 2>&1"
    if (-not (Select-String -Path "$Salida\build.log" -Pattern 'CONSTRUCCION_INTEGRADA_PASS' -Quiet)) { throw "Fallo la compilacion: $Salida\build.log" }
} finally { Pop-Location }
"VARIANTE_LISTA en $ws"
