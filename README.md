# EL3313 — Taller de Diseño Digital

Repositorio de trabajo del curso **EL3313 Taller de Diseño Digital**, de la Escuela de Ingeniería Electrónica del Instituto Tecnológico de Costa Rica, correspondiente al **II Semestre de 2026**.

El repositorio reúne los proyectos desarrollados durante el curso, incluyendo documentación de diseño, código RTL en SystemVerilog, testbenches, archivos de restricciones para FPGA e informes técnicos.

Los proyectos se desarrollan siguiendo una metodología de **diseño modular**, avanzando desde la arquitectura general del sistema hasta la implementación y verificación de los módulos individuales.

---

## Integrantes

| Nombre | Carné |
|---|---:|
| Kevin Aarón Aguilar Mora | 2023395928 |
| Kenneth Aarón Campos Rodríguez | 2021023141 |
| Kevin Cortéz González | 2023099872 |
| Daniel Puentes | 2022111281 |

---

## Docentes

- **Dr.-Ing. Jeferson González-Gómez**
- **Ing. Rolen Coto Calderón**

---

## Proyectos

| Proyecto | Descripción | Tecnologías principales | Estado |
|---|---|---|---|
| [Proyecto 1 — Whack-a-Mole](./Proyecto1_Whack-a-mole/) | Juego híbrido implementado mediante FPGA y lógica discreta, con comunicación serial UART entre ambos subsistemas. | Basys 3, SystemVerilog, UART, lógica 74xx | Finalizado |
| Proyecto 2 - NA | --- | --- | --- |

Cada proyecto dispone de su propio `README.md`, donde se documentan su arquitectura, estructura interna, módulos implementados, procedimiento de uso y referencias hacia la documentación técnica.

---

## Estructura del repositorio

La organización general utilizada para los proyectos es la siguiente:

```text
Taller-Diseno-de-Sistemas-Digitales/
│
├── README.md
├── .gitignore
│
└── Proyecto1_Whack-a-mole/
    │
    ├── README.md
    │
    ├── docs/
    │   ├── diseno/
    │   │   ├── README.md
    │   │   └── img/
    │   │
    │   └── informe/
    │       ├── README.md
    │       ├── img/
    │       └── resultados/
    │
    └── src/
        ├── design/
        ├── testbench/
        └── constraints/
```

---

## Contenido de las carpetas

### `docs/diseno/`

Contiene el planteamiento y la documentación del diseño modular, incluyendo diagramas de arquitectura, diagramas de estados, esquemáticos, tablas, ecuaciones y decisiones de diseño.

### `docs/informe/`

Contiene el informe técnico final, resultados de simulación, mediciones, evidencia experimental y resultados relevantes de síntesis e implementación.

### `src/design/`

Contiene los módulos RTL sintetizables desarrollados en **SystemVerilog**.

### `src/testbench/`

Contiene los testbenches utilizados para verificar individualmente los módulos y el sistema integrado.

### `src/constraints/`

Contiene los archivos de restricciones de la FPGA, incluyendo la asignación de pines y las restricciones de reloj.

---

## Herramientas y tecnologías

Durante el desarrollo de los proyectos se utilizan principalmente:

- **AMD/Xilinx Vivado** — síntesis, implementación, análisis temporal y simulación.
- **SystemVerilog** — descripción RTL y desarrollo de testbenches.
- **Digilent Basys 3** — tarjeta de desarrollo basada en FPGA **Xilinx Artix-7 XC7A35T**.
- **Lógica discreta de la familia 74xx** — implementación de subsistemas digitales externos a la FPGA.
- **GitHub** — control de versiones y desarrollo colaborativo.
- **Markdown** — documentación técnica del diseño y de los informes.

---

## Metodología de diseño

Los proyectos se desarrollan utilizando una metodología de diseño modular:

1. Análisis de los requisitos del problema.
2. Investigación de los conceptos necesarios.
3. Definición de la arquitectura general.
4. Descomposición progresiva del sistema en subsistemas y módulos.
5. Diseño de lógica combinacional y secuencial.
6. Implementación RTL en SystemVerilog.
7. Desarrollo de testbenches y verificación por simulación.
8. Síntesis e implementación en FPGA.
9. Integración con los subsistemas externos.
10. Validación experimental y documentación de resultados.

Esta metodología permite verificar los componentes individualmente antes de integrarlos en el sistema completo y facilita la identificación de errores durante el proceso de diseño.

---

## Flujo de trabajo con Git

El desarrollo colaborativo se realiza mediante ramas de trabajo individuales o por funcionalidad.

El flujo general utilizado es:

```text
main
  │
  ├── rama de desarrollo
  │       │
  │       ├── commits de avance
  │       └── push al repositorio remoto
  │
  └──── Pull Request
             │
             ├── revisión de cambios
             └── integración a main
```

La rama `main` se utiliza para conservar las versiones integradas del proyecto, mientras que las modificaciones se desarrollan y documentan en ramas independientes antes de ser incorporadas mediante **Pull Requests**.

---

## Documentación

La documentación específica de cada proyecto puede consultarse desde su carpeta correspondiente.

Para el Proyecto 1:

- [Descripción y uso del proyecto](./Proyecto1_Whack-a-mole/README.md)
- [Documentación de diseño](./Proyecto1_Whack-a-mole/docs/diseno/README.md)
- [Informe técnico](./Proyecto1_Whack-a-mole/docs/informe/README.md)

---

## Curso

**EL3313 — Taller de Diseño Digital**  
Escuela de Ingeniería Electrónica  
Instituto Tecnológico de Costa Rica  
**II Semestre 2026**