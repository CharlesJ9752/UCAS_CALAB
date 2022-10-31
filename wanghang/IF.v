`include "mycpu.h"
`include "csr.h"

module IF (
    input           clk,
    input           reset,
    input           ds_allowin,
    output          fs_to_ds_valid,
    input   [32:0]  ds_to_fs_bus,
    output  [`FS_TO_DS_BUS_WD-1:0]  fs_to_ds_bus,
    output          inst_sram_en,
    output  [31:0]  inst_sram_addr,
    input   [31:0]  inst_sram_rdata,

    // exc && int
    input         wb_exc,
    input         wb_ertn,
    input  [31:0] exc_entry,
    input  [31:0] exc_retaddr
);
reg             fs_valid;
wire            fs_ready_go;
reg     [31:0]  fs_pc;
wire    [31:0]  nextpc;
wire    [31:0]  fs_inst;
wire            fs_allowin;
wire            br_taken;
wire    [31:0]  brch_addr;
wire    [31:0]  seq_pc;

//contact
assign fs_allowin = (fs_ready_go & ds_allowin)|!fs_valid;
assign fs_ready_go = 1'b1;
assign fs_to_ds_valid = fs_valid & fs_ready_go;
always @(posedge clk ) begin
    if(reset)begin
        fs_valid<=1'b0;
    end
    else if (wb_exc | wb_ertn) begin
        fs_valid<=1'b0;
    end
    else if(fs_allowin)begin
        fs_valid<=1'b1;
       end
end

//data
assign {br_taken,brch_addr} = ds_to_fs_bus;
assign fs_to_ds_bus = { fs_exc_flags,
                        fs_pc,
                        fs_inst};

//PC
assign nextpc = br_taken ? brch_addr : seq_pc;
assign seq_pc = fs_pc+3'h4;
always @(posedge clk ) begin
    if (reset) begin
        fs_pc <= 32'h1bfffffc;  //trick: to make nextpc be 0x1c000000 during reset 
    end else if (wb_exc | wb_ertn) begin
        fs_pc <= (wb_exc ? exc_entry : exc_retaddr) - 32'h4;
    end
    else if(fs_allowin)begin 
        fs_pc <= nextpc;
    end
end

assign inst_sram_en = fs_allowin;
assign inst_sram_addr = nextpc;
assign fs_inst = inst_sram_rdata;

// exec list
wire [`EXC_NUM - 1:0] fs_exc_flags;
assign fs_exc_flags[`EXC_FLG_ADEF] = |nextpc[1:0];
// init other exec to 0 by default
assign fs_exc_flags[`EXC_FLG_SYS]  = 1'b0;
assign fs_exc_flags[`EXC_FLG_ALE]  = 1'b0;
assign fs_exc_flags[`EXC_FLG_BRK]  = 1'b0;
assign fs_exc_flags[`EXC_FLG_INE]  = 1'b0;
assign fs_exc_flags[`EXC_FLG_INT]  = 1'b0;

endmodule