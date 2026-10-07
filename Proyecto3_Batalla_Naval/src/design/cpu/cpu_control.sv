// FSM multiciclo: las habilitaciones dependen del estado actual y las validaciones.
// ROM y datos tienen lectura síncrona: solicitud y captura usan ciclos separados.
// Desde FETCH_REQ hasta COMMIT: ALU/JAL/JALR=6, branch=5, SW=6 y LW=8 ciclos.
module cpu_control (
    input logic clk_i, rst_i, legal_i, pc_valid_i, execute_valid_i,
    input logic [2:0] kind_i,
    output logic ir_en_o, operands_en_o, execute_en_o, load_en_o, pc_en_o, rf_we_o,
    output logic mem_access_o, store_o, fault_o
);
    import cpu_pkg::*;
    // state_q conserva el estado; state_d es el siguiente estado combinacional.
    state_t state_q, state_d;
    logic fault_q;
    // MEMORIA DE ESTADO: reset síncrono devuelve la FSM a FETCH_REQ.
    // La indicación de fallo queda retenida hasta reset; no hay recuperación
    // automática ni manejador de excepciones que retome la instrucción.
    always_ff @(posedge clk_i) begin
        if (rst_i) begin state_q<=FETCH_REQ; fault_q<=0; end
        else begin
            state_q<=state_d;
            if (state_d==FAULT) fault_q<=1;
        end
    end
    assign fault_o=fault_q;
    // TRANSICIONES Y SALIDAS: valores por defecto deshabilitan toda escritura
    // y evitan latches. Un enable alto permite capturar al terminar ese ciclo.
    always_comb begin
        state_d=state_q;
        ir_en_o=0; operands_en_o=0; execute_en_o=0; load_en_o=0;
        pc_en_o=0; rf_we_o=0; mem_access_o=0; store_o=0;
        case (state_q)
            // BÚSQUEDA, ciclo 1: el PC ya está en el bus de ROM. Al flanco
            // final la ROM registra su salida; un PC inválido conduce a FAULT.
            FETCH_REQ: begin
                if (pc_valid_i) state_d=FETCH_CAPTURE; else state_d=FAULT;
            end
            // BÚSQUEDA, ciclo 2: captura en IR la respuesta del ciclo anterior.
            // ROM e IR usan <=: el IR recibe la salida previa al mismo flanco.
            FETCH_CAPTURE: begin ir_en_o=1; state_d=DECODE; end
            // DECODIFICACIÓN: solo una instrucción admitida captura operandos
            // y selecciones. Una codificación ilegal no alcanza EXECUTE.
            DECODE: begin
                if (legal_i) begin operands_en_o=1; state_d=EXECUTE; end
                else state_d=FAULT;
            end
            EXECUTE: begin
                // EJECUCIÓN: ALU calcula resultado/dirección; datapath calcula
                // próximo PC y enlace. Se capturan sus registros internos.
                // Si falla la validación, no se alcanza STORE, WRITEBACK ni
                // COMMIT: memoria, banco y PC no reciben esos resultados.
                // execute_en no depende de la salida combinacional de ALU:
                // evita llevar la validación del destino a todos sus enables.
                execute_en_o=1;
                if (!execute_valid_i) state_d=FAULT;
                else begin
                    case (kind_i)
                        // LW necesita leer y conservar datos antes de escribir rd.
                        K_LOAD: state_d=LOAD_REQ;
                        // SW escribe memoria; branch solo actualiza el PC.
                        K_STORE: state_d=STORE;
                        K_BRANCH: state_d=COMMIT;
                        K_ALU, K_JAL, K_JALR: state_d=WRITEBACK;
                        default: state_d=FAULT;
                    endcase
                end
            end
            // CARGA, solicitud: dirección estable; el destino registra su dato
            // al flanco final. No se captura todavía en load_data_q.
            LOAD_REQ: begin mem_access_o=1; state_d=LOAD_CAPTURE; end
            // CARGA, captura: mantiene dirección y conserva DataIn en datapath.
            // Después WRITEBACK transfiere ese registro al rd de la instrucción.
            LOAD_CAPTURE: begin mem_access_o=1; load_en_o=1; state_d=WRITEBACK; end
            // ALMACENAMIENTO: dirección calculada y rs2 salen al bus con we=1.
            // El destino escribe al flanco; SW no modifica el banco de registros.
            STORE: begin mem_access_o=1; store_o=1; state_d=COMMIT; end
            // RETORNO: escribe rd con ALU, dato cargado o enlace, según decoder.
            WRITEBACK: begin rf_we_o=1; state_d=COMMIT; end
            // FINALIZACIÓN: actualiza PC con el destino conservado en EXECUTE.
            // Solo después se permite comenzar la búsqueda de otra instrucción.
            COMMIT: begin pc_en_o=1; state_d=FETCH_REQ; end
            // Estado absorbente: habilitaciones permanecen en cero hasta reset.
            FAULT: state_d=FAULT;
            default: state_d=FAULT;
        endcase
        // Aunque el estado se reinicia al flanco, las habilitaciones se inhiben
        // combinacionalmente al activar reset; evita escribir durante un STORE
        // interrumpido. fault_q también mantiene desactivados los efectos.
        if (rst_i || fault_q) begin
            ir_en_o=0; operands_en_o=0; execute_en_o=0; load_en_o=0;
            pc_en_o=0; rf_we_o=0; mem_access_o=0; store_o=0;
        end
    end
endmodule
