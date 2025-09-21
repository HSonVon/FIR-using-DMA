module RisiEdgeDectector (
	input   logic  clk,
	input   logic  rstn,
	input   logic  sign,
	output  logic  trigger
);

logic sign_dl;

assign trigger = ~sign_dl & sign;

always_ff @(posedge clk, negedge rstn) begin
	if (~rstn)
		sign_dl <= 1'b0;
	else
		sign_dl <= sign;
end


endmodule