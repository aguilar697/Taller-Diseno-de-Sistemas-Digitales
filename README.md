# Taller de Diseño de Sistemas Digitales — EL 3313

Repositorio del curso **EL 3313 Taller de Diseño Digital**, Escuela de Ingeniería Electrónica, Instituto Tecnológico de Costa Rica (ITCR), Campus Tecnológico Central Cartago — II Semestre 2026.

Este repositorio centraliza todos los proyectos desarrollados durante el curso. Cada proyecto se ubica en su propia carpeta, siguiendo la metodología de diseño modular y los formatos de entrega definidos por el curso.

## Integrantes del grupo

| Nombre | Carné |
|---|---|
| Kevin Aarón Aguilar Mora | 2023395928 |
| Kenneth Aarón Campos Rodríguez | 2021023141 |
| Kevin Cortéz González | 2023099872 |
| Daniel Puentes | 2022111281 |

## Docente

- Prof. Ing. Rolen Coto Calderón

## Estructura del repositorio

Este repositorio contiene todos los proyectos del curso. Cada proyecto se ubica en su propia carpeta, siguiendo una estructura interna estandarizada:
```
├── Proyecto1_NombreProyecto/
│   ├── docs/
│   │   ├── diseño/       # Planteamiento del diseño (metodología modular)
│   │   └── informe/      # Informe técnico final
│   ├── src/
│   │   ├── design/       # Módulos SystemVerilog
│   │   ├── testbench/    # Testbenches
│   │   └── constraints/  # Archivos .xdc
│   ├── scripts/          # Scripts de automatización (Tcl / Vivado)
│   └── README.md         # Documentación específica del proyecto
│
├── Proyecto2_NombreProyecto/
│   └── (misma estructura)
│
└── README.md              # Documentación general del repositorio
```
Cada carpeta de proyecto es independiente y contiene su propia documentación de diseño, código fuente, pruebas y README detallando los módulos desarrollados.

## Herramientas utilizadas

- **Vivado** — síntesis, implementación y simulación de diseños en FPGA
- **SystemVerilog** — descripción de hardware (RTL)
- **GitHub** — control de versiones y trabajo colaborativo
- Tarjeta de desarrollo FPGA (BASYS3-Artic7)
- Componentes discretos (familia 74xx) para las partes implementadas en protoboard

## Metodología de trabajo

Cada proyecto sigue la metodología de **diseño modular**: comprensión del problema, investigación previa, planteamiento del diseño por niveles (bloques generales → bloques funcionales → módulos individuales), implementación, y elaboración del informe final.

## Cómo navegar el repositorio

Cada carpeta de proyecto contiene su propio README con el detalle de los módulos diseñados, criterios de diseño, testbenches y resultados de simulación.
