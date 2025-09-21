module DMA_FIR_core (
    // Global signals
    input  logic         iClk,
    input  logic         iRstn,

    // Configuration
    input  logic         iChipSelect_Control,
    input  logic         iWrite_Control,
    input  logic         iRead_Control,
    input  logic [2:0]   iAddress_Control,
    input  logic [31:0]  iData_Control,
    output logic [31:0]  oData_Control,

    // Master Read
    output logic [31:0]  oAddress_Master_Read,
    output logic         oRead_Master_Read,
    input  logic         iDataValid_Master_Read,
    input  logic         iWait_Master_Read,
    input  logic [31:0]  iReadData_Master_Read,

    // Master Write
    output logic [31:0]  oAddress_Master_Write,
    output logic [31:0]  oData_Master_Write,
    output logic         oWrite_Master_Write,
    input  logic         iWait_Master_Write
);

/*****************************************************************************
 *                 Internal Wires and Registers Declarations                 *
 *****************************************************************************/

// Control & Status Registers
logic [31:0] control, inital, length, read_start_address, write_start_address;
logic [31:0] status;

// Read Master
logic         start, master_read_done, address_read_fetch, address_read_incr;
logic [31:0]  address_read, end_address_read;

// Write Master
logic         master_write_done, address_write_fetch, address_write_incr;
logic [31:0]  address_write, end_address_write;

// FIFO Signals
logic         fifoi_clear, fifoi_read, fifoi_write, fifoi_full, fifoi_empty;
logic [31:0]  fifoi_out_data, fifoi_in_data;
logic         fifoo_clear, fifoo_read, fifoo_write, fifoo_full, fifoo_empty;
logic [31:0]  fifoo_in_data;// fifoo_out_data;
logic [7:0]   number_word_usedi, number_word_usedo;

// FIR Signals
logic [1:0]   fir_add;
logic [31:0]  fir_data;
logic         fir_wr, fir_select;

// Control Signals
logic         start_trigger, done_trigger, dma_done;

// State Machines
enum {r_idle, r_request, r_fifo_write, r_incr} r_cs, r_ns;
enum {w_idle, w_fifo_read, w_request, w_incr} w_cs, w_ns;

/*****************************************************************************
 *                              Assignments                                  *
 *****************************************************************************/
