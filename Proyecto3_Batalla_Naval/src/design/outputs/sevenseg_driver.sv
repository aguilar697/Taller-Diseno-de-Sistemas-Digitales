// Conversion decimal y multiplexado activo en bajo para Basys 3.
module sevenseg_driver #(
    parameter int unsigned CLK_FREQ_HZ = 100_000_000,
    parameter int unsigned FRAME_REFRESH_HZ = 1_000
)(
    input  logic       clk_i,
    input  logic       rst_i,
    input  logic [7:0] j1_wins_i,
    input  logic [7:0] j2_wins_i,
    output logic [6:0] seg_o,
    output logic [3:0] an_o
);
    localparam int unsigned RAW_DIGIT_CYCLES = CLK_FREQ_HZ/(FRAME_REFRESH_HZ*4);
    localparam int unsigned DIGIT_CYCLES = (RAW_DIGIT_CYCLES<1) ? 1 : RAW_DIGIT_CYCLES;
    localparam int unsigned COUNT_WIDTH = (DIGIT_CYCLES<=1) ? 1 : $clog2(DIGIT_CYCLES);

    logic [COUNT_WIDTH-1:0] scan_count;
    logic [1:0] digit_select;
    logic [3:0] active_digit;
    logic [7:0] j1_value,j2_value;
    logic [3:0] j1_tens,j1_units,j2_tens,j2_units;

    // Los registros contienen enteros binarios. La salida se limita a 99.
    always_comb begin
        j1_value = (j1_wins_i > 8'd99) ? 8'd99 : j1_wins_i;
        j2_value = (j2_wins_i > 8'd99) ? 8'd99 : j2_wins_i;
        j1_tens  = j1_value / 8'd10;
        j1_units = j1_value % 8'd10;
        j2_tens  = j2_value / 8'd10;
        j2_units = j2_value % 8'd10;
    end

    always_ff @(posedge clk_i) begin
        if(rst_i)begin
            scan_count<='0;
            digit_select<=2'd0;
        end else if(scan_count==DIGIT_CYCLES-1)begin
            scan_count<='0;
            digit_select<=digit_select+1'b1;
        end else scan_count<=scan_count+1'b1;
    end

    always_comb begin
        case(digit_select)
            2'd0:begin an_o=4'b1110;active_digit=j2_units;end
            2'd1:begin an_o=4'b1101;active_digit=j2_tens;end
            2'd2:begin an_o=4'b1011;active_digit=j1_units;end
            2'd3:begin an_o=4'b0111;active_digit=j1_tens;end
            default:begin an_o=4'b1111;active_digit=4'd0;end
        endcase

        case(active_digit)
            4'd0:seg_o=7'b1000000;
            4'd1:seg_o=7'b1111001;
            4'd2:seg_o=7'b0100100;
            4'd3:seg_o=7'b0110000;
            4'd4:seg_o=7'b0011001;
            4'd5:seg_o=7'b0010010;
            4'd6:seg_o=7'b0000010;
            4'd7:seg_o=7'b1111000;
            4'd8:seg_o=7'b0000000;
            4'd9:seg_o=7'b0010000;
            default:seg_o=7'b1111111;
        endcase
    end
endmodule
