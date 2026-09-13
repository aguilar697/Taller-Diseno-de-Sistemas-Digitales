`timescale 1ns/1ps
module lcd_peripheral (
    input  logic        clk_i,
    input  logic        rst_i,
    input  logic        write_enable_i,
    input  logic [1:0]  addr_i,
    input  logic [31:0] wdata_i,
    output logic [31:0] rdata_o,
    output logic [7:0]  lcd_db,
    output logic        lcd_rs,
    output logic        lcd_rw,
    output logic        lcd_e
);

  localparam int unsigned POWERON_WAIT_CYCLES = 1_500_000;
  localparam int unsigned PULSE_WIDTH_CYCLES  = 50;
  localparam int unsigned EXEC_NORMAL_CYCLES  = 4_000;
  localparam int unsigned EXEC_LONG_CYCLES    = 152_000;
  localparam int unsigned NUM_INIT_STEPS      = 8;
  localparam int unsigned MAX_WAIT_CYCLES     = 410_000;

  localparam int POWERON_CNT_W = $clog2(POWERON_WAIT_CYCLES + 1);
  localparam int PULSE_CNT_W   = $clog2(PULSE_WIDTH_CYCLES + 1);
  localparam int WAIT_CNT_W    = $clog2(MAX_WAIT_CYCLES + 1);

  function automatic logic [7:0] init_cmd_lut(input logic [2:0] idx);
    case (idx)
      3'd0:    init_cmd_lut = 8'h30;
      3'd1:    init_cmd_lut = 8'h30;
      3'd2:    init_cmd_lut = 8'h30;
      3'd3:    init_cmd_lut = 8'h38;
      3'd4:    init_cmd_lut = 8'h08;
      3'd5:    init_cmd_lut = 8'h01;
      3'd6:    init_cmd_lut = 8'h06;
      3'd7:    init_cmd_lut = 8'h0C;
      default: init_cmd_lut = 8'h00;
    endcase
  endfunction

  function automatic logic [31:0] init_wait_lut(input logic [2:0] idx);
    case (idx)
      3'd0:    init_wait_lut = 32'd410_000;
      3'd1:    init_wait_lut = 32'd10_000;
      3'd2:    init_wait_lut = 32'd4_000;
      3'd3:    init_wait_lut = 32'd4_000;
      3'd4:    init_wait_lut = 32'd4_000;
      3'd5:    init_wait_lut = 32'd152_000;
      3'd6:    init_wait_lut = 32'd4_000;
      3'd7:    init_wait_lut = 32'd4_000;
      default: init_wait_lut = 32'd4_000;
    endcase
  endfunction

  typedef enum logic [2:0] {
    S_POWERON_WAIT,
    S_LATCH,
    S_PULSE,
    S_EXEC_WAIT,
    S_DONE,
    S_IDLE
  } lcd_state_e;

  lcd_state_e state;

  logic       rs_cfg;
  logic [7:0] data_reg;

  always_ff @(posedge clk_i) begin
    if (rst_i) begin
      rs_cfg   <= 1'b0;
      data_reg <= 8'h00;
    end else if (write_enable_i) begin
      unique case (addr_i)
        2'b00:   rs_cfg   <= wdata_i[1];
        2'b01:   data_reg <= wdata_i[7:0];
        default: ;
      endcase
    end
  end

  logic start_w1p, clear_w1p, home_w1p;
  assign start_w1p = write_enable_i && (addr_i == 2'b00) && wdata_i[0];
  assign clear_w1p = write_enable_i && (addr_i == 2'b00) && wdata_i[2];
  assign home_w1p  = write_enable_i && (addr_i == 2'b00) && wdata_i[3];

  logic [POWERON_CNT_W-1:0] poweron_cnt;
  logic [PULSE_CNT_W-1:0]   pulse_cnt;
  logic [WAIT_CNT_W-1:0]    wait_cnt;
  logic [2:0]               init_idx;
  logic                     initializing;
  logic                     long_exec;

  logic [7:0] db_reg;
  logic       rs_out_reg;
  logic       e_reg;

  logic [WAIT_CNT_W-1:0] wait_target;

  always_comb begin
    if (initializing)
      wait_target = WAIT_CNT_W'(init_wait_lut(init_idx));
    else if (long_exec)
      wait_target = WAIT_CNT_W'(EXEC_LONG_CYCLES);
    else
      wait_target = WAIT_CNT_W'(EXEC_NORMAL_CYCLES);
  end

  always_ff @(posedge clk_i) begin
    if (rst_i) begin
      state        <= S_POWERON_WAIT;
      poweron_cnt  <= '0;
      pulse_cnt    <= '0;
      wait_cnt     <= '0;
      init_idx     <= '0;
      initializing <= 1'b1;
      long_exec    <= 1'b0;
      db_reg       <= 8'h00;
      rs_out_reg   <= 1'b0;
      e_reg        <= 1'b0;
    end else begin
      unique case (state)

        S_POWERON_WAIT: begin
          e_reg <= 1'b0;
          if (poweron_cnt >= POWERON_CNT_W'(POWERON_WAIT_CYCLES - 1)) begin
            poweron_cnt <= '0;
            db_reg      <= init_cmd_lut(3'd0);
            rs_out_reg  <= 1'b0;
            state       <= S_LATCH;
          end else begin
            poweron_cnt <= poweron_cnt + 1'b1;
          end
        end

        S_LATCH: begin
          pulse_cnt <= '0;
          e_reg     <= 1'b1;
          state     <= S_PULSE;
        end

        S_PULSE: begin
          if (pulse_cnt >= PULSE_CNT_W'(PULSE_WIDTH_CYCLES - 1)) begin
            e_reg     <= 1'b0;
            pulse_cnt <= '0;
            wait_cnt  <= '0;
            state     <= S_EXEC_WAIT;
          end else begin
            pulse_cnt <= pulse_cnt + 1'b1;
          end
        end

        S_EXEC_WAIT: begin
          if (wait_cnt >= wait_target - 1'b1) begin
            wait_cnt <= '0;
            if (initializing) begin
              if (init_idx == 3'(NUM_INIT_STEPS - 1)) begin
                initializing <= 1'b0;
                state        <= S_IDLE;
              end else begin
                init_idx   <= init_idx + 1'b1;
                db_reg     <= init_cmd_lut(init_idx + 1'b1);
                rs_out_reg <= 1'b0;
                state      <= S_LATCH;
              end
            end else begin
              state <= S_DONE;
            end
          end else begin
            wait_cnt <= wait_cnt + 1'b1;
          end
        end

        S_DONE: begin
          state <= S_IDLE;
        end

        S_IDLE: begin
          long_exec <= 1'b0;
          if (clear_w1p) begin
            db_reg     <= 8'h01;
            rs_out_reg <= 1'b0;
            long_exec  <= 1'b1;
            state      <= S_LATCH;
          end else if (home_w1p) begin
            db_reg     <= 8'h02;
            rs_out_reg <= 1'b0;
            long_exec  <= 1'b1;
            state      <= S_LATCH;
          end else if (start_w1p) begin
            db_reg     <= data_reg;
            // Se usa wdata_i[1] directamente, no rs_cfg: rs y start llegan
            // juntos en la misma escritura, y rs_cfg solo se actualizaria
            // un ciclo despues (quedaria desfasado un caracter).
            rs_out_reg <= wdata_i[1];
            long_exec  <= 1'b0;
            state      <= S_LATCH;
          end
        end

        default: state <= S_POWERON_WAIT;

      endcase
    end
  end

  logic busy_int, done_int;
  assign busy_int = (state != S_IDLE);
  assign done_int = (state == S_DONE);

  assign lcd_db = db_reg;
  assign lcd_rs = rs_out_reg;
  assign lcd_rw = 1'b0;
  assign lcd_e  = e_reg;

  always_comb begin
    unique case (addr_i)
      2'b00:   rdata_o = {22'b0, done_int, busy_int, 6'b0, rs_cfg, 1'b0};
      2'b01:   rdata_o = {24'b0, data_reg};
      default: rdata_o = 32'h0000_0000;
    endcase
  end

endmodule
