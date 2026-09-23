// FSM multiciclo: la memoria inicia una lectura y el CPU captura en el flanco siguiente.
module cpu_control (
    input logic clk_i, rst_i, legal_i, pc_valid_i, execute_valid_i,
    input logic [2:0] kind_i,
    output logic ir_en_o, operands_en_o, execute_en_o, load_en_o, pc_en_o, rf_we_o,
    output logic mem_access_o, store_o, fault_o
);
    import cpu_pkg::*;
    state_t state_q, state_d;
    logic fault_q;
    always_ff @(posedge clk_i) begin
        if (rst_i) begin state_q<=FETCH_REQ; fault_q<=0; end
        else begin
            state_q<=state_d;
            if (state_d==FAULT) fault_q<=1;
        end
    end
    assign fault_o=fault_q;
    always_comb begin
        state_d=state_q;
        ir_en_o=0; operands_en_o=0; execute_en_o=0; load_en_o=0;
        pc_en_o=0; rf_we_o=0; mem_access_o=0; store_o=0;
        case (state_q)
            FETCH_REQ: begin
                if (pc_valid_i) state_d=FETCH_CAPTURE; else state_d=FAULT;
            end
            FETCH_CAPTURE: begin ir_en_o=1; state_d=DECODE; end
            DECODE: begin
                if (legal_i) begin operands_en_o=1; state_d=EXECUTE; end
                else state_d=FAULT;
            end
            EXECUTE: begin
                if (!execute_valid_i) state_d=FAULT;
                else begin
                    execute_en_o=1;
                    case (kind_i)
                        K_LOAD: state_d=LOAD_REQ;
                        K_STORE: state_d=STORE;
                        K_BRANCH: state_d=COMMIT;
                        K_ALU, K_JAL, K_JALR: state_d=WRITEBACK;
                        default: begin execute_en_o=0; state_d=FAULT; end
                    endcase
                end
            end
            LOAD_REQ: begin mem_access_o=1; state_d=LOAD_CAPTURE; end
            LOAD_CAPTURE: begin mem_access_o=1; load_en_o=1; state_d=WRITEBACK; end
            STORE: begin mem_access_o=1; store_o=1; state_d=COMMIT; end
            WRITEBACK: begin rf_we_o=1; state_d=COMMIT; end
            COMMIT: begin pc_en_o=1; state_d=FETCH_REQ; end
            FAULT: state_d=FAULT;
            default: state_d=FAULT;
        endcase
        // Inhibe efectos antes del flanco de reset, incluso si se interrumpe STORE.
        if (rst_i || fault_q) begin
            ir_en_o=0; operands_en_o=0; execute_en_o=0; load_en_o=0;
            pc_en_o=0; rf_we_o=0; mem_access_o=0; store_o=0;
        end
    end
endmodule
