module sync_fifo #(
    parameter C_FIFO_WIDTH = 8,
    parameter C_FIFO_DEPTH = 2048
)(
    input  wire                             rst,
    input  wire                             clk,
    
    input  wire                             wr_en,
    input  wire [C_FIFO_WIDTH - 1:0]        din,
    output reg                              full,
    
    input  wire                             rd_en,
    output wire [C_FIFO_WIDTH - 1:0]        dout,
    output reg                              empty,
    output reg  [clogb2(C_FIFO_DEPTH-1):0]  data_count
);

//======================================================
//  Constants and Signals Definition
//======================================================
localparam ADDR_WIDTH = clogb2(C_FIFO_DEPTH-1);

reg  [C_FIFO_WIDTH - 1:0]              mem [C_FIFO_DEPTH - 1:0];
reg  [ADDR_WIDTH - 1:0]                wr_ptr;           // Write pointer
reg  [ADDR_WIDTH - 1:0]                rd_ptr;           // Read pointer
wire [ADDR_WIDTH - 1:0]                next_wr_ptr;      // Next write pointer
wire [ADDR_WIDTH - 1:0]                next_rd_ptr;      // Next read pointer
wire                                   wr_ack;           // Write acknowledge
wire                                   rd_ack;           // Read acknowledge

//======================================================
//  Pointer Management
//======================================================

// Calculate next write pointer
assign next_wr_ptr = (wr_ptr == C_FIFO_DEPTH - 1) ? 0 : (wr_ptr + 1);

// Write pointer update
always @(posedge clk or posedge rst) begin
    if (rst)
        wr_ptr <= 0;
    else if (wr_ack)
        wr_ptr <= next_wr_ptr;
end

// Calculate next read pointer
assign next_rd_ptr = (rd_ptr == C_FIFO_DEPTH - 1) ? 0 : (rd_ptr + 1);

// Read pointer update
always @(posedge clk or posedge rst) begin
    if (rst)
        rd_ptr <= 0;
    else if (rd_ack)
        rd_ptr <= next_rd_ptr;
end

//======================================================
//  Memory Write Logic
//======================================================
assign wr_ack = wr_en & ~full;

always @(posedge clk) begin
    if (wr_ack)
        mem[wr_ptr] <= din;
end

//======================================================
//  Memory Read Logic
//======================================================
assign rd_ack = rd_en & ~empty;
assign dout   = mem[rd_ptr];

//======================================================
//  Full Flag Generation
//======================================================
always @(posedge clk or posedge rst) begin
    if (rst) begin
        full <= 1'b0;
    end else begin
        if (((wr_ptr == C_FIFO_DEPTH - 1) && (rd_ptr == 0)) || 
            (wr_ptr == rd_ptr - 1)) begin
            if (wr_en && !rd_en)
                full <= 1'b1;
            else if (rd_en)
                full <= 1'b0;
        end else if (full && rd_en) begin
            full <= 1'b0;
        end else if (!full && ((wr_ptr == C_FIFO_DEPTH - 1) && (rd_ptr == 0)) || 
                     (wr_ptr == rd_ptr - 1)) begin
            if (wr_en && !rd_en)
                full <= 1'b1;
        end
    end
end

//======================================================
//  Empty Flag Generation
//======================================================
always @(posedge clk or posedge rst) begin
    if (rst) begin
        empty <= 1'b1;
    end else begin
        if (((rd_ptr == C_FIFO_DEPTH - 1) && (wr_ptr == 0)) || 
            (rd_ptr == wr_ptr)) begin
            if (rd_en && !wr_en)
                empty <= 1'b1;
            else if (wr_en)
                empty <= 1'b0;
        end else if (empty && wr_en) begin
            empty <= 1'b0;
        end else if (!empty && ((rd_ptr == C_FIFO_DEPTH - 1) && (wr_ptr == 0)) || 
                     (rd_ptr == wr_ptr)) begin
            if (rd_en && !wr_en)
                empty <= 1'b1;
        end
    end
end

//======================================================
//  Data Count Logic
//======================================================
always @(posedge clk or posedge rst) begin
    if (rst)
        data_count <= 0;
    else begin
        case ({wr_ack, rd_ack})
            2'b10: data_count <= data_count + 1;  // Write only
            2'b01: data_count <= data_count - 1;  // Read only
            default: data_count <= data_count;    // No change
        endcase
    end
end

//======================================================
//  Utility Function
//======================================================
function integer clogb2;
    input integer depth;
    begin
        for(clogb2 = 0; depth > 0; clogb2 = clogb2 + 1)
            depth = depth >> 1;
    end
endfunction

endmodule