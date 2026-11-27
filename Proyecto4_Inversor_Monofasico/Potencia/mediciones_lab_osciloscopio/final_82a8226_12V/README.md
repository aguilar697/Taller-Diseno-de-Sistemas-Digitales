# Ensayos de la versión presentada (26/11)

Software `82a8226`, bus de potencia de 12 V fijos, normalización del PR de 24 V en firmware y carga de 7,3 Ω (R3 puenteada) o 10,6 Ω.
Osciloscopio: tensión en la resistencia de 3,4 Ω.

## UART (`uart/`, régimen permanente)

La [carpeta UART](uart/) conserva el binario original, los datos decodificados en CSV y el resumen de cada trama. Las referencias y fundamentales de la tabla son amplitudes pico.

| Trama original | Carga | Ref. (A) | Fundamental (A) | Error | Desfase |
|---|---|---|---|---|---|
| [r73_0a2](uart/r73_0a2.bin) / [repetición](uart/r73_0a2_rep.bin) | 7,3 Ω | 0,2 | 0,176 / 0,175 | −12,1 % / −12,6 % | −7° |
| [r73_0a5](uart/r73_0a5.bin) / [repetición](uart/r73_0a5_rep.bin) / [adicional](uart/r73_0a5_adicional.bin) | 7,3 Ω | 0,5 | 0,390 / 0,390 / 0,388 | −22 % | −58° |
| [r73_1a](uart/r73_1a.bin) | 7,3 Ω | 1,0 | 0,337 | −66 % | −69° |
| [r106_0a2](uart/r106_0a2.bin) | 10,6 Ω | 0,2 | 0,169 | −15 % | −7° |
| [r106_0a5](uart/r106_0a5.bin) | 10,6 Ω | 0,5 | 0,342 | −32 % | −61° |
| [cambio_carga_despues](uart/cambio_carga_despues.bin) | 10,6 Ω | 0,5 | 0,343 | −31 % | −60° |

`reposo_off` (potencia apagada) y `reposo_12v*`: referencia cero; media 6 a 10 mA, 15 mA rms.
Sin fallas ni conversiones perdidas; ISR máx. 8,94 µs. Ningún punto cumple ±10 %.
En las 500 muestras de los cinco ciclos más recientes de cada captura principal, el mando alcanzó el límite Q1.15 en el 16,4 % (`r73_0a5`), 33,0 % (`r73_1a`) y 17,0 % (`r106_0a5`). Los registros principales a 0,2 A no alcanzaron el límite.

## Régimen en osciloscopio (`regimen/`)

| Ref. (A pico) | Fundamental 50 Hz (V pico) | Distorsión armónicos 2–9 | Captura |
|---|---|---|---|
| 0,2 | 0,485 | 12 % | [CSV](regimen/0a2_scope_16.csv) |
| 0,5 | 1,05 | 37 % | [CSV](regimen/0a5_scope_18.csv) |
| 1,0 | 0,868 | 30 % | [CSV](regimen/1a_scope_20.csv) |

[Gráfica de las tres consignas](regimen/regimen_0a2_0a5_1a.png).

## Transitorios

| Ensayo | Fundamental (V pico) | Asentamiento | Observación |
|---|---|---|---|
| 0,2 → 0,5 A ([CSV](escalones/0a2_a_0a5_scope_17.csv), [gráfica](escalones/escalon_0a2_0a5.png)) | 0,48 → 1,06 | ≈75 ms | pico 1,88 V, menor que el del régimen final (1,95 V) |
| 0,5 → 1 A ([CSV](escalones/0a5_a_1a_scope_19.csv), [gráfica](escalones/escalon_0a5_1a.png)) | 1,05 → 0,87 | ≈60 ms | pico 2,25 V (16 % sobre el previo); la corriente no sube |
| 7,3 → 10,6 Ω, 0,5 A ([CSV](cambio_carga/scope_15.csv), [gráfica](cambio_carga/cambio_carga_0a5.png)) | 1,04 → 0,92 | 20–40 ms | Caída de 11,5 % respecto a la amplitud previa. El lazo sigue operando. |

## Tiempo muerto (`tiempo_muerto/`)

Los pares JA1/JA2 ([CSV](tiempo_muerto/JA1_JA2_scope_21.csv), [captura](tiempo_muerto/JA1_JA2_scope_22.png)) y JA3/JA4 ([CSV](tiempo_muerto/JA3_JA4_scope_24.csv), [captura](tiempo_muerto/JA3_JA4_scope_23.png)) muestran 1,00 µs al 50 % de amplitud y unos 0,98 µs con ambas órdenes por debajo de 0,8 V. En las transiciones capturadas se comprobó la separación de las órdenes lógicas.

## Rizado (`rizado/`, preliminar)

CH1 y CH2 en los extremos de la resistencia, F1 = CH1 − CH2, ventana de 200 µs. Límite: 0,20 A pp.

| Captura | Bruto pp (A) | Filtrado pp (A) |
|---|---|---|
| [A, 0,2 A](rizado/A_0a2_scope_25.csv) | 0,166 | 0,047 |
| [B, 0,5 A](rizado/B_0a5_scope_27.csv) | 0,180 | 0,048 |
| [C, 1 A](rizado/C_1a_scope_28.csv) | 0,251 | 0,049 |

- Bruto: F1 menos su tendencia lineal, con todos los picos de conmutación.
- Filtrado: además, promedio móvil de 1 µs, excluyendo ±1 µs alrededor de un pico
  cercano a +29 µs y 60 muestras en cada extremo.
- C supera el límite en bruto; solo queda por debajo con el filtrado.
- F1 sigue en parte a la tensión de modo común (1 a 2 %), posible error de medición no confirmado.
- [D, ambas sondas en el mismo punto](rizado/D_mismo_punto_scope_29.csv) se tomó a 20 ms/div: nivel medio de −59 mV y 75 mV pp.
  No es comparable con A–C.

La variación pico a pico de la tendencia lineal en los 200 µs fue de 0,68, 6,65 y 4,12 mA en A, B y C. Es una estimación local de baja frecuencia. Los valores bruto y filtrado corresponden al residuo respecto a esa tendencia.

## Lazo de control en JB1 (`jb1/`)

El [CSV de JB1](jb1/un_pulso_scope_30.csv) contiene un solo pulso: ancho 7,55 µs al 50 %, nivel alto 3,26 V. No se confirmó
el estado del sistema y el disparo no estaba en ese flanco. No mide período ni jitter.

## Pendiente

- Período y jitter del lazo en JB1, también durante la exportación UART (no medidos).
- Opcional: tiempo muerto en V_GS, D repetida a 20 µs/div.
