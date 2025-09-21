module FIR_Csr (
    input clk,
    input RstN,                  
    input ChipSelect,       
    input [31:0] WriteData,
    input [1:0] Address,
    input Write,                  
    input Read,  
    input [23:0] Yn, 
    output reg [7:0] X,
    output reg Wait,
    output reg [7:0] H0, H1, H2, H3, H4, H5, H6, H7,
    output [31:0] ReadData                   
);
    reg [31:0] Data ;
    assign ReadData = Data;
    always @(posedge clk or negedge RstN) begin
        if (!RstN) begin
            H0 <= 8'b0; H1 <= 8'b0; 
            H2 <= 8'b0; H3 <= 8'b0; 
            H4 <= 8'b0; H5 <= 8'b0; 
            H6 <= 8'b0; H7 <= 8'b0; 
            Data <= 32'b0; 
            Wait <= 1'b1;        
        end else if (ChipSelect) begin
            if (Write) begin
                case (Address)
                    2'b00: begin
                        Wait <= 1'b1 ;
                        H0 <= WriteData[7:0];
                        H1 <= WriteData[15:8];
                        H2 <= WriteData[23:16];
                        H3 <= WriteData[31:24];
                    end
                    2'b01: begin
                        Wait <= 1'b1 ;
                        H4 <= WriteData[7:0];
                        H5 <= WriteData[15:8];
                        H6 <= WriteData[23:16];
                        H7 <= WriteData[31:24];
                    end
                    2'b10: begin
                        Wait <= 1'b0 ;
                        X <= WriteData[7:0];
                    end
                endcase
            end 
	if (Read) begin
                Data <= {8'b0, Yn}; 
	end
        end 
  end
endmodule