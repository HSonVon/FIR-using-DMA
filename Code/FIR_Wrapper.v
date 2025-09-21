module FIR_Wrapper (
    input wire clk,
    input wire RstN,                  
    input wire ChipSelect,       
    input wire [31:0] WriteData,
    input wire [1:0] Address,
    input wire Write,                  
    input wire Read,  	 
    output wire [31:0] ReadData       

);
    wire [7:0] H0, H1, H2, H3, H4, H5, H6, H7, X;
    wire [23:0] Yn;
    wire Wait;
    FIR_Csr csr (
        .clk(clk),
        .RstN(RstN),                   
        .ChipSelect(ChipSelect), 
        .WriteData(WriteData),
        .Address(Address),
        .Write(Write),                
        .Read(Read),   
		  .Yn(Yn),
		  .X(X),
		  .Wait(Wait),
        .H0(H0), .H1(H1), .H2(H2), .H3(H3),
        .H4(H4), .H5(H5), .H6(H6), .H7(H7),
        .ReadData(ReadData)          
    );

    FIR_Core core (
        .clk(clk),
        .RstN(RstN),                 
        .Wait(Wait),
		  .Write(Write),         
        .X(X),                      
        .H0(H0), .H1(H1), .H2(H2), .H3(H3),
        .H4(H4), .H5(H5), .H6(H6), .H7(H7),
        .Yn(Yn)           
    );
endmodule
