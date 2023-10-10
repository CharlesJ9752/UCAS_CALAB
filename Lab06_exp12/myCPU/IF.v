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
    output                          inst_sram_en,
    output  [3:0]                   inst_sram_we,
    output  [31:0]                  inst_sram_addr,
    output  [31:0]                  inst_sram_wdata,
    input   [31:0]                  inst_sram_rdata,
    //异常&中断
    input                           wb_exc,
    input                           ertn_flush,
    input   [31:0]                  exc_entaddr,//中断处理程序入口地址
    input   [31:0]                  exc_retaddr//中断处理程序结束后的出口地址
);
//信号定义-IF内控制信号
    reg                             if_valid;//有指令在if�?
    wire                            if_ready_go;//指令可以去下�?个阶�?
    wire                            if_allowin;//可接�?
    wire                            en_brch_cancel;//使能跳转
    //pc和指令
    reg     [31:0]                  if_pc;//if阶段的pc�?
    wire    [31:0]                  if_inst;//if阶段的指�?
    wire    [31:0]                  if_nextpc;//下一个pc
    wire    [31:0]                  if_brch_addr;//若跳转的pc
    wire    [31:0]                  seq_pc;//若顺序的pc


//控制信号的赋值
    assign  if_ready_go = 1'b1;
    assign  if_allowin = ~resetn | if_ready_go & id_allowin;//还没�?始，或当前指令可以去下一�?
    always @(posedge clk ) begin
        if(~resetn)begin
            if_valid <= 1'b0;
        end
        else if (wb_exc | ertn_flush) begin //untest 
            if_valid <= 1'b0;
        end
        else if(if_allowin)begin
            if_valid <= 1'b1;
        end
    end
    assign  if_id_valid = if_ready_go & if_valid;

//pre-IF生成pc
    assign  seq_pc = if_pc + 3'h4;
    assign  if_nextpc = en_brch_cancel ? if_brch_addr : seq_pc;
    always @(posedge clk ) begin
        if(~resetn)begin
            if_pc <= 32'h1bfffffc;
        end
        else if(wb_exc | ertn_flush)begin   //untest
            if_pc <= (wb_exc? exc_entaddr - 4'h4 : exc_retaddr - 4'h4); 
        end
        else if(if_allowin)begin
            if_pc <= if_nextpc;
        end
    end

//取指操作
    assign  inst_sram_en = if_allowin;
    assign  inst_sram_addr = if_nextpc;
    assign  if_inst = inst_sram_rdata;
    assign  inst_sram_we = 4'b0;
    assign  inst_sram_wdata = 32'b0;

//与ID阶段交换数据
    assign  if_id_bus = { 
        if_pc, if_inst 
    };
    assign  { 
        en_brch_cancel, if_brch_addr
    } = id_if_bus;

endmodule