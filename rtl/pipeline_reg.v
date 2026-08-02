`default_nettype none

module pipeline_reg #(
    parameter PAYLOAD_W = 1
) (
    input  wire                 clk,
    input  wire                 rst,
    input  wire                 flush,
    input  wire                 hold,
    input  wire                 in_valid,
    input  wire [PAYLOAD_W-1:0] in_payload,
    output reg                  out_valid,
    output reg  [PAYLOAD_W-1:0] out_payload
);
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            out_valid   <= 1'b0;
            out_payload <= {PAYLOAD_W{1'b0}};
        end else if (flush) begin
            out_valid   <= 1'b0;
            out_payload <= {PAYLOAD_W{1'b0}};
        end else if (!hold) begin
            out_valid   <= in_valid;
            out_payload <= in_payload;
        end
    end
endmodule

`default_nettype wire
