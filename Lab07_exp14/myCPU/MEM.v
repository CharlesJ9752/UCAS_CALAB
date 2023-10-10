`include "mycpu.h"
//接受读数据存储器
module MEM (
    input                                   clk,
    input                                   resetn,
    //与EXE阶段
    output                                  mem_allowin,
    input                                   exe_mem_valid,
    input   [`EXE_MEM_BUS_WDTH - 1:0]       exe_mem_bus,
    //与WB阶段
    output                                  mem_wb_valid,
    input                                   wb_allowin,
    output  [`MEM_WB_BUS_WDTH - 1:0]        mem_wb_bus,
    //与数据存储器
    input   [ 31:0]                         data_sram_rdata,
    input                                   data_sram_data_ok,
    //写信号
    output  [`MEM_WR_BUS_WDTH - 1:0]        mem_wr_bus,
    output                                  mem_exc,
    output  [`MEM_CSR_BLK_BUS_WDTH - 1:0]   mem_csr_blk_bus,
    //中断和异常信号
    input                                   wb_exc,
    input                                   ertn_flush,
    output                                  mem_ertn        ,
    output                                  ldst_cancel 
);
//信号定义
    //控制信号
    reg                                     mem_valid;
    wire                                    mem_ready_go;
    //pc和指令
    wire    [ 31:0]                         mem_pc;
    wire    [ 31:0]                         mem_inst;
    //bus
    reg     [`EXE_MEM_BUS_WDTH - 1:0]       exe_mem_bus_vld;
    wire                                    mem_gr_we;
    wire                                    res_from_mem;
    wire    [  4:0]                         mem_dest;
    wire    [ 31:0]                         exe_to_mem_result;
    wire    [ 31:0]                         mem_final_result;
    wire                                    mem_en_bypass;
    wire    [ 31:0]                         mem_ld_result;
    wire                                    mem_inst_ertn;
    //csr
    wire                                    mem_csr_we;
    wire    [13:0]                          mem_csr_waddr;
    wire    [31:0]                          mem_csr_wdata;
    wire    [31:0]                          mem_csr_rdata;
    wire    [31:0]                          mem_csr_wmask;
    //中断和异常标志
    wire    [`NUM_TYPES - 1:0]               exe_exc_type;
    wire    [`NUM_TYPES - 1:0]               mem_exc_type;
    wire                                    ls_cancel;
    wire                                    mem_we;
//控制信号的赋值
    assign  mem_ready_go = (is_load | mem_we) ?  (|mem_exc_type) | ls_cancel | data_sram_data_ok : 1'b1;
    assign  mem_wb_valid = mem_ready_go & mem_valid &  ~is_ertn_exc;
    assign  mem_allowin = mem_ready_go & wb_allowin | ~mem_valid;
    always @(posedge clk ) begin
        if (~resetn) begin
            mem_valid <= 1'b0;
        end else if(mem_allowin) begin
            mem_valid <= exe_mem_valid;
        end
    end
//主bus连接
    always @(posedge clk ) begin
        if (exe_mem_valid & mem_allowin) begin
            exe_mem_bus_vld <= exe_mem_bus;
        end
    end
    assign {mem_csr_we,mem_csr_waddr,mem_csr_wmask,
         mem_csr_wdata,mem_inst_ertn,exe_exc_type,
        mem_gr_we, res_from_mem, mem_dest,
        mem_pc, mem_inst, exe_to_mem_result,ls_cancel,mem_we
    } = exe_mem_bus_vld;
    assign  mem_wb_bus = {mem_csr_we,mem_csr_waddr,
        mem_csr_wmask,mem_csr_wdata,mem_inst_ertn,mem_exc_type,
        mem_gr_we, mem_pc, mem_inst, mem_final_result, mem_dest
    };
//读寄存器
    assign inst_ld_b = mem_inst[31:22] == 10'b0010100000;
    assign inst_ld_h = mem_inst[31:22] == 10'b0010100001;
    assign inst_ld_bu = mem_inst[31:22] == 10'b0010101000;
    assign inst_ld_hu = mem_inst[31:22] == 10'b0010101001;
    assign inst_ld_w = mem_inst[31:22] == 10'b0010100010;
    assign is_load = inst_ld_b | inst_ld_bu | inst_ld_h |inst_ld_hu |inst_ld_w;
    wire    [ 1:0]  vaddr;
    wire    [31:0]  word;
    wire    [15:0]  half;
    wire    [ 7:0]  byte;
    wire    [31:0]  half_xtnd;
    wire    [31:0]  byte_xtnd;
    
    assign  vaddr = exe_to_mem_result[1:0];
    assign  word  = data_sram_rdata;
    assign  half  = vaddr[1] ? word[31:16] : word[15:0];
    assign  byte  = vaddr[1] & vaddr[0] ? word[31:24] :
                    vaddr[1] &~vaddr[0] ? word[23:16] :
                   ~vaddr[1] & vaddr[0] ? word[15: 8] :
                                          word[ 7: 0] ;
    assign  half_xtnd = {32{inst_ld_h}} & {{16{half[15]}}, half} | {32{inst_ld_hu}} & {16'b0, half};
    assign  byte_xtnd = {32{inst_ld_b}} & {{24{byte[ 7]}}, byte} | {32{inst_ld_bu}} & {24'b0, byte};

    assign  mem_ld_result = {32{inst_ld_b | inst_ld_bu}} & byte_xtnd |
                            {32{inst_ld_h | inst_ld_hu}} & half_xtnd |
                            {32{inst_ld_w             }} & word      ;

    assign  mem_final_result =  mem_exc_type[`TYPE_ALE] ?   exe_to_mem_result      ://new added(unsure)
                                res_from_mem            ?   mem_ld_result   : 
                                                            exe_to_mem_result      ;
    assign mem_exc = (|mem_exc_type) & mem_valid;
//阻塞和前递
    assign  mem_en_bypass = mem_valid & mem_gr_we;
    assign  mem_wr_bus = {mem_en_bypass, mem_dest, mem_final_result};
    assign  mem_csr_blk_bus= {mem_csr_we & mem_valid, mem_ertn, mem_csr_waddr};
//中断和异常标志
    assign mem_exc_type = exe_exc_type;
    assign mem_ertn = mem_valid & mem_inst_ertn;
//add
    assign ldst_cancel = mem_exc|mem_ertn;
    assign is_ertn_exc = wb_exc | ertn_flush | exc_reg | ertn_reg;
    reg     exc_reg;
    reg     ertn_reg;
    always @(posedge clk) begin
        if (~resetn) begin
            exc_reg <= 1'b0;
            ertn_reg <= 1'b0;
        end 
        else if (wb_exc) begin
            exc_reg <= 1'b1;
        end 
        else if (ertn_flush) begin
            ertn_reg <= 1'b1;
        end 
        else if (exe_mem_valid & mem_allowin)begin
            exc_reg <= 1'b0;
            ertn_reg <= 1'b0;
        end
    end
    
endmodule