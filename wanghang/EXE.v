`include "mycpu.h"
`include "csr.h"

module EXE (
    input           clk,
    input           reset,
    output          es_allowin,
    input           ds_to_es_valid,
    input   [`DS_TO_ES_BUS_WD-1:0] ds_to_es_bus,
    output          es_to_ms_valid,
    output  [`ES_TO_MS_BUS_WD-1:0]  es_to_ms_bus,
    input           ms_allowin,
    
    // data sram interface
    output                         data_sram_req  ,
    output                         data_sram_wr   ,
    output [ 1:0]                  data_sram_size ,
    output [31:0]                  data_sram_addr ,
    output [ 3:0]                  data_sram_wstrb,
    output [31:0]                  data_sram_wdata,
    input                          data_sram_addr_ok,

    output  [6:0]   es_block_bus,
    output  [31:0]  es_forward,
    // EXC & INT
    input  wb_exc,
    input  wb_ertn,
    input ms_to_es_ls_cancel,
    // block for csr
    output [`ES_CSR_BLK_BUS_WD-1:0] es_csr_blk_bus
);
    reg        wb_exc_r;
    reg        wb_ertn_r;
    reg [`DS_TO_ES_BUS_WD-1:0] EXEreg;
    reg es_valid;
    wire es_ready_go;
    wire [18:0] alu_op;
    wire [31:0] alu_src1;
    wire [31:0] alu_src2;
    wire [31:0] rkd_value;
    wire gr_we;
    wire mem_we;
    wire [31:0] es_pc;
    wire res_from_mem;
    wire [4:0] dest;
    wire [31:0] alu_result;
    wire [31:0] final_result;

    wire [4:0] ld_type;
    wire [2:0] st_type;
    wire [31:0]store_data;
    wire ls_cancel;
    wire is_half;
    wire is_word;
    // CSR
    wire [`EXC_NUM - 1:0] es_exc_flags;
    wire [`EXC_NUM - 1:0] ds_to_es_exc_flags;
    wire        es_csr_we;
    wire        es_csr_re;
    wire [13:0] es_csr_wnum;
    wire [31:0] es_csr_wdata;
    wire [31:0] es_csr_rdata;
    wire [31:0] es_csr_wmask;
    // timer
    wire es_rdcn_en;
    wire es_rdcn_sel;
    reg [63:0] stable_cnter;

    reg es_addr_ok_r;

    //contact
    assign es_ready_go= ((|ld_type) || mem_we) ? 
                        (((data_sram_req & data_sram_addr_ok) | ls_cancel) || es_addr_ok_r) : (~(is_div & ~div_ready));
    assign es_allowin = es_ready_go & ms_allowin | ~es_valid;
    assign es_to_ms_valid =  es_valid & es_ready_go & (~(wb_exc | wb_ertn | wb_exc_r | wb_ertn_r));
    // from id
    always @(posedge clk) begin
        if (reset) begin
            es_valid<=1'b0;
        end
        else if(es_allowin) begin
            es_valid<=ds_to_es_valid;
        end
    end
    //data
    always @(posedge clk) begin
        if(es_allowin&ds_to_es_valid)begin
            EXEreg<=ds_to_es_bus;
        end
    end

    always @(posedge clk) begin
        if(reset) begin
            es_addr_ok_r <= 1'b0;
        end else if(data_sram_addr_ok && data_sram_req && !ms_allowin) begin
            es_addr_ok_r <= 1'b1;
        end else if(ms_allowin) begin
            es_addr_ok_r <= 1'b0;
        end
    end
// exception
    always @(posedge clk) begin
        if (reset) begin
            wb_exc_r <= 1'b0;
            wb_ertn_r <= 1'b0;
        end else if (wb_exc) begin
            wb_exc_r <= 1'b1;
        end else if (wb_ertn) begin
            wb_ertn_r <= 1'b1;
        end else if (ds_to_es_valid & es_allowin)begin
            wb_exc_r <= 1'b0;
            wb_ertn_r <= 1'b0;
        end 
    end

    assign {es_rdcn_en,
            es_rdcn_sel,
            es_csr_we,
            es_csr_re,
            es_csr_wnum,
            es_csr_wmask,
            es_csr_wdata,
            es_csr_rdata,
            es_inst_ertn, 
            ds_to_es_exc_flags,
            st_type,
            ld_type,
            alu_op,
            alu_src1,
            alu_src2,
            rkd_value,
            gr_we,
            mem_we,
            es_pc,
            res_from_mem,
            dest} = EXEreg;
    assign  es_to_ms_bus = {es_csr_we   ,
                            es_csr_wnum ,
                            es_csr_wmask,
                            es_csr_wdata,
                            es_inst_ertn,
                            es_exc_flags,
                            ls_cancel   , // 73
                            ld_type     , // 76:72
                            mem_we      , // 71
                            gr_we,        // 70
                            es_pc,        // 69:38
                            res_from_mem, // 37
                            final_result, // 36:5
                            dest};        // 4:0
    assign es_block_bus = {gr_we&es_valid,res_from_mem & es_valid,dest};
    assign es_forward = final_result;
    assign data_sram_req   = ((|ld_type) || mem_we) && es_valid && ~(wb_exc | wb_ertn | wb_exc_r | wb_ertn_r) && !es_addr_ok_r && ~ls_cancel;
    assign data_sram_wr    = es_valid && mem_we;
    assign data_sram_size  = st_type[1] ? 2'h1     : // h
                             st_type[0] ? 2'h2 : 2'h0;   
    assign data_sram_wstrb = ~data_sram_wr   ? 4'h0                               :
                             st_type[2] ? (4'h1 <<  alu_result[1:0])      : // b
                             st_type[1] ? (4'h3 << {alu_result[1], 1'b0}) : // h
                             st_type[0] ? 4'hf : 4'h0;    
    assign  data_sram_addr = alu_result;
    assign  data_sram_wdata = store_data;

    assign store_data = st_type[2] ? {4{rkd_value[ 7:0]}} :  // b
                        st_type[1] ? {2{rkd_value[15:0]}} :  rkd_value[31:0]; //h|w
    
    assign ls_cancel = (wb_exc | wb_ertn | wb_exc_r | wb_ertn_r) | ms_to_es_ls_cancel | (|es_exc_flags);

    assign is_half = st_type[1] | ld_type[2] | ld_type[4];
    assign is_word = st_type[0] | ld_type[0];
    assign final_result = {es_rdcn_en &  es_rdcn_sel} ? stable_cnter[63:32] :
                          {es_rdcn_en & ~es_rdcn_sel} ? stable_cnter[31: 0] :
                           es_csr_re ? es_csr_rdata : alu_result;
    alu ex_alu(
        .clk(clk),
        .rst(reset),
        .alu_op(alu_op),
        .alu_src1(alu_src1),
        .alu_src2(alu_src2),
        .alu_result(alu_result),
        .es_valid(es_valid),
        .is_div(is_div),
        .div_ready(div_ready),
        .wb_exc(wb_exc),
        .wb_ertn(wb_ertn)
    );
    
    // update exec list
    assign es_exc_flags[`EXC_FLG_SYS ] = ds_to_es_exc_flags[`EXC_FLG_SYS ];
    assign es_exc_flags[`EXC_FLG_ADEF] = ds_to_es_exc_flags[`EXC_FLG_ADEF];
    assign es_exc_flags[`EXC_FLG_ALE ] = es_valid & (res_from_mem | mem_we) &
                                        (is_half & alu_result[0] | is_word & (|alu_result[1:0]));
    assign es_exc_flags[`EXC_FLG_BRK ] = ds_to_es_exc_flags[`EXC_FLG_BRK ];
    assign es_exc_flags[`EXC_FLG_INE ] = ds_to_es_exc_flags[`EXC_FLG_INE ];
    assign es_exc_flags[`EXC_FLG_INT ] = ds_to_es_exc_flags[`EXC_FLG_INT ];
    
    assign es_csr_blk_bus = {es_csr_we & es_valid, es_inst_ertn & es_valid, es_csr_wnum};

    always @ (posedge clk) begin
        if (reset) begin
            stable_cnter <= 64'b0;
        end else begin
            stable_cnter <= stable_cnter + 64'd1;
        end
    end

endmodule