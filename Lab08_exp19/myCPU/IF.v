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
    input                            flush,
    input   [31:0]                   flush_pc,
    input                            csr_crmd_da,
    input                            csr_crmd_pg,
    input  [ 1:0]                    csr_crmd_plv,
    output [18:0]                    s0_vppn,
    output                           s0_va_bit12,
    input                            s0_found,
    input  [ 3:0]                    s0_index,
    input  [19:0]                    s0_ppn,
    input  [ 5:0]                    s0_ps,
    input  [ 1:0]                    s0_plv,
    input  [ 1:0]                    s0_mat,
    input                            s0_d,
    input                            s0_v,
    input                            csr_dmw0_plv0,
    input                            csr_dmw0_plv3,
    input [ 1:0]                     csr_dmw0_mat,
    input [ 2:0]                     csr_dmw0_pseg,
    input [ 2:0]                     csr_dmw0_vseg,
    input                            csr_dmw1_plv0,
    input                            csr_dmw1_plv3,
    input [ 1:0]                     csr_dmw1_mat,
    input [ 2:0]                     csr_dmw1_pseg,
    input [ 2:0]                     csr_dmw1_vseg
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
    assign  pf_ready_go =  (inst_sram_addr_ok && inst_sram_req) && ~(((pf_wb_flush_r || stall_reg) && cancel) || flush || br_stall);   
    
    //生成pc
    wire    [31:0]                  pf_seqpc;
    wire    [31:0]                  pf_nextpc;
    reg     [31:0]                  pf_pc;
    assign  pf_nextpc = flush ?      flush_pc : pf_wb_flush_r ?         flush_pc_r : br_reg ?        br_target_reg : br_taken & ~br_stall ?  br_target   : pf_seqpc;
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
    reg                             br_reg;
    reg     [31:0]                  br_target_reg;
    reg                             stall_reg;
    reg                             pf_wb_flush_r;
    reg     [31:0]                  flush_pc_r;
    //控制信号
    always @(posedge clk) begin
        if (~resetn) begin
            br_reg <= 1'b0;
            stall_reg <= 1'b0;
        end else if(br_stall) begin
            stall_reg <= 1'b1;
        end else if (br_taken && !br_stall) begin
            br_reg <= 1'b1;
        end else if (inst_sram_addr_ok && ~cancel && if_allowin)begin
            br_reg <= 1'b0;
            stall_reg <= 1'b0;
        end 
    end
    always @(posedge clk) begin
        if (~resetn) begin
            pf_wb_flush_r <= 1'b0;
        end else if (flush) begin
            pf_wb_flush_r <= 1'b1;
        end else if (inst_sram_addr_ok&&~cancel&&if_allowin) begin
            pf_wb_flush_r <= 1'b0;
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
    always @(posedge clk) begin
        if (~resetn) begin
            flush_pc_r <= 32'b0;
        end else if (flush) begin
            flush_pc_r <= flush_pc;
        end else if (inst_sram_addr_ok&&~cancel&&if_allowin) begin
            flush_pc_r <= 32'b0;
        end
    end
    //向指令存储器发送申请
    assign inst_sram_req = pf_valid && if_allowin && !cancel;//add
    assign inst_sram_addr = csr_crmd_da & ~csr_crmd_pg ? pf_nextpc : pf_dmw0_hit ? pf_dmw0_paddr : pf_dmw1_hit ? pf_dmw1_paddr :pf_tlb_pa;
    assign inst_sram_size = 2'h2        ;
    assign inst_sram_wstrb = 4'b0       ;
    assign inst_sram_wdata = 32'b0      ;
    assign inst_sram_wr    = 1'b0       ;//don't write
    reg     cancel;
    always @(posedge clk ) begin
        if (~resetn) begin
            cancel <= 1'b0;
        end else if (inst_sram_req && (flush | (br_stall && inst_sram_addr_ok))) begin
            cancel <= 1'b1;
        end else if (inst_sram_data_ok) begin
            cancel <= 1'b0;
        end
    end
    wire    [`PF_IF_BUS_WDTH - 1:0] pf_if_bus;
    assign pf_if_bus = {
        pf_exc_type, pf_nextpc
    };
    //exceptions
    wire    [`NUM_TYPES - 1:0] pf_exc_type;
    assign pf_exc_type[`TYPE_ADEF] = ((|pf_nextpc[1:0])|(pf_nextpc[31]&csr_crmd_plv==2'd3))&~pf_dmw0_hit&~pf_dmw1_hit;
    assign pf_exc_type[`TYPE_TLBRF] = use_tlb & ~s0_found;
    assign pf_exc_type[`TYPE_PIF]  = use_tlb & ~s0_v;
    assign pf_exc_type[`TYPE_PLVF] = use_tlb & (csr_crmd_plv > s0_plv);
    assign pf_exc_type[`TYPE_PME]  = 1'b0;
    assign pf_exc_type[`TYPE_PIL]  = 1'b0;
    assign pf_exc_type[`TYPE_PIS]  = 1'b0;
    assign pf_exc_type[`TYPE_SYS]  = 1'b0;
    assign pf_exc_type[`TYPE_PLVM] = 1'b0;
    assign pf_exc_type[`TYPE_ALE]  = 1'b0;
    assign pf_exc_type[`TYPE_BRK]  = 1'b0;
    assign pf_exc_type[`TYPE_INE]  = 1'b0;
    assign pf_exc_type[`TYPE_INT]  = 1'b0;
    assign pf_exc_type[`TYPE_ADEM] = 1'b0;
    assign pf_exc_type[`TYPE_TLBRM] = 1'b0;
    //虚实地址转换
    wire    pf_dmw0_hit;
    wire    pf_dmw1_hit;
    wire    use_tlb;
    wire    [31:0]  pf_dmw0_paddr;
    wire    [31:0]  pf_dmw1_paddr;
    wire    [31:0]  pf_tlb_pa;
    assign {s0_vppn,s0_va_bit12}= pf_nextpc[31:12];
    assign use_tlb = ~(csr_crmd_da & ~csr_crmd_pg) & ~pf_dmw0_hit & ~pf_dmw1_hit;
    assign pf_tlb_pa = s0_ps == 6'd22 ? {s0_ppn[19:10],pf_nextpc[21:0]}:{s0_ppn,pf_nextpc[11:0]};
    assign pf_dmw0_paddr = {csr_dmw0_pseg, pf_nextpc[28:0]};
    assign pf_dmw1_paddr = {csr_dmw1_pseg, pf_nextpc[28:0]};
    assign pf_dmw0_hit =pf_nextpc[31:29]==csr_dmw0_vseg&&(csr_crmd_plv == 2'd0&&csr_dmw0_plv0||csr_crmd_plv == 2'd3&& csr_dmw0_plv3);
    assign pf_dmw1_hit =pf_nextpc[31:29]==csr_dmw1_vseg&&(csr_crmd_plv == 2'd0&&csr_dmw1_plv0||csr_crmd_plv == 2'd3&& csr_dmw1_plv3);
//IF阶段，完成取指，传递给下个ID阶段
    //流水线控制信号
    reg         if_valid;
    wire        if_ready_go;
    wire        if_allowin;
    assign if_allowin = if_ready_go&id_allowin|~if_valid;
    assign if_ready_go = inst_sram_data_ok&if_valid|buffer_valid;//is_ertn_exc
    assign if_id_valid = ~is_ertn_exc&if_valid&if_ready_go;
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
    always @(posedge clk ) begin
        if(~resetn)begin
            if_wb_flush_r<=1'b0;
        end
        else if (flush) begin
            if_wb_flush_r<=1'b1;
        end
        else if (pf_if_valid && if_allowin)begin
            if_wb_flush_r<=1'b0;
        end
    end
    //接preIF
    reg [`PF_IF_BUS_WDTH - 1:0]  pf_if_bus_vld;
    always @(posedge clk ) begin
        if(~resetn)begin
            pf_if_bus_vld<=`PF_IF_BUS_WDTH'b0;
        end
        else if(pf_if_valid & if_allowin)begin
            pf_if_bus_vld <= pf_if_bus;
        end
    end
    wire [31:0] if_pc;
    wire [`NUM_TYPES - 1:0] from_pf_exc_type;
    assign  {from_pf_exc_type,if_pc} = pf_if_bus_vld;
    //中断和异常
    wire [`NUM_TYPES - 1:0]  if_exc_type;
    assign if_exc_type = from_pf_exc_type;
    //取指
    reg         buffer_valid;
    reg         if_wb_flush_r;
    wire        is_ertn_exc;
    reg [31:0]  buffer;
    wire [31:0] if_inst;
    assign  if_inst = buffer_valid ? buffer : inst_sram_rdata;
    assign is_ertn_exc = flush|if_wb_flush_r;
    always @(posedge clk ) begin
        if(~resetn)begin
            buffer_valid <= 1'b0;
        end
        else if (inst_sram_data_ok & ~buffer_valid & ~is_ertn_exc & ~id_allowin)begin
            buffer_valid <= 1'b1;
        end
        else if (id_allowin | is_ertn_exc) begin
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
        else if (id_allowin | is_ertn_exc) begin
            buffer <= 32'b0;
        end
    end
    //连接ID
    assign  if_id_bus = {
        if_exc_type, if_pc, if_inst
    };
endmodule