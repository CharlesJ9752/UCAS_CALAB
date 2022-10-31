`include "mycpu.h"
`include "csr.h"

module WB (
    input           clk,
    input           reset,
    output          ws_allowin,
    input           ms_to_ws_valid,
    input   [`MS_TO_WS_BUS_WD-1:0]  ms_to_ws_bus,//add csr
    output  [37:0]  ws_to_ds_bus,
    output  [31:0]  debug_wb_pc     ,
    output  [ 3:0]  debug_wb_rf_we ,
    output  [ 4:0]  debug_wb_rf_wnum,
    output  [31:0]  debug_wb_rf_wdata,
    output  [5:0]   ws_block_bus,
    output  [31:0]  ws_forward,

    //write csr
    output          csr_we,
    output  [13:0]  csr_wnum,
    output  [31:0]  csr_wvalue,
    output  [31:0]  csr_wmask,

    //exc
    output          wb_exc,
    output  [5:0]   wb_ecode,
    output  [8:0]   wb_esubcode,
    output          ertn_flush,
    output  [31:0]  wb_pc,
    output  [31:0]  wb_vaddr,
    //csr blk
    output  [15:0]  ws_csr_blk_bus
);
    reg [`MS_TO_WS_BUS_WD -1:0] WBreg;
    reg ws_valid;
    wire ws_ready_go;
    wire gr_we;
    wire [31:0] ws_pc;
    wire [31:0] final_result;
    wire rf_we;
    wire [4:0] rf_waddr;
    wire [4:0] dest;
    wire [31:0] rf_wdata;
    //csr
    wire [5:0]          ws_exc_flags;//every bit marks onr type of exc, for exp12 only one bit is used(syscall)
    wire                ws_csr_we;
    wire [13:0]         ws_csr_wnum;
    wire [31:0]         ws_csr_wvalue;
    wire [31:0]         ws_csr_wmask;
    wire                ws_inst_ertn;

    //contact
    assign ws_ready_go=1'b1;
    assign ws_allowin = ws_ready_go|~ws_valid;
    always @(posedge clk ) begin
        if(reset)begin
            ws_valid<=1'b0;
        end
        else if (wb_exc | ertn_flush) begin
            ws_valid <= 1'b0;
        end
        else if(ws_allowin) begin
            ws_valid<=ms_to_ws_valid;
        end
    end

    //data
    always @(posedge clk ) begin
        if(ws_allowin&ms_to_ws_valid)begin
            WBreg<=ms_to_ws_bus;
        end
    end
    assign {ws_csr_we,ws_csr_wnum,ws_csr_wmask,ws_csr_wvalue,ws_inst_ertn,ws_exc_flags,gr_we,ws_pc,final_result,dest} = WBreg;
    assign ws_to_ds_bus = {rf_we,rf_waddr,rf_wdata};
    assign ws_block_bus = {rf_we&ws_valid,dest};
    assign ws_forward = rf_wdata;

    assign rf_we = gr_we & ws_valid & ~wb_exc;
    assign rf_waddr = dest;
    assign rf_wdata = final_result;


    //debug
    assign debug_wb_pc = ws_pc;
    assign debug_wb_rf_we={4{rf_we}};
    assign debug_wb_rf_wnum=dest;
    assign debug_wb_rf_wdata=final_result;

    // exception & int
    assign wb_exc   = ws_valid & (|ws_exc_flags);
    assign wb_ecode = ws_exc_flags[`EXC_FLG_INT ] ? `ECODE_INT :
                      ws_exc_flags[`EXC_FLG_ADEF] ? `ECODE_ADE :
                      ws_exc_flags[`EXC_FLG_INE ] ? `ECODE_INE :
                      ws_exc_flags[`EXC_FLG_SYS ] ? `ECODE_SYS :
                      ws_exc_flags[`EXC_FLG_BRK ] ? `ECODE_BRK :
                      ws_exc_flags[`EXC_FLG_ALE ] ? `ECODE_ALE : 6'h00;
    assign wb_esubcode = {9{ws_exc_flags[`EXC_FLG_ADEF]}} & `ESUBCODE_ADEF;
    assign wb_pc = ws_pc;
    assign wb_vaddr = final_result;
    assign ertn_flush = ws_inst_ertn & ws_valid;

    assign ws_csr_blk_bus = {ws_csr_we & ws_valid, ws_inst_ertn & ws_valid, ws_csr_wnum};//conflict
    
    // csr
    assign csr_wmask = ws_csr_wmask;
    assign csr_we = ws_csr_we & ws_valid & ~wb_exc;
    assign csr_wnum = ws_csr_wnum;
    assign csr_wvalue = ws_csr_wvalue;

endmodule