`timescale 1ns / 1ps
// Esclavo AXI4-Lite de adquisición: captura AW/W independientes y respuestas estables.
// Mapa en bytes: CONTROL00, STATUS04, SAMPLE08, ERROR0C y ACK_ID 10.
module adc_axi_lite #(
    parameter int ADDR_WIDTH = 6 // Mínimo 5 para representar ACK_ID en 0x10.
)(
    input  logic s_axi_aclk,
    input  logic s_axi_aresetn,
    input  logic [ADDR_WIDTH-1:0] s_axi_awaddr,
    input  logic [2:0] s_axi_awprot,
    input  logic s_axi_awvalid,
    output logic s_axi_awready,
    input  logic [31:0] s_axi_wdata,
    input  logic [3:0] s_axi_wstrb,
    input  logic s_axi_wvalid,
    output logic s_axi_wready,
    output logic [1:0] s_axi_bresp,
    output logic s_axi_bvalid,
    input  logic s_axi_bready,
    input  logic [ADDR_WIDTH-1:0] s_axi_araddr,
    input  logic [2:0] s_axi_arprot,
    input  logic s_axi_arvalid,
    output logic s_axi_arready,
    output logic [31:0] s_axi_rdata,
    output logic [1:0] s_axi_rresp,
    output logic s_axi_rvalid,
    input  logic s_axi_rready,
    input  logic [31:0] sample_i,
    input  logic [31:0] sample_token_i, // Token que se captura junto con la lectura SAMPLE.
    input  logic busy_i, valid_i, new_data_i, xadc_busy_i,
    input  logic missed_trigger_i, overrun_i, timeout_i,
    output logic start_sw_o,
    output logic ack_sample_o,
    output logic [31:0] ack_id_o
);
    localparam logic [1:0] OKAY = 2'b00, SLVERR = 2'b10;
    logic aw_full, w_full;
    logic [ADDR_WIDTH-1:0] awaddr;
    logic [31:0] wdata;
    logic [3:0] wstrb;
    logic [31:0] read_sample_token; // Instantánea asociada a la última lectura SAMPLE.

    // Parámetro inválido falla en elaboración, sin lógica de simulación en RTL.
    generate
        if (ADDR_WIDTH < 5) begin : g_bad_address_width
            ADC_AXI_ADDR_WIDTH_MUST_BE_AT_LEAST_5 invalid_parameter();
        end
    endgenerate

    // Capacidad de una operación pendiente por sentido; se permite insertar burbujas.
    assign s_axi_awready = s_axi_aresetn && !aw_full && !s_axi_bvalid;
    assign s_axi_wready  = s_axi_aresetn && !w_full && !s_axi_bvalid;
    assign s_axi_arready = s_axi_aresetn && !s_axi_rvalid;

    always_ff @(posedge s_axi_aclk or negedge s_axi_aresetn) begin
        if (!s_axi_aresetn) begin
            aw_full <= 1'b0; w_full <= 1'b0;
            awaddr <= '0; wdata <= '0; wstrb <= '0;
            s_axi_bvalid <= 1'b0; s_axi_bresp <= OKAY;
            start_sw_o <= 1'b0; ack_sample_o <= 1'b0; ack_id_o <= 0;
        end else begin
            start_sw_o <= 1'b0;
            ack_sample_o <= 1'b0;
            if (s_axi_bvalid && s_axi_bready)
                s_axi_bvalid <= 1'b0;
            if (s_axi_awvalid && s_axi_awready) begin
                awaddr <= s_axi_awaddr;
                aw_full <= 1'b1;
            end
            if (s_axi_wvalid && s_axi_wready) begin
                wdata <= s_axi_wdata;
                wstrb <= s_axi_wstrb;
                w_full <= 1'b1;
            end
            // Se ejecuta una vez con ambas capturas, nunca por VALID aislado.
            if (aw_full && w_full && !s_axi_bvalid) begin
                aw_full <= 1'b0;
                w_full <= 1'b0;
                s_axi_bvalid <= 1'b1;
                s_axi_bresp <= SLVERR;
                case (awaddr)
                    'h00: begin
                        // El bit1 antiguo no identifica muestra: rechazo completo sin START.
                        if (wstrb[0] && wdata[1]) s_axi_bresp <= SLVERR;
                        else begin
                            s_axi_bresp <= OKAY;
                            if (wstrb[0]) start_sw_o <= wdata[0];
                        end
                    end
                    'h10: begin
                        // Un token no se ensambla con bytes de transacciones distintas.
                        if (wstrb == 0) s_axi_bresp <= OKAY;
                        else if (wstrb == 4'b1111 && wdata != 0) begin
                            s_axi_bresp <= OKAY;
                            ack_id_o <= wdata;
                            ack_sample_o <= 1'b1;
                        end
                    end
                    default: begin end // RO, reservado o no alineado: sin acciones.
                endcase
            end
        end
    end

    always_ff @(posedge s_axi_aclk or negedge s_axi_aresetn) begin
        if (!s_axi_aresetn) begin
            s_axi_rvalid <= 1'b0;
            s_axi_rresp <= OKAY;
            s_axi_rdata <= '0;
            read_sample_token <= 0;
        end else begin
            if (s_axi_rvalid && s_axi_rready)
                s_axi_rvalid <= 1'b0;
            if (s_axi_arvalid && s_axi_arready) begin
                s_axi_rvalid <= 1'b1;
                s_axi_rresp <= OKAY;
                // Instantánea al handshake AR: independiente de conversiones posteriores.
                case (s_axi_araddr)
                    'h00: s_axi_rdata <= 32'b0;
                    'h04: s_axi_rdata <= {25'b0, timeout_i, overrun_i,
                        missed_trigger_i, xadc_busy_i, busy_i, new_data_i, valid_i};
                    'h08: begin
                        // Muestra y token se capturan en el mismo flanco, incluso si publica DRDY.
                        s_axi_rdata <= sample_i;
                        read_sample_token <= sample_token_i;
                    end
                    'h10: s_axi_rdata <= read_sample_token;
                    'h0c: s_axi_rdata <= {29'b0, timeout_i, overrun_i, missed_trigger_i};
                    default: begin
                        s_axi_rdata <= 32'b0;
                        s_axi_rresp <= SLVERR;
                    end
                endcase
            end
        end
    end
    // AWPROT/ARPROT se aceptan sin diferenciación de privilegios en este contrato local.
endmodule
