`include "mycpu.h"
`include "csr.h"

module MEM (
    input           clk,
    input           reset,
    output          ms_allowin,
    input           es_to_ms_valid,
    input   [`ES_TO_MS_BUS_WD-1:0]  es_to_ms_bus,
    output          ms_to_ws_valid,
    output  [`MS_TO_WS_BUS_WD-1:0]  ms_to_ws_bus,
    input           ws_allowin,
    input   [31:0]  data_sram_rdata,
    output  [5:0]   ms_block_bus,
    output  [31:0]  ms_forward,
    // EXEC & INT
    input  wb_exc,
    input  wb_ertn,
    output ms_to_es_st_cancel,
    output [`MS_CSR_BLK_BUS_WD-1:0] ms_csr_blk_bus
);
    reg [`ES_TO_MS_BUS_WD-1:0] MEMreg;
    reg ms_valid;
    wire ms_ready_go;
    wire gr_we;
    wire [31:0] ms_pc;
    wire res_from_mem;
    wire [31:0] alu_result;
    wire [4:0] dest;
    wire [31:0] final_result;
    wire [31:0] mem_result;
    //ld type
    wire [4:0] ld_type;
    wire ms_ld_w;
    wire ms_ld_b;
    wire ms_ld_bu;
    wire ms_ld_h;
    wire ms_ld_hu;
    //alu[1:0] type
    wire [1:0] load_op;
    wire [3:0] sel_mem_res;
    //mem_result for different ld types
    wire mem_res_07;
    wire mem_res_15;
    wire mem_res_23;
    wire mem_res_31;
    wire [31:0] mem_res_lhg;//lh,lhu
    wire [31:0] mem_res_lbg;//lb,lbu
    wire [`EXC_NUM-1:0] es_to_ms_exc_flags;
    wire [`EXC_NUM-1:0] ms_exc_flags;
    wire        ms_csr_we;
    wire [13:0] ms_csr_wnum;
    wire [31:0] ms_csr_wmask;
    wire [31:0] ms_csr_wdata;
    wire        ms_inst_ertn;

    //contact
    assign ms_ready_go = 1'b1;
    assign ms_allowin = ms_ready_go&ws_allowin|~ms_valid;
    assign ms_to_ws_valid = ms_valid & ms_ready_go;
    always @(posedge clk) begin
        if(reset)begin
            ms_valid<=1'b0;
        end else if (wb_exc | wb_ertn) begin
            ms_valid <= 1'b0;
        end
        else if (ms_allowin) begin
            ms_valid<=es_to_ms_valid;
        end
    end

    //data 
    always @(posedge clk ) begin
        if (ms_allowin&es_to_ms_valid) begin
            MEMreg<=es_to_ms_bus;
        end
    end
    assign {ms_csr_we,
            ms_csr_wnum,
            ms_csr_wmask,
            ms_csr_wdata,
            ms_inst_ertn,
            es_to_ms_exc_flags,
            ld_type,
            gr_we,
            ms_pc,
            res_from_mem,
            alu_result,
            dest} = MEMreg;
    assign ms_block_bus = {gr_we&ms_valid,dest};
    assign ms_forward = final_result;
    assign ms_to_ws_bus = { ms_csr_we,
                            ms_csr_wnum,
                            ms_csr_wmask,
                            ms_csr_wdata,
                            ms_inst_ertn,
                            ms_exc_flags,
                            gr_we,
                            ms_pc,
                            final_result,
                            dest    
                          };

    // prepare load type
    assign {ms_ld_hu,ms_ld_bu,ms_ld_h,ms_ld_b,ms_ld_w} = ld_type;
    //select mem_result
    assign load_op = alu_result[1:0];
    assign sel_mem_res[0] = (load_op==2'b00);
    assign sel_mem_res[1] = (load_op==2'b01);
    assign sel_mem_res[2] = (load_op==2'b10);
    assign sel_mem_res[3] = (load_op==2'b11);
    
    // prepare sign extend
    assign mem_res_07 = ms_ld_b & data_sram_rdata[ 7];
    assign mem_res_15 = (ms_ld_b | ms_ld_h) & data_sram_rdata[15];
    assign mem_res_23 = ms_ld_b & data_sram_rdata[23];
    assign mem_res_31 = (ms_ld_b | ms_ld_h) & data_sram_rdata[31];
    assign mem_res_lhg = {32{~load_op[1] }} & {{16{mem_res_15}}, data_sram_rdata[15: 0]} | // LH/LHU
                         {32{ load_op[1] }} & {{16{mem_res_31}}, data_sram_rdata[31:16]};
    assign mem_res_lbg = {32{sel_mem_res[0]}} & {{24{mem_res_07}}, data_sram_rdata[ 7: 0]} | // LB/LBU
                         {32{sel_mem_res[1]}} & {{24{mem_res_15}}, data_sram_rdata[15: 8]} |
                         {32{sel_mem_res[2]}} & {{24{mem_res_23}}, data_sram_rdata[23:16]} |
                         {32{sel_mem_res[3]}} & {{24{mem_res_31}}, data_sram_rdata[31:24]};

    //mem_result
    assign mem_result = {32{ms_ld_h | ms_ld_hu}} & mem_res_lhg | // LH/LHU
                        {32{ms_ld_b | ms_ld_bu}} & mem_res_lbg | // LB/LBU
                        {32{ms_ld_w}} & data_sram_rdata; // LW

    assign final_result = ms_exc_flags[`EXC_FLG_ALE] ? alu_result :
                          res_from_mem ? mem_result : alu_result;
    assign ms_to_es_st_cancel = ((|ms_exc_flags) | ms_inst_ertn) & ms_valid;
    assign ms_csr_blk_bus     = {ms_csr_we & ms_valid, ms_inst_ertn & ms_valid, ms_csr_wnum};

    assign ms_exc_flags = es_to_ms_exc_flags;
endmodule