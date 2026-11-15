"""Compila y corre todas las pruebas del software en PC.

Uso, desde la carpeta que contiene software/:  python software/tests/correr_pruebas.py
"""

import os
import subprocess
import sys

# Rutas
RAIZ = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
EMB = os.path.join("software", "embedded")
TESTS = os.path.join("software", "tests")
CARPETA = {"trama": "uart", "exportacion": "uart", "drv_adc": os.path.join("drivers", "adc"),
           "drv_pwm": os.path.join("drivers", "pwm"),
           "drv_gpio": os.path.join("drivers", "plataforma"),
           "drv_uart": os.path.join("drivers", "plataforma"),
           "drv_timer": os.path.join("drivers", "plataforma")}
BANDERAS = ["-std=c11", "-Wall", "-Wextra", "-Werror",
            "-I", os.path.join(EMB, "control"), "-I", os.path.join(EMB, "uart"),
            "-I", os.path.join(EMB, "drivers"), "-I", os.path.join(EMB, "drivers", "adc"),
            "-I", os.path.join(EMB, "drivers", "pwm"),
            "-I", os.path.join(EMB, "drivers", "plataforma")]

# Pruebas: nombre, módulos, banderas extra
APLICACION = ["aplicacion", "lectura", "supervision", "referencia", "control_pr", "modulacion",
              "registro", "antirrebote", "trama", "exportacion"]
PRUEBAS = [
    ("referencia",  ["referencia"], []),
    ("control_pr",  ["control_pr"], []),
    ("modulacion",  ["modulacion"], []),
    ("registro",    ["registro"], ["-DREGISTRO_N_BUF=8u"]),
    ("lectura",     ["lectura"], []),
    ("supervision", ["supervision"], []),
    ("antirrebote", ["antirrebote"], []),
    ("exportacion", ["registro", "trama", "exportacion"], ["-DREGISTRO_N_BUF=8u"]),
    ("drv_adc",     ["drv_adc"], ["-DADC_BASE=0x40000000u"]),
    ("drv_pwm",     ["drv_pwm"], ["-DPWM_BASE=0x44000000u"]),
    ("drv_plataforma", ["drv_gpio", "drv_uart", "drv_timer"],
     ["-DGPIO_ENTRADAS_BASE=0x40000000u", "-DGPIO_SALIDAS_BASE=0x40010000u",
      "-DUART_BASE=0x40600000u", "-DTIMER_BASE=0x41C00000u"]),
    ("aplicacion",  APLICACION, []),     # al final: genera la trama para la prueba de PC
]


def fuente(modulo):
    """Ruta del .c de un módulo."""
    return os.path.join(EMB, CARPETA.get(modulo, "control"), modulo + ".c")


def main():
    """Compila, corre y resume."""
    os.chdir(RAIZ)
    os.makedirs("build", exist_ok=True)
    resultados = []

    # Pruebas en C
    for nombre, modulos, extra in PRUEBAS:
        fuentes = [fuente(m) for m in modulos] + [os.path.join(TESTS, f"test_{nombre}.c")]
        exe = os.path.join("build", f"test_{nombre}.exe")
        comp = subprocess.run(["gcc", *BANDERAS, *extra, *fuentes, "-o", exe, "-lm"],
                              capture_output=True, text=True, check=False)
        if comp.returncode != 0:
            print(comp.stderr)
            resultados.append((nombre, "NO COMPILA"))
            continue
        corr = subprocess.run([exe], capture_output=True, encoding="utf-8",
                              errors="replace", check=False)
        pasan = corr.stdout.count("[PASA]")
        fallan = corr.stdout.count("[FALLA]")
        if corr.returncode != 0:
            print(corr.stdout)
        if corr.returncode == 0 or fallan:
            resultados.append((nombre, f"{pasan} pasan, {fallan} fallan"))
        else:
            resultados.append((nombre, "terminó con error"))

    # Prueba de la aplicación de PC
    py = subprocess.run([sys.executable, os.path.join("software", "pc", "test_receptor.py")],
                        capture_output=True, text=True, check=False)
    resultados.append(("receptor (PC)", "ok" if py.returncode == 0 else "FALLA"))
    if py.returncode != 0:
        print(py.stderr)

    # Resumen
    print()
    for nombre, estado in resultados:
        print(f"  {nombre:<15} {estado}")
    malas = [r for r in resultados if "0 fallan" not in r[1] and r[1] != "ok"]
    print("\nRESULTADO:", "POSITIVO" if not malas else f"NEGATIVO ({len(malas)} con problemas)")
    return 1 if malas else 0


if __name__ == "__main__":
    sys.exit(main())
