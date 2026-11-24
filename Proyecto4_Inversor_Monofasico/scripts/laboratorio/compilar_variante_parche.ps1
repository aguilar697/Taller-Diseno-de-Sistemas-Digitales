<#
Compila control_inversor con un parche de laboratorio sin modificar el repositorio.
Copia scripts/ y software/ a SALIDA/fuente, aplica el parche y compila en SALIDA/sw.
Ejemplos (Vitis 2026.1):
  Registro de falla:      .\compilar_variante_parche.ps1 -Xsa C:/hw/inversor_integrado.xsa -Salida C:/var_falla -Parche aplicar_captura_falla.py
  Captura de transitorio: .\compilar_variante_parche.ps1 -Xsa C:/hw/inversor_integrado.xsa -Salida C:/var_captura -Parche aplicar_captura_transitorio.py
#>
param(
    [Parameter(Mandatory)] [string] $Xsa,
    [Parameter(Mandatory)] [string] $Salida,
    [Parameter(Mandatory)] [string] $Parche,
    [string] $Python = 'python',
    [string] $Xilinx = 'C:\AMDDesignTools\2026.1'
)
$ErrorActionPreference = 'Stop'
$proyecto = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$fuente = Join-Path $Salida 'fuente\Proyecto4_Inversor_Monofasico'
if (Test-Path $Salida) { throw "La salida ya existe: $Salida" }
New-Item -ItemType Directory -Force $fuente | Out-Null
foreach ($d in 'scripts', 'software') { Copy-Item -Recurse (Join-Path $proyecto $d) (Join-Path $fuente $d) }
Get-ChildItem $fuente -Recurse -Directory -Filter __pycache__ | Remove-Item -Recurse -Force
& $Python -B (Join-Path $PSScriptRoot $Parche) $fuente
if ($LASTEXITCODE -ne 0) { throw 'Fallo el parche' }

$env:Path = "$Xilinx\Vivado\bin;$Xilinx\gnu\riscv\nt\bin;$env:Path"
$ws = ($Salida -replace '\\', '/') + '/sw'
Push-Location $fuente
try {
    cmd /c "`"$Xilinx\Vitis\bin\vitis.bat`" -s scripts/vitis/build_integrated.py $Xsa $ws --incluir-laboratorio > `"$Salida\build.log`" 2>&1"
    if (-not (Select-String -Path "$Salida\build.log" -Pattern 'CONSTRUCCION_INTEGRADA_PASS' -Quiet)) { throw "Fallo la compilacion: $Salida\build.log" }
} finally { Pop-Location }
"VARIANTE_LISTA en $ws"
