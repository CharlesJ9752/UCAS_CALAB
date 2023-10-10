`include "mycpu.h"
//运行alu，写存储�?
module EXE (
    input                                   clk,
    input                                   resetn,
    //与ID阶段
    output                                  exe_allowin,
    input                                   id_exe_valid,
    input   [`ID_EXE_BUS_WDTH - 1:0]        id_exe_bus,
    //与MEM阶段
    output                                  exe_mem_valid,
    input                                   mem_allowin,
    output  [`EXE_MEM_BUS_WDTH - 1:0]       exe_mem_bus,
    //与数据存储器
    output                                  data_sram_req  ,
    output                                  data_sram_wr   ,
    output [ 1:0]                           data_sram_size ,
    output [31:0]                           data_sram_addr ,
    output [ 3:0]                           data_sram_wstrb,
    output [31:0]                           data_sram_wdata,
    input                                   data_sram_addr_ok,
    //写信�???
    output  [`EXE_WR_BUS_WDTH - 1:0]        exe_wr_bus,
    //csr信号
    output  [`EXE_CSR_BLK_BUS_WDTH - 1:0]   exe_csr_blk_bus,
    //中断和异常信�?
    input                                   flush,
    input                                   mem_exc,
    input                                   mem_ertn,
    input                                   ldst_cancel,

    input                                   csr_crmd_da,
    input                                   csr_crmd_pg,
    input   [ 1:0]                          csr_crmd_plv,
    //mmu
    output  [18:0]                          s1_vppn,
    output                                  s1_va_bit12,
    output  [ 9:0]                          s1_asid,
    input                                   s1_found,
    input   [ 3:0]                          s1_index,
    input   [19:0]                          s1_ppn,
    input   [ 5:0]                          s1_ps,
    input   [ 1:0]                          s1_plv,
    input   [ 1:0]                          s1_mat,
    input                                   s1_d,
    input                                   s1_v,
    output                                  invtlb_valid,
    output  [ 4:0]                          invtlb_op,
    input   [ 9:0]                          csr_asid_asid,
    input   [18:0]                          csr_tlbehi_vppn,
    input                                   csr_dmw0_plv0,
    input                                   csr_dmw0_plv3,
    input  [ 1:0]                           csr_dmw0_mat,
    input  [ 2:0]                           csr_dmw0_pseg,
    input  [ 2:0]                           csr_dmw0_vseg,
    input                                   csr_dmw1_plv0,
    input                                   csr_dmw1_plv3,
    input  [ 1:0]                           csr_dmw1_mat,
    input  [ 2:0]                           csr_dmw1_pseg,
    input  [ 2:0]                           csr_dmw1_vseg
);
//信号定义
    //控制信号
    reg                                 exe_valid;
    wire                                exe_ready_go;
    //pc和指�?
    wire    [ 31:0]                     exe_inst;
    wire    [ 31:0]                     exe_pc;
    //阻塞和前�?
    wire                                exe_en_bypass;
    wire                                exe_en_block;
    //bus通路
    reg     [`ID_EXE_BUS_WDTH - 1:0]    id_exe_bus_vld;
    wire                                exe_gr_we;
    wire                                exe_mem_we;
    wire                                exe_res_from_mem;
    wire    [18:0]                      alu_op;
    wire    [31:0]                      alu_src1;
    wire    [31:0]                      alu_src2;
    wire    [ 4:0]                      exe_dest;
    wire    [31:0]                      exe_rkd_value;
    wire                                exe_inst_ertn;
    wire    [31:0]                      exe_result;  
    wire    [31:0]                      exe_rj_value;
    //csr信号
    wire                                exe_csr_we;
    wire                                exe_csr_re;
    wire [13:0]                         exe_csr_waddr;
    wire [31:0]                         exe_csr_wdata;
    wire [31:0]                         exe_csr_rdata;
    wire [31:0]                         exe_csr_wmask;
    //中断和异常标�?
    wire [`NUM_TYPES - 1:0]              id_exc_type;
    wire [`NUM_TYPES - 1:0]              exe_exc_type;

    /**new added**/
    wire exe_rdcn;
    wire exe_inst_rdcntvh_w;

    /**new added**/

    //控制信号的赋�?
    assign exe_ready_go    = do_mem? data_sram_req&data_sram_addr_ok|ls_cancel: 
                             ((alu_op[15] | alu_op[17]) & div_out_tvalid | 
                             (alu_op[16] | alu_op[18]) & divu_out_tvalid |
                             (~(alu_op[15]|alu_op[16]|alu_op[17]|alu_op[18])));
    assign  exe_mem_valid = ~is_ertn_exc & exe_ready_go & exe_valid ;
    assign  exe_allowin = exe_ready_go & mem_allowin | ~exe_valid;
    always @(posedge clk ) begin
        if (~resetn) begin
            exe_valid <= 1'b0;
        end else  if(exe_allowin) begin
            exe_valid <= id_exe_valid;
        end
    end
//主bus连接
    wire exe_dmw0_hit;
    wire exe_dmw1_hit;
    wire use_tlb;
    wire [31:0] exe_dmw0_paddr;
    wire [31:0] exe_dmw1_paddr;
    wire [31:0] exe_tlb_paddr;
    wire do_mem;
    assign exe_dmw0_hit = alu_result[31:29] == csr_dmw0_vseg&&(csr_crmd_plv==2'd0&&csr_dmw0_plv0||csr_crmd_plv== 2'd3&&csr_dmw0_plv3);
    assign exe_dmw1_hit = alu_result[31:29] == csr_dmw1_vseg&&(csr_crmd_plv==2'd0&&csr_dmw1_plv0||csr_crmd_plv== 2'd3&&csr_dmw1_plv3);
    assign exe_dmw0_paddr = {csr_dmw0_pseg, alu_result[28:0]};
    assign exe_dmw1_paddr = {csr_dmw1_pseg, alu_result[28:0]};
    assign exe_tlb_paddr = s1_ps == 6'd22 ? {s1_ppn[19:10], alu_result[21:0]} : {s1_ppn, alu_result[11:0]};

    assign do_mem = is_load | exe_mem_we;
    assign use_tlb = ~csr_crmd_da & csr_crmd_pg & ~exe_dmw0_hit & ~exe_dmw1_hit;
    wire exe_refetch;
    wire exe_inst_tlbsrch;
    wire exe_inst_tlbrd;
    wire exe_inst_tlbwr;
    wire exe_inst_tlbfill;
    wire exe_inst_invtlb;
    wire [4:0] exe_invtlb_op;
    wire exe_tlbhit;
    wire [3:0] exe_tlbhit_index;
    assign exe_tlbhit = s1_found;
    assign exe_tlbhit_index= s1_index;
    always @(posedge clk ) begin
        if(~resetn)begin
            id_exe_bus_vld <= `ID_EXE_BUS_WDTH'b0;
        end
        else if (id_exe_valid & exe_allowin) begin
            id_exe_bus_vld <= id_exe_bus; 
        end
    end
    assign { 
        exe_refetch, exe_inst_tlbsrch,
        exe_inst_tlbrd, exe_inst_tlbwr,
        exe_inst_tlbfill, exe_inst_invtlb,
        exe_invtlb_op, exe_rj_value, 
        //new add
        exe_rdcn, exe_inst_rdcntvh_w,  
        exe_csr_we, exe_csr_re, exe_csr_waddr, exe_csr_wmask, exe_csr_wdata, exe_csr_rdata,   //112 bits
        exe_inst_ertn, id_exc_type,                                                         //7 bits
        exe_gr_we, exe_mem_we, exe_res_from_mem, 
        alu_op, alu_src1, alu_src2,
        exe_dest, exe_rkd_value, exe_inst, exe_pc
    }=id_exe_bus_vld;
    assign  exe_mem_bus = {
        exe_refetch,exe_inst_tlbsrch,
        exe_inst_tlbrd,exe_inst_tlbwr,
        exe_inst_tlbfill,exe_tlbhit,exe_tlbhit_index,
        //new add
        exe_csr_we,exe_csr_waddr,exe_csr_wmask,
        exe_csr_wdata,exe_inst_ertn,exe_exc_type,
        exe_gr_we, exe_res_from_mem, exe_dest,
        exe_pc, exe_inst, exe_result, ls_cancel, exe_mem_we
    };
//运行alu
    //alu
    wire    [31:0]  alu_result;
    alu my_alu (
        .alu_op(alu_op),
        .alu_src1(alu_src1),
        .alu_src2(alu_src2),
        .alu_result(alu_result)
    );
    //除法�?
    wire    [31:0]  div_src1;//有符号除法被除数
    wire            div_src1_ready;
    wire            div_src1_tvalid;
    reg             div_src1_flag;   

    wire    [31:0]  div_src2;//有符号除法除�?
    wire            div_src2_ready;
    wire            div_src2_tvalid;
    reg             div_src2_flag;

    wire    [63:0]  div_res;//有符号除法结�?
    wire    [31:0]  div_res_hi;
    wire    [31:0]  div_res_lo;
    wire            div_out_tvalid;//有符号除法返回�?�有�?


    wire    [31:0]  divu_src1;//无符号除法被除数
    wire            divu_src1_ready;
    wire            divu_src1_tvalid;
    reg             divu_src1_flag;

    wire    [31:0]  divu_src2;//无符号除法除�?
    wire            divu_src2_ready;
    wire            divu_src2_tvalid;
    reg             divu_src2_flag;

    wire    [63:0]  divu_res;//无符号除法结�?
    wire    [31:0]  divu_res_hi;
    wire    [31:0]  divu_res_lo;
    wire            divu_out_tvalid;//无符号除法返回�?�有�?

    //有符号除�?
    always @(posedge clk ) begin
        if(~resetn) begin
            div_src1_flag <= 1'b0;
        end
        else if (div_src1_tvalid & div_src1_ready) begin
            div_src1_flag <= 1'b1;
        end
        else if (exe_ready_go & mem_allowin) begin
            div_src1_flag <= 1'b0;
        end
    end
    assign div_src1_tvalid = (alu_op[15] | alu_op[17]) & exe_valid & ~div_src1_flag;

    always @(posedge clk ) begin
        if(~resetn) begin
            div_src2_flag <= 1'b0;
        end
        else if (div_src2_tvalid & div_src2_ready) begin
            div_src2_flag <= 1'b1;
        end
        else if (exe_ready_go & mem_allowin) begin
            div_src2_flag <= 1'b0;
        end
    end
    assign div_src2_tvalid = (alu_op[15] | alu_op[17]) & exe_valid & ~div_src2_flag;

    assign div_src1 = alu_src1;
    assign div_src2 = alu_src2;
    my_div my_div (
        .aclk                   (clk),
        .s_axis_dividend_tdata  (div_src1),
        .s_axis_dividend_tready (div_src1_ready),
        .s_axis_dividend_tvalid (div_src1_tvalid),
        .s_axis_divisor_tdata   (div_src2),
        .s_axis_divisor_tready  (div_src2_ready),
        .s_axis_divisor_tvalid  (div_src2_tvalid),
        .m_axis_dout_tdata      (div_res),
        .m_axis_dout_tvalid     (div_out_tvalid)
    );
    assign {div_res_hi, div_res_lo} = div_res;
    //无符号除�?
    always @(posedge clk ) begin
        if(~resetn) begin
            divu_src1_flag <= 1'b0;
        end
        else if (divu_src1_tvalid & divu_src1_ready) begin
            divu_src1_flag <= 1'b1;
        end
        else if (exe_ready_go & mem_allowin) begin
            divu_src1_flag <= 1'b0;
        end
    end
    assign divu_src1_tvalid = (alu_op[16] | alu_op[18]) & exe_valid & ~divu_src1_flag;

    always @(posedge clk ) begin
        if(~resetn) begin
            divu_src2_flag <= 1'b0;
        end
        else if (divu_src2_tvalid & divu_src2_ready) begin
            divu_src2_flag <= 1'b1;
        end
        else if (exe_ready_go & mem_allowin) begin
            divu_src2_flag <= 1'b0;
        end
    end
    assign divu_src2_tvalid = (alu_op[16] | alu_op[18]) & exe_valid & ~divu_src2_flag;
    
    assign divu_src1 = alu_src1;
    assign divu_src2 = alu_src2;
    my_divu my_divu (
        .aclk                   (clk),
        .s_axis_dividend_tdata  (divu_src1),
        .s_axis_dividend_tready (divu_src1_ready),
        .s_axis_dividend_tvalid (divu_src1_tvalid),
        .s_axis_divisor_tdata   (divu_src2),
        .s_axis_divisor_tready  (divu_src2_ready),
        .s_axis_divisor_tvalid  (divu_src2_tvalid),
        .m_axis_dout_tdata      (divu_res),
        .m_axis_dout_tvalid     (divu_out_tvalid)
    );
    assign {divu_res_hi, divu_res_lo} = divu_res;
//中断和异常标�?
    /**new added**/
    assign inst_ld_b = exe_inst[31:22] == 10'b0010100000;
    assign inst_ld_h = exe_inst[31:22] == 10'b0010100001;
    assign inst_ld_bu = exe_inst[31:22] == 10'b0010101000;
    assign inst_ld_hu = exe_inst[31:22] == 10'b0010101001;
    assign inst_ld_w = exe_inst[31:22] == 10'b0010100010;
    assign  exe_exc_type[`TYPE_SYS]=id_exc_type[`TYPE_SYS];
    assign  exe_exc_type[`TYPE_ADEF]=id_exc_type[`TYPE_ADEF];
    assign exe_exc_type[`TYPE_TLBRF] = id_exc_type[`TYPE_TLBRF];
    assign exe_exc_type[`TYPE_PLVF] = id_exc_type[`TYPE_PLVF];
    assign exe_exc_type[`TYPE_PIF ] = id_exc_type[`TYPE_PIF ];
    assign  exe_exc_type[`TYPE_BRK]=id_exc_type[`TYPE_BRK];
    assign  exe_exc_type[`TYPE_INE]=id_exc_type[`TYPE_INE];
    assign  exe_exc_type[`TYPE_INT]=id_exc_type[`TYPE_INT];
    assign  exe_exc_type[`TYPE_ALE]=(exe_res_from_mem | exe_mem_we) & ((inst_ld_h | inst_ld_hu | inst_st_h) & alu_result[0] | (inst_ld_w | inst_st_w) & (|alu_result[1:0]));
    assign exe_exc_type[`TYPE_ADEM] = do_mem&alu_result[31]&(csr_crmd_plv == 2'd3)&~exe_dmw0_hit&~exe_dmw1_hit;
    assign exe_exc_type[`TYPE_TLBRM] = do_mem&use_tlb&~s1_found;
    assign exe_exc_type[`TYPE_PIL]  = is_load&use_tlb & ~s1_v;
    assign exe_exc_type[`TYPE_PIS]  = exe_mem_we&use_tlb& ~s1_v;
    assign exe_exc_type[`TYPE_PME]  = exe_mem_we&use_tlb&~s1_d;
    assign exe_exc_type[`TYPE_PLVM] = do_mem&use_tlb&(csr_crmd_plv>s1_plv);

    /**new added**/
    assign exe_exc = |exe_exc_type & exe_valid; 
    assign exe_ertn = exe_inst_ertn & exe_valid;
//阻塞和前�?
    //regfile
    assign  exe_en_bypass = exe_valid & exe_gr_we;
    assign  exe_en_block = exe_valid & exe_res_from_mem;//in case of load
    assign exe_wr_bus = {
        exe_en_bypass, exe_en_block, exe_dest, exe_result
    };
    //csr
    assign exe_csr_blk_bus = {
        exe_csr_we & exe_valid, exe_ertn, exe_inst_tlbsrch&&exe_valid,exe_csr_waddr
    };
//写存储器
    wire            inst_st_w;
    wire            inst_st_h;
    wire            inst_st_b;

    assign  inst_st_w = exe_inst[31:22] == 10'b0010100110;
    assign  inst_st_h = exe_inst[31:22] == 10'b0010100101;
    assign  inst_st_b = exe_inst[31:22] == 10'b0010100100;

    wire    [ 1:0]  vaddr;
    wire    [ 3:0]  strb;
    wire    [31:0]  wr_data;
    wire            ls_cancel;
    
    assign  vaddr   =   alu_result[1:0];
    assign  strb    =   {4{inst_st_w}} & 4'b1111 |
                        {4{inst_st_h}} & {{2{vaddr[1]}},{2{~vaddr[1]}}} |
                        {4{inst_st_b}} & {vaddr[1]&vaddr[0],vaddr[1]&~vaddr[0],~vaddr[1]&vaddr[0],~vaddr[1]&~vaddr[0]};
    assign  wr_data =   {32{inst_st_w}} & exe_rkd_value |
                        {32{inst_st_h}} & {2{exe_rkd_value[15:0]}} |
                        {32{inst_st_b}} & {4{exe_rkd_value[7:0]}};
    assign  ls_cancel   = is_ertn_exc | ldst_cancel | (|exe_exc_type);
    assign  data_sram_req = (is_load || exe_mem_we) && mem_allowin && ~is_ertn_exc&& exe_valid && ~ls_cancel;
    assign  data_sram_wr = exe_valid & exe_mem_we;
    assign  data_sram_wstrb = inst_st_b ? (4'b0001<<alu_result[1:0]) : inst_st_h ? (4'b0011<<{alu_result[1],1'b0}) : inst_st_w ? 4'b1111  : 4'b0;
    assign  data_sram_size = inst_st_h ? 2'h1 : inst_st_w ? 2'h2 : 2'h0;                
    assign  data_sram_addr = csr_crmd_da & ~csr_crmd_pg? alu_result :exe_dmw0_hit ? exe_dmw0_paddr : exe_dmw1_hit ? exe_dmw1_paddr :exe_tlb_paddr;
    assign  data_sram_wdata = wr_data;
/**new added**/
//counter
reg [63:0] countor;
always @ (posedge clk) begin
    if (~resetn)
            countor <= 64'b0;
    else
        countor <= countor + 64'b1;
end
/**new added**/
//exe阶段�?终结�?

            //可能有问�?
    assign  exe_result =    {exe_rdcn& exe_inst_rdcntvh_w}?countor[63:32] :/**new added**/
                            {exe_rdcn&~exe_inst_rdcntvh_w}?countor[31: 0] :/**new added**/
                            exe_csr_re ? exe_csr_rdata:
                            alu_op[15] ? div_res_hi :
                            alu_op[17] ? div_res_lo :
                            alu_op[16] ? divu_res_hi :
                            alu_op[18] ? divu_res_lo :
                                         alu_result;
//add, exp14
    reg  flush_r;
    wire is_load;
    assign is_ertn_exc = (flush|flush_r);
    assign is_load = inst_ld_b | inst_ld_h | inst_ld_bu | inst_ld_hu | inst_ld_w;
    always @(posedge clk ) begin
        if (~resetn)begin
            flush_r<=1'b0;
        end
        else if (flush)begin
            flush_r<=1'b1;
        end
        else if(id_exe_valid&&exe_allowin)begin
            flush_r<=1'b0;
        end
    end
//add, exp18
    assign {s1_vppn,s1_va_bit12} = do_mem   ? alu_result[31:12] : invtlb_valid ?  exe_rkd_value[31:12] :{csr_tlbehi_vppn, 1'b0};
    assign s1_asid = invtlb_valid ? exe_rj_value[ 9: 0] : csr_asid_asid;
    assign invtlb_valid = exe_inst_invtlb;
    assign invtlb_op = exe_invtlb_op;
endmodule