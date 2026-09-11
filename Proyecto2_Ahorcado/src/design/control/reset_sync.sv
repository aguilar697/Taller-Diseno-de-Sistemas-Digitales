module reset_sync (
    input  logic clk_i,
    input  logic btn_rst_i,
    output logic rst_sync
);

    (* ASYNC_REG = "TRUE" *)
    logic [1:0] sync_ff;

    always_ff @(posedge clk_i or posedge btn_rst_i) begin
        if (btn_rst_i) begin
            sync_ff <= 2'b11;
        end else begin
            sync_ff <= {sync_ff[0], 1'b0};
        end
    end

    assign rst_sync = sync_ff[1];

endmodule