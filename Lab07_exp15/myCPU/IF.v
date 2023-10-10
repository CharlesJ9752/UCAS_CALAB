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
    output                           inst_sram_req,
    output                           inst_sram_wr,
    output [ 1:0]                    inst_sram_size,
    output [ 3:0]                    inst_sram_wstrb,
    output [31:0]                    inst_sram_addr,
    output [31:0]                    inst_sram_wdata,
    input                            inst_sram_addr_ok,
    input                            inst_sram_data_ok,
    input  [31:0]                    inst_sram_rdata,
    //异常&中断
    input                           wb_exc,
    input                           ertn_flush,
    input   [31:0]                  exc_entaddr,//中断处理程序入口地址
    input   [31:0]                  exc_retaddr//中断处理程序结束后的出口地址
);
//跳转
    wire                            br_stall;
    wire                            br_taken;
    wire    [31:0]                  br_target;
    assign  {
        br_taken, br_stall, br_target
    } = id_if_bus;
//preIF阶段，完成更新pc,向指令存储器发送申请
    //控制信号
    wire                            pf_ready_go;
    reg                             pf_valid;
    wire                            pf_if_valid;
    wire                            to_pf_valid;
    wire                            pf_allowin;
    always @(posedge clk ) begin
        if(~resetn)begin
            pf_valid<=1'b0;
        end
        else begin
            pf_valid<=to_pf_valid;
        end
    end
    assign  to_pf_valid = 1'b1;
    assign  pf_allowin  = 1'b1;//untest
    assign  pf_if_valid = pf_ready_go & pf_valid;
    assign  pf_ready_go =  inst_sram_addr_ok && inst_sram_req
                        &&!(wb_exc||ertn_flush||br_stall||((pf_ertn_reg || pf_exc_reg)&&cancel));//untest
    //生成pc
    wire    [31:0]                  pf_seqpc;
    wire    [31:0]                  pf_nextpc;
    reg     [31:0]                  pf_pc;
    assign  pf_nextpc = wb_exc     ?    exc_entaddr   : pf_exc_reg              ?  pf_entaddr_reg :
                        ertn_flush ?    exc_retaddr   : pf_ertn_reg             ?  pf_retaddr_reg :
                        br_reg ?        br_target_reg : br_taken & ~br_stall ?  br_target   :
                        pf_seqpc;
    assign  pf_seqpc = pf_pc + 3'h4;
    always @(posedge clk ) begin
        if(~resetn)begin
            pf_pc<=32'h1bfffffc;
        end
        else if(pf_ready_go & if_allowin)begin
            pf_pc<=pf_nextpc;
        end
    end
    //中断返回、中断陷入和跳转的地址
    reg                             pf_exc_reg;
    reg     [31:0]                  pf_entaddr_reg;
    reg                             pf_ertn_reg;
    reg     [31:0]                  pf_retaddr_reg;
    reg                             br_reg;
    reg     [31:0]                  br_target_reg;
    //控制信号
    always @(posedge clk) begin
        if (~resetn) begin
            br_reg <= 1'b0;
        end
        else if (br_taken && !br_stall) begin
            br_reg <= 1'b1;
        end 
        else if (inst_sram_addr_ok && ~cancel && if_allowin)begin
            br_reg <= 1'b0;
        end 
    end
    always @(posedge clk) begin
        if (~resetn) begin
            pf_exc_reg <= 1'b0;
            pf_ertn_reg <= 1'b0;
        end 
        else if (wb_exc) begin
            pf_exc_reg <= 1'b1;
        end 
        else if (ertn_flush) begin
            pf_ertn_reg <= 1'b1;
        end 
        else if (inst_sram_addr_ok && if_allowin && ~cancel)begin
            pf_exc_reg <= 1'b0;
            pf_ertn_reg <= 1'b0;
        end
    end
    //地址信息
    always @(posedge clk ) begin
        if (~resetn) begin
            br_target_reg <= 32'b0;
        end
        else if (br_taken && !br_stall) begin
            br_target_reg <= br_target;
        end 
        else if (inst_sram_addr_ok && ~cancel && if_allowin)begin
            br_target_reg <= 32'b0;
        end 
    end
    always @(posedge clk ) begin
        if (~resetn) begin
            pf_entaddr_reg <= 32'b0;
            pf_retaddr_reg <= 32'b0;
        end 
        else if (wb_exc) begin
            pf_entaddr_reg <= exc_entaddr;
        end 
        else if (ertn_flush) begin
            pf_retaddr_reg <= exc_retaddr;
        end 
        else if (inst_sram_addr_ok && if_allowin && ~cancel)begin
            pf_entaddr_reg <= 32'b0;
            pf_retaddr_reg <= 32'b0;
        end
    end
    //向指令存储器发送申请
    assign inst_sram_req = resetn && pf_valid && if_allowin && ~cancel;//add
    assign inst_sram_addr = pf_nextpc   ;
    assign inst_sram_size = 2'h2        ;
    assign inst_sram_wstrb = 4'b0       ;
    assign inst_sram_wdata = 32'b0      ;
    assign inst_sram_wr    = 1'b0       ;//don't write
    reg     cancel;//flush用于避免陷入时出现pc和指令不相同的情况
    always @(posedge clk ) begin
        if(~resetn)begin
            cancel <= 1'b0;
        end
        else if(inst_sram_req && (ertn_flush||wb_exc||(br_stall&&inst_sram_addr_ok)))begin
            cancel <= 1'b1;
        end
        else if(inst_sram_data_ok)begin
            cancel <= 1'b0;
        end
    end
//IF阶段，完成取指，传递给下个ID阶段
    //流水线控制信号
    reg         if_valid;
    wire        if_ready_go;
    wire        if_allowin;
    assign if_allowin = if_ready_go && id_allowin || ~if_valid;
    assign if_ready_go = inst_sram_data_ok & if_valid | buffer_valid;//is_ertn_exc
    assign if_id_valid = ~is_ertn_exc & if_valid & if_ready_go;
    always @(posedge clk ) begin
        if(~resetn)begin
            if_valid <= 1'b0;
        end
        else if (if_allowin) begin
            if_valid <= pf_if_valid;
        end//例外
    end
    //控制信号
    reg             if_exc_reg;
    reg             if_ertn_reg;
    always @(posedge clk) begin
        if (~resetn) begin
            if_exc_reg <= 1'b0;
            if_ertn_reg <= 1'b0;
        end 
        else if (wb_exc) begin
            if_exc_reg <= 1'b1;
        end 
        else if (ertn_flush) begin
            if_ertn_reg <= 1'b1;
        end 
        else if (if_allowin && pf_if_valid)begin
            if_exc_reg <= 1'b0;
            if_ertn_reg <= 1'b0;
        end 
    end
    //接preIF
    reg [31:0]  if_pc_reg;
    always @(posedge clk ) begin
        if(~resetn)begin
            if_pc_reg<=32'b0;
        end
        else if(pf_if_valid & if_allowin)begin
            if_pc_reg <= pf_nextpc;
        end
    end
    wire [31:0] if_pc;
    assign  if_pc = if_pc_reg;
    //中断和异常
    wire [5:0]  if_exc_type;
    assign if_exc_type[`TYPE_ADEF] = |if_pc[1:0];
    assign if_exc_type[`TYPE_SYS]  = 1'b0;
    assign if_exc_type[`TYPE_ALE]  = 1'b0;
    assign if_exc_type[`TYPE_BRK]  = 1'b0;
    assign if_exc_type[`TYPE_INE]  = 1'b0;
    assign if_exc_type[`TYPE_INT]  = 1'b0;
    //取指
    reg         buffer_valid;
    wire        is_ertn_exc;
    reg [31:0]  buffer;
    wire [31:0] if_inst;
    assign  if_inst = buffer_valid ? buffer : inst_sram_rdata;
    assign is_ertn_exc = wb_exc | ertn_flush | if_ertn_reg | if_exc_reg;
    always @(posedge clk ) begin
        if(~resetn)begin
            buffer_valid <= 1'b0;
        end
        else if (inst_sram_data_ok & ~buffer_valid & ~is_ertn_exc & ~id_allowin)begin
            buffer_valid <= 1'b1;
        end
        else if (id_allowin | ertn_flush | wb_exc) begin
            buffer_valid <= 1'b0;//清零
        end
    end
    always @(posedge clk ) begin
        if(~resetn)begin
            buffer <= 32'b0;
        end
        else if (inst_sram_data_ok & ~buffer_valid & ~is_ertn_exc & ~id_allowin)begin
            buffer <= inst_sram_rdata;
        end
        else if (id_allowin | ertn_flush | wb_exc) begin
            buffer <= 32'b0;
        end
    end
    //连接ID
    assign  if_id_bus = {
        if_exc_type, if_pc, if_inst
    };
endmodule