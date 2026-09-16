# Informe de verificación — Interfaz local

**Subsistema:** S4. **Responsable:** Kevin Cortés.

## 1. Objetivo y fundamento

Presentar el estado del juego mediante LCD, siete segmentos, LED y buzzer. El LCD requiere secuencias de inicialización, preparación, pulso y ejecución; los displays usan barrido multiplexado y el buzzer divide el reloj mediante contadores. El [diseño de S4](../diseno/nivel_3_interfaz_local.md) desarrolla interfaces, FSM, registros y valores nominales.

## 2. Simulación e implementación

La simulación integrada `tb_top` instancia la interfaz local y comprueba valores definidos después del reset. La validación del texto LCD, las temporizaciones de escritura y los tonos requiere pruebas específicas del subsistema. Los recursos y el análisis temporal del diseño completo se presentan en el [informe general](README.md).

### 2.1. Testbench autoverificable de la interfaz local

### **EN PROCESO**

### 2.2. Formas de onda de LCD, displays y buzzer

### **EN PROCESO**

## 3. Análisis temporal y funcional

Una prueba dirigida de `lcd_peripheral` a 100 MHz midió 10 ns entre el cambio de RS y la subida de E. La hoja HD44780U indica mínimos de 40 ns a 4.5–5.5 V y 60 ns a 2.7–4.5 V. El controlador concreto del PmodCLP debe contrastarse con su propia especificación: Digilent identifica un KS0066. El ancho del pulso E no sustituye la preparación previa de RS.

El RTL espera 15 ms desde reset antes del primer comando; el manual PmodCLP establece al menos 20 ms desde alimentación. El tiempo de configuración de FPGA puede añadir margen en la prueba física, pero esa contribución no está modelada en el periférico. El funcionamiento observado no demuestra por sí solo todos los márgenes eléctricos.

Una prueba del buzzer con duraciones reducidas y la misma FSM mostró que un pulso de fin durante un tono previo se pierde. Los valores utilizados fueron 20/30/40 ciclos de duración y 2/3/4 ciclos de semiperíodo para acierto/error/fin. La prioridad de eventos solo opera cuando el buzzer está en reposo.

El temporizador de S1 mantiene el estado final 3 s desde la decisión de fin. La señal `screen_done` no interviene en el inicio del contador, por lo que la duración del texto completo visible depende también del tiempo de actualización de la LCD.

## 4. Resultados experimentales

### 4.1. Inicialización y pantallas del LCD

### **EN PROCESO**

### 4.2. Displays y LED de estado

### **EN PROCESO**

### 4.3. Frecuencia y duración de los tonos

### **EN PROCESO**

### 4.4. Duración visible del resultado final

### **EN PROCESO**

## 5. Análisis y conclusión

La interfaz local reúne la presentación visual y sonora del juego en una jerarquía sintetizable. La separación entre periférico LCD y administrador de pantallas permite coordinar las escrituras mediante busy. Las pruebas dirigidas identifican límites en la preparación temporal de la LCD y en la atención de eventos sonoros durante un tono activo. La duración del resultado depende de la coordinación entre actualización de pantalla y temporizador de S1.

## Referencias

- [Diseño y FSM de interfaz local](../diseno/nivel_3_interfaz_local.md).
- [Manual PmodCLP de Digilent](https://digilent.com/reference/_media/pmod:pmod:pmodCLP_rm.pdf).
- [HD44780U, características temporales](https://www.sparkfun.com/datasheets/LCD/HD44780.pdf).
- [Registros de comprobaciones dirigidas](resultados/integracion/limites_verificacion.txt).
