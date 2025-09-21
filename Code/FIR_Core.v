module FIR_Core (
    input clk,
    input RstN,
    input Wait,
    input Write,                      
    input [7:0] X,                   
    input [7:0] H0, H1, H2, H3, H4, H5, H6, H7, 
    output [23:0] Yn                                  
);
    reg [7:0] Xn [0:7]; 
    reg [23:0] yn;
    assign Yn = yn;
    always @(posedge clk or negedge RstN) begin
        if (!RstN) begin
		Xn[0] <= 8'b0; Xn[1] <= 8'b0; 
		Xn[2] <= 8'b0; Xn[3] <= 8'b0; 
		Xn[4] <= 8'b0; Xn[5] <= 8'b0; 
		Xn[6] <= 8'b0; Xn[7] <= 8'b0; 
		yn <= 24'b0;         
        end else if (~Wait) begin
		Xn[0] = X; 
		yn = Xn[0] * H7 + Xn[1] * H6 + Xn[2] * H5 +
		Xn[3] * H4 + Xn[4] * H3 + Xn[5] * H2 +
		Xn[6] * H1 + Xn[7] * H0;
		if(Write) begin
		Xn[7] = Xn[6]; 
		Xn[6] = Xn[5]; 
		Xn[5] = Xn[4]; 
		Xn[4] = Xn[3]; 
		Xn[3] = Xn[2]; 
		Xn[2] = Xn[1]; 
		Xn[1] = Xn[0];  
		end        
	end else begin
		yn <= 24'b0;
		end
	end
endmodule
