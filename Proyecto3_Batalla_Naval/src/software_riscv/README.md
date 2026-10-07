# Programa del juego

El programa utiliza el subconjunto RV32I implementado por la CPU y ejecuta las reglas del juego mediante accesos MMIO. El hardware y la terminal de PC no deciden la validez de las jugadas.

| Archivo | Función |
|---|---|
| `constantes.s` | Direcciones, registros, estados y códigos del protocolo |
| `main.s` | Inicialización y ciclo de servicio |
| `control_estado.s` | Fases, reinicio y marcador |
| `colocacion.s` | Colocación y validación de flotas |
| `turnos.s` | Alternancia y validación de disparos |
| `victoria.s` | Hundimientos y condición de victoria |
| `uart.s` | Recepción, parser y cola de transmisión |
| `salidas.s` | Actualización de VGA, LED, displays y buzzer |
| `program.hex` | ROM de 2048 palabras de 32 bits |

Desde la raíz de `Proyecto3_Batalla_Naval`:

```powershell
python scripts/ensamblar_programa.py --check
python scripts/ensamblar_programa.py
```

La primera orden comprueba la correspondencia entre las fuentes y el HEX sin modificarlo. La segunda regenera la imagen. El programa ocupa 1739 palabras; las restantes contienen NOP. El ensamblador valida registros, inmediatos, alineación de destinos, símbolos y capacidad de la ROM. No requiere paquetes de Python adicionales.

Las pseudoinstrucciones `call` se expanden a `jal ra, destino`, y `li` a una o dos instrucciones. Esta expansión reproduce la imagen utilizada en las pruebas de integración. Otro ensamblador puede producir una imagen distinta; cualquier cambio de herramienta o programa requiere repetir las pruebas y generar un nuevo bitstream.

El ciclo principal atiende botones, RX, TX y un paso de redibujado VGA. La UART recibe un byte pendiente, sin FIFO; la terminal espera respuesta a cada solicitud. El programa consume RX mediante escritura de uno en CONTROL bit 1 y transmite cuando CONTROL bit 0 indica disponibilidad. El buzzer limita en hardware la duración de cada sonido.

Al salir del reset general, `sistema_init` ejecuta una espera de `ESPERA_ARRANQUE=120000` iteraciones antes de `partida_init`. En esta CPU multiciclo la espera supera los 10 ms del debounce y permite guardar en `BTN_PREV` los niveles estabilizados de los switches. Un switch que ya esté activo al arrancar no se interpreta como una nueva confirmación o rotación. Esta espera corresponde al arranque del hardware; `GAME_RST` inicia otra partida sin repetirla.
