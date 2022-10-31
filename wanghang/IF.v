`include "mycpu.h"
`include "csr.h"

module IF (
    input           clk,
    input           reset,
    //ds
    input           ds_allowin,
    output          fs_to_ds_valid,
    input  [`BR_BUS_WD       -1:0]  br_bus,
    output  [`FS_TO_DS_BUS_WD-1:0]  fs_to_ds_bus,
    
    //from pfs
    input                            pfs_to_fs_valid,
    input  [`PFS_TO_FS_BUS_WD - 1:0] pfs_to_fs_bus  ,

    //to pfs
    output                           fs_allowin     ,
    output                           fs_block ,

    // inst sram interface
    input                           inst_sram_addr_ok,
    input                           inst_sram_data_ok,
    input   [31:0]                  inst_sram_rdata,

    // exc && int
    input         wb_exc,
    input         wb_ertn,
    input  [31:0] exc_entry,
    input  [31:0] exc_retaddr
);

reg             fs_valid;
wire            fs_ready_go;


wire    [31:0]  fs_pc;
wire    [31:0]  fs_inst;

// for exp14
reg        fs_inst_valid;
reg [31:0] fs_inst_buff;
reg        fs_inst_cancel;

wire         br_taken;
wire         br_stall;
wire    [31:0]  brch_addr;
assign {br_taken, br_stall, brch_addr} = br_bus;

wire [31                   :0] pfs_pc;
reg  [`PFS_TO_FS_BUS_WD - 1:0] pfs_to_fs_bus_r;
assign pfs_pc = pfs_to_fs_bus_r;

wire [`EXC_NUM - 1:0] fs_exc_flags;
assign fs_to_ds_bus = { fs_exc_flags,
                        fs_pc,
                        fs_inst};
reg        wb_exc_r;
reg        wb_ertn_r;

//contact 
assign fs_allowin     = (fs_ready_go && ds_allowin) || !fs_valid;
assign fs_ready_go    = fs_inst_valid || (fs_valid && inst_sram_data_ok);
assign fs_to_ds_valid = fs_valid && fs_ready_go && !(wb_exc || wb_ertn) && !(br_taken && !br_stall) && !fs_inst_cancel;

// from pfs
always @(posedge clk) begin
    if(reset)begin
        fs_valid <= 1'b0;
    end
    else if(fs_allowin)begin
        fs_valid <= pfs_to_fs_valid;
    end
end
always @(posedge clk) begin
    if(pfs_to_fs_valid && fs_allowin) begin
        pfs_to_fs_bus_r <= pfs_to_fs_bus;
    end
end

always @(posedge clk) begin        
    if(reset) begin
        fs_inst_valid <= 1'b0;
        fs_inst_buff <= 32'b0;
    end
    else if(!fs_inst_valid && inst_sram_data_ok && !fs_inst_cancel && !ds_allowin) begin
        fs_inst_valid <= 1'b1;
        fs_inst_buff <= inst_sram_rdata;
    end
    else if (ds_allowin || (wb_ertn || wb_exc) ) begin
        fs_inst_valid <= 1'b0;
        fs_inst_buff <= 32'b0;
    end

//inst_cancel
    if(reset) begin
        fs_inst_cancel <= 1'b0;
    end
    else if(!fs_allowin && !fs_ready_go && ((wb_ertn | wb_exc) ||( br_taken && ~br_stall))) begin
        fs_inst_cancel <= 1'b1;
    end
    else if(inst_sram_data_ok) begin
        fs_inst_cancel <= 1'b0;
    end

end

/// exception
always @(posedge clk) begin
    if (reset) begin
        wb_exc_r <= 1'b0;
        wb_ertn_r <= 1'b0;
    end else if (fs_ready_go && ds_allowin)begin
        wb_exc_r <= 1'b0;
        wb_ertn_r <= 1'b0;
    end else if (wb_exc) begin
        wb_exc_r <= 1'b1;
    end else if (wb_ertn) begin
        wb_ertn_r <= 1'b1;
    end
end

assign fs_block = !fs_valid || fs_inst_valid;
assign fs_pc = pfs_pc;
assign fs_inst = fs_inst_valid ? fs_inst_buff : inst_sram_rdata;

// exec list
assign fs_exc_flags[`EXC_FLG_ADEF] = |fs_pc[1:0];
// init other exec to 0 by default
assign fs_exc_flags[`EXC_FLG_SYS]  = 1'b0;
assign fs_exc_flags[`EXC_FLG_ALE]  = 1'b0;
assign fs_exc_flags[`EXC_FLG_BRK]  = 1'b0;
assign fs_exc_flags[`EXC_FLG_INE]  = 1'b0;
assign fs_exc_flags[`EXC_FLG_INT]  = 1'b0;

endmodule