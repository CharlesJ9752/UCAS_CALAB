`include "mycpu.h"
//取指，更新pc
module IF (
    input                           clk,
    input                           resetn,
    //与ID阶段数据中断
    input                           id_allowin,
    output                          if_id_valid,
    output  [`IF_ID_BUS_WDTH - 1:0] if_id_bus,//if_exc_type + if_pc + if_inst
    input   [`ID_IF_BUS_WDTH - 1:0] id_if_bus,//en_brch+brch_addr
    //与指令存储器
    output  [3:0]                   inst_sram_we,
    output  [31:0]                  inst_sram_wdata,
    input   [31:0]                  inst_sram_rdata,
    input                           inst_sram_addr_ok,
    input                           inst_sram_data_ok,
    //异常&中断
    input                           wb_exc,
    input                           ertn_flush,
    input   [31:0]                  exc_entaddr,//中断处理程序入口地址
    input   [31:0]                  exc_retaddr,//中断处理程序结束后的出口地址
    //与preIF
    output                           if_allowin     ,
    output                           if_block ,
    input                            pf_if_valid,
    input  [31:0]                    pf_if_bus  
);
//信号定义-IF内控制信号
    reg                             if_valid;//有指令在if�?
    wire                            if_ready_go;//指令可以去下�?个阶�?
    wire                            br_taken;//使能跳转
    //pc和指令
    wire     [31:0]                  if_pc;//if阶段的pc�?
    wire    [31:0]                  if_inst;//if阶段的指�?
    wire    [5:0]                   if_exc_type;

    //exp14
    reg        if_inst_valid;
    reg [31:0] if_inst_buff;
    reg        if_inst_cancel;                           
    wire       br_stall;
    wire [31:0] br_target;
    assign  {
        br_taken, br_stall, br_target
    } = id_if_bus;
    assign  if_id_bus = {
        if_exc_type, if_pc, if_inst
    };
    assign if_allowin     = (if_ready_go && id_allowin) || !if_valid;
    assign if_ready_go    = if_inst_valid || (if_valid && inst_sram_data_ok);
    assign if_id_valid = if_valid && if_ready_go && !(wb_exc || ertn_flush) && !(br_taken && !br_stall) && !if_inst_cancel;
    reg     wb_exc_reg;
    reg     ertn_flush_reg;
    reg     [31:0]  pf_if_bus_vld;
    wire    [31:0]  pf_pc;
    assign  pf_pc = pf_if_bus_vld;
    always @(posedge clk) begin
    if(~resetn)begin
        if_valid <= 1'b0;
    end
    else if(if_allowin)begin
        if_valid <= pf_if_valid;
    end
    // else if(ertn_flush || wb_exc || br_taken) begin
    //     if_valid <= 1'b0;
    // end
end
always @(posedge clk) begin
    if(pf_if_valid && if_allowin) begin
        pf_if_bus_vld <= pf_if_bus;
    end
end

always @(posedge clk) begin        
    if(~resetn) begin
        if_inst_valid <= 1'b0;
        if_inst_buff <= 32'b0;
    end
    else if(!if_inst_valid && inst_sram_data_ok && !if_inst_cancel && !id_allowin) begin
        if_inst_valid <= 1'b1;
        if_inst_buff <= inst_sram_rdata;
    end
    else if (id_allowin || (ertn_flush || wb_exc) ) begin
        if_inst_valid <= 1'b0;
        if_inst_buff <= 32'b0;
    end

    if(~resetn) begin
        if_inst_cancel <= 1'b0;
    end
    else if(!if_allowin && !if_ready_go && ((ertn_flush | wb_exc) ||( br_taken && ~br_stall))) begin
        if_inst_cancel <= 1'b1;
    end
    else if(inst_sram_data_ok) begin
        if_inst_cancel <= 1'b0;
    end

end

always @(posedge clk) begin
    if (~resetn) begin
        wb_exc_reg <= 1'b0;
        ertn_flush_reg <= 1'b0;
    end else if (if_ready_go && id_allowin)begin
        wb_exc_reg <= 1'b0;
        ertn_flush_reg <= 1'b0;
    end else if (wb_exc) begin
        wb_exc_reg <= 1'b1;
    end else if (ertn_flush) begin
        ertn_flush_reg <= 1'b1;
    end
end

assign if_block = !if_valid || if_inst_valid;
assign if_pc = pf_pc;
assign if_inst = if_inst_valid ? if_inst_buff : inst_sram_rdata;

assign if_exc_type[`TYPE_ADEF] = |if_pc[1:0];
assign if_exc_type[`TYPE_SYS]  = 1'b0;
assign if_exc_type[`TYPE_ALE]  = 1'b0;
assign if_exc_type[`TYPE_BRK]  = 1'b0;
assign if_exc_type[`TYPE_INE]  = 1'b0;
assign if_exc_type[`TYPE_INT]  = 1'b0;
endmodule