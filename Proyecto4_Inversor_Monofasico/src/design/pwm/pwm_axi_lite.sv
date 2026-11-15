`timescale 1ns / 1ps
// Esclavo de una transacción pendiente por sentido. AW y W se aceptan por separado.
module pwm_axi_lite #(
    parameter integer ADDR_WIDTH = 6,
    parameter integer MOD_LIMIT_Q15 = 27853,
    parameter integer MIN_ON_CYCLES = 100
)(
    input  logic s_axi_aclk, s_axi_aresetn,
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
    input  logic running_i,
    output logic enable_o,
    output logic [1:0] freq_sel_o,
    output logic signed [15:0] reference_o,
    output logic [31:0] deadtime_o, trigger_phase_o
);
    localparam logic [1:0] OKAY = 2'b00, SLVERR = 2'b10;
    logic aw_full, w_full, enable_q;
    logic [ADDR_WIDTH-1:0] address_q;
    logic [31:0] data_q, merged_control, merged_reference, merged_deadtime, merged_phase;
    logic [3:0] strobe_q;
    logic execute_write, accept_write, disable_now;

    generate
        if (ADDR_WIDTH < 4 || MOD_LIMIT_Q15 < 1 || MOD_LIMIT_Q15 > 32767 ||
            MIN_ON_CYCLES < 1) begin : g_invalid_parameters
            PWM_PARAMETERS_MUST_BE_VALID invalid_parameters();
        end
    endgenerate

    function automatic logic [31:0] merge_bytes(input logic [31:0] previous,
        input logic [31:0] incoming, input logic [3:0] strobes);
        integer j;
        begin
            merge_bytes = previous;
            for (j=0; j<4; j=j+1)
                if (strobes[j]) merge_bytes[j*8 +: 8] = incoming[j*8 +: 8];
        end
    endfunction

    function automatic logic signed [15:0] saturate(input logic signed [15:0] value);
        begin
            if ($signed(value) > MOD_LIMIT_Q15) saturate = 16'(MOD_LIMIT_Q15);
            else if ($signed(value) < -MOD_LIMIT_Q15) saturate = 16'(-MOD_LIMIT_Q15);
            else saturate = value;
        end
    endfunction

    function automatic logic config_valid(input logic [1:0] frequency,
        input logic [31:0] delay_cycles, input logic [31:0] phase);
        integer n, h_min, width_min;
        begin
            case (frequency)
                0: begin n=5000; h_min=2500-(5000*MOD_LIMIT_Q15+32768)/65536; end
                1: begin n=2500; h_min=1250-(2500*MOD_LIMIT_Q15+32768)/65536; end
                2: begin n=2000; h_min=1000-(2000*MOD_LIMIT_Q15+32768)/65536; end
                default: begin n=0; h_min=0; end
            endcase
            // Cada ancho se resuelve como constante de elaboración; no hace
            // falta un multiplicador en el camino de validación de CONTROL.
            width_min = 2*h_min;
            // La resta evita que D + MIN_ON se desborde con escrituras de 32 bits.
            config_valid = n > 0 && phase < 2*n && delay_cycles >= 1 &&
                delay_cycles <= width_min &&
                MIN_ON_CYCLES <= (32'(width_min)-delay_cycles);
        end
    endfunction

    assign s_axi_awready = s_axi_aresetn && !aw_full && !s_axi_bvalid;
    assign s_axi_wready = s_axi_aresetn && !w_full && !s_axi_bvalid;
    assign s_axi_arready = s_axi_aresetn && !s_axi_rvalid;
    assign execute_write = aw_full && w_full && !s_axi_bvalid;
    // El apagado llega al núcleo en el mismo flanco que ejecuta CONTROL=0.
    assign disable_now = execute_write && address_q == 0 && strobe_q[0] && !data_q[0];
    assign enable_o = enable_q && !disable_now;

    always_comb begin
        merged_control = merge_bytes({29'b0,freq_sel_o,enable_q}, data_q, strobe_q);
        merged_reference = merge_bytes({16'b0,reference_o}, data_q, strobe_q);
        merged_deadtime = merge_bytes(deadtime_o, data_q, strobe_q);
        merged_phase = merge_bytes(trigger_phase_o, data_q, strobe_q);
        accept_write = 0;
        case (address_q)
            'h00: begin
                if (!strobe_q[0]) accept_write = 1;
                else if (enable_q && !merged_control[0]) accept_write = 1;
                else if (merged_control[2:1] != 2'b11) begin
                    if (enable_q) accept_write = merged_control[2:1] == freq_sel_o;
                    else accept_write = !merged_control[0] ||
                        config_valid(merged_control[2:1],deadtime_o,trigger_phase_o);
                end
            end
            'h04: accept_write = 1;
            'h08, 'h0c: accept_write = !enable_q || strobe_q == 0;
            default: accept_write = 0;
        endcase
    end

    always_ff @(posedge s_axi_aclk or negedge s_axi_aresetn) begin
        if (!s_axi_aresetn) begin
            aw_full <= 0; w_full <= 0; address_q <= 0; data_q <= 0; strobe_q <= 0;
            s_axi_bvalid <= 0; s_axi_bresp <= OKAY;
            enable_q <= 0; freq_sel_o <= 0; reference_o <= 0;
            deadtime_o <= 0; trigger_phase_o <= 0;
        end else begin
            if (s_axi_bvalid && s_axi_bready) s_axi_bvalid <= 0;
            if (s_axi_awvalid && s_axi_awready) begin
                address_q <= s_axi_awaddr;
                aw_full <= 1;
            end
            if (s_axi_wvalid && s_axi_wready) begin
                data_q <= s_axi_wdata; strobe_q <= s_axi_wstrb;
                w_full <= 1;
            end
            if (execute_write) begin
                aw_full <= 0; w_full <= 0;
                s_axi_bvalid <= 1;
                s_axi_bresp <= accept_write ? OKAY : SLVERR;
                if (accept_write) begin
                    case (address_q)
                        'h00: if (strobe_q[0]) begin
                            enable_q <= merged_control[0];
                            if (!enable_q) freq_sel_o <= merged_control[2:1];
                        end
                        'h04: reference_o <= saturate($signed(merged_reference[15:0]));
                        'h08: deadtime_o <= merged_deadtime;
                        'h0c: trigger_phase_o <= merged_phase;
                        default: begin end
                    endcase
                end
            end
        end
    end

    always_ff @(posedge s_axi_aclk or negedge s_axi_aresetn) begin
        if (!s_axi_aresetn) begin
            s_axi_rvalid <= 0; s_axi_rdata <= 0; s_axi_rresp <= OKAY;
        end else begin
            if (s_axi_rvalid && s_axi_rready) s_axi_rvalid <= 0;
            if (s_axi_arvalid && s_axi_arready) begin
                s_axi_rvalid <= 1; s_axi_rresp <= OKAY;
                case (s_axi_araddr)
                    'h00: s_axi_rdata <= {28'b0,running_i,freq_sel_o,enable_q};
                    'h04: s_axi_rdata <= {16'b0,reference_o};
                    'h08: s_axi_rdata <= deadtime_o;
                    'h0c: s_axi_rdata <= trigger_phase_o;
                    default: begin s_axi_rdata <= 0; s_axi_rresp <= SLVERR; end
                endcase
            end
        end
    end
endmodule