assign fifoi_clear = control[1];
assign fifoo_clear = control[4];
assign fir_add     = control[9:8];
assign fir_data    = (fir_add == 2'b10) ? fifoi_out_data : inital ;
assign fir_select = iChipSelect_Control | !dma_done;
assign fir_wr = fifoi_read | (iWrite_Control & (fir_add == 2'b00 | fir_add == 2'b01) );
assign status      = {22'd0, fir_add, dma_done, fifoo_full, fifoo_empty, fifoo_clear, fifoi_full, fifoi_empty, fifoi_clear, start};
assign master_read_done = (address_read == end_address_read) & start;
assign end_address_read = read_start_address + length;
assign master_write_done = (address_write == end_address_write) & start;
assign end_address_write = write_start_address + length;
assign fifoi_in_data = iReadData_Master_Read;
assign fifoi_write   = iDataValid_Master_Read;
//assign fifoo_out_data = oData_Master_Write;
assign fifoo_read    = oWrite_Master_Write;

/*****************************************************************************
 *                            Always Blocks                                   *
 *****************************************************************************/
// Control and Status Register Management
always_ff @(posedge iClk or negedge iRstn) begin
    if (~iRstn) begin
        control             <= 32'd0;
        inital              <= 32'd0;
        length              <= 32'd0;
        write_start_address <= 32'd0;
        read_start_address  <= 32'd0;
    end else if (iChipSelect_Control & iWrite_Control) begin
        case (iAddress_Control)
            3'd0: control             <= iData_Control;
            3'd1: inital              <= iData_Control;
            3'd2: read_start_address  <= iData_Control;
            3'd3: write_start_address <= iData_Control;
            3'd4: length              <= iData_Control;
        endcase
    end
end

always_ff @(posedge iClk or negedge iRstn) begin
    if (~iRstn)
        oData_Control <= 32'd0;
    else if (iChipSelect_Control & iRead_Control)
        case (iAddress_Control)
            3'd0: oData_Control <= control;
            3'd1: oData_Control <= inital;
            3'd2: oData_Control <= read_start_address;
            3'd3: oData_Control <= write_start_address;
            3'd4: oData_Control <= length;
            3'd5: oData_Control <= status;
        endcase
end

// Start Signal Management
always_ff @(posedge iClk or negedge iRstn) begin
    if (~iRstn)
        start <= 1'b0;
    else if (iChipSelect_Control & iWrite_Control & (iAddress_Control == 3'd0))
        start <= iData_Control[0];
    else if (done_trigger)
        start <= 1'b0;
end

// DMA Done Management
always_ff @(posedge iClk or negedge iRstn) begin
    if (~iRstn)
        dma_done <= 1'b0;
    else if (done_trigger)
        dma_done <= 1'b1;
    else if (start_trigger)
        dma_done <= 1'b0;
end

// Address Read Management
always_ff @(posedge iClk or negedge iRstn) begin
    if (~iRstn)
        address_read <= 32'd0;
    else if (address_read_fetch)
        address_read <= read_start_address;
    else if (address_read_incr)
        address_read <= address_read + 32'd4;
end

// Address Write Management
always_ff @(posedge iClk or negedge iRstn) begin
    if (~iRstn)
        address_write <= 32'd0;
    else if (address_write_fetch)
        address_write <= write_start_address;
    else if (address_write_incr)
        address_write <= address_write + 32'd4;
end

/*****************************************************************************
 *                        Read State Machine                                 *
 *****************************************************************************/
always_ff @(posedge iClk or negedge iRstn) begin
    if (~iRstn)
        r_cs <= r_idle;
    else
        r_cs <= r_ns;
end

always_comb begin
    r_ns = r_cs;
    oAddress_Master_Read = 32'd0;
    oRead_Master_Read    = 1'b0;
    address_read_fetch   = 1'b0;
    address_read_incr    = 1'b0;
	 fifoo_write          = 1'b0;
    case (r_cs)
        r_idle:
            if (start_trigger) 
				begin
                address_read_fetch = 1'b1;
                r_ns = r_fifo_write;
				end
        r_fifo_write:
            if (!fifoo_empty) begin
                fifoo_write = 1'b1;
                r_ns = r_request;
            end
        r_request:
            begin
                oAddress_Master_Read = address_read;
                oRead_Master_Read    = 1'b1;
					 //oData_Master_Read  = 
                if (iWait_Master_Read | fifoo_full)
                    r_ns = r_request;
                else begin
                    address_read_incr = 1'b1;
                    r_ns = r_incr;
                end
            end
        r_incr:
            if (master_read_done)
                r_ns = r_idle;
            else
                r_ns = r_request;
    endcase
end

/*****************************************************************************
 *                        Write State Machine                                *
 *****************************************************************************/
always_ff @(posedge iClk or negedge iRstn) begin
    if (~iRstn)
        w_cs <= w_idle;
    else
        w_cs <= w_ns;
end

always_comb begin
    w_ns = w_cs;
    oAddress_Master_Write = 32'd0;
    //oData_Master_Write    = 32'd0;
    oWrite_Master_Write   = 1'b0;
    address_write_fetch   = 1'b0;
    address_write_incr    = 1'b0;
    fifoi_read            = 1'b0;
    done_trigger          = 1'b0;
    case (w_cs)
        w_idle:
            if (!fifoi_empty)
				begin
                address_write_fetch = 1'b1;
                w_ns = w_fifo_read;
				end
        w_fifo_read:
            if (!fifoi_empty) begin
                fifoi_read = 1'b1;
                w_ns = w_request;
            end
        w_request:
            begin
                oWrite_Master_Write = 1'b1;
                oAddress_Master_Write = address_write;
                //oData_Master_Write = fifoo_out_data;
                if (iWait_Master_Write | fifoi_full)
                    w_ns = w_request;
                else begin
                    address_write_incr = 1'b1;
                    w_ns = w_incr;
                end
            end
        w_incr:
            if (master_write_done) begin
                w_ns = w_idle;
                done_trigger = 1'b1;
            end else
                w_ns = w_fifo_read;
    endcase
end

/*****************************************************************************
 *                          Module Instances                                 *
 *****************************************************************************/  
RisiEdgeDectector RisiEdgeDectector_start(
  .clk     (iClk),
  .rstn    (iRstn),
  .sign    (start),
  .trigger (start_trigger)
);

//Instantce FIFO
FIFO fifo_i (
    .aclr(fifoi_clear),
	 .wrclk(iClk),
    .wrreq(fifoi_write),
    .data(fifoi_in_data),
    .wrfull(fifoi_full),
    .wrusedw(number_word_usedi),
    .rdreq(fifoi_read),
	 .rdclk(iClk),
    .rdempty(fifoi_empty),
    .q(fifoi_out_data)

);

FIFO fifo_o (
    .aclr(fifoo_clear),
	 .wrclk(iClk),
    .wrreq(fifoo_write),
    .data(fifoo_in_data),
    .wrfull(fifoo_full),
    .wrusedw(number_word_usedo),
    .rdreq(fifoo_read),
	 .rdclk(iClk),
    .rdempty(fifoo_empty),
    .q(oData_Master_Write)
);

FIR_Wrapper fir_wrapper (
    .clk(iClk),
    .RstN(iRstn),
    .ChipSelect(fir_select),
    .WriteData(fir_data),
    .Address(fir_add),
    .Write(fir_wr),
    .Read(fifoo_write),
    .ReadData(fifoo_in_data)
);

endmodule 