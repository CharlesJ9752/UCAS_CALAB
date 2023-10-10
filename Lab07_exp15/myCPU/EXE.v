`include "mycpu.h"
//运行alu，写存储器
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
    //写信�??
    output  [`EXE_WR_BUS_WDTH - 1:0]        exe_wr_bus,
    //csr信号
    output  [`EXE_CSR_BLK_BUS_WDTH - 1:0]   exe_csr_blk_bus,
    //中断和异常信号
    input                                   wb_exc,
    input                                   ertn_flush,
    input                                   mem_exc,
    input                                   mem_ertn,
    input                                   ldst_cancel
);
//信号定义
    //控制信号
    reg                                 exe_valid;
    wire                                exe_ready_go;
    //pc和指令
    wire    [ 31:0]                     exe_inst;
    wire    [ 31:0]                     exe_pc;
    //阻塞和前递
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
    //csr信号
    wire                                exe_csr_we;
    wire                                exe_csr_re;
    wire [13:0]                         exe_csr_waddr;
    wire [31:0]                         exe_csr_wdata;
    wire [31:0]                         exe_csr_rdata;
    wire [31:0]                         exe_csr_wmask;
    //中断和异常标志
    wire [`NUM_TYPES - 1:0]              id_exc_type;
    wire [`NUM_TYPES - 1:0]              exe_exc_type;

    /**new added**/
    wire exe_rdcn;
    wire exe_inst_rdcntvh_w;

    /**new added**/


    //控制信号的赋值
    assign exe_ready_go    = (is_load || exe_mem_we)? (((data_sram_req & data_sram_addr_ok) | ls_cancel) || addr_ok_reg) : 
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
    always @(posedge clk ) begin
        if(~resetn)begin
            id_exe_bus_vld <= `ID_EXE_BUS_WDTH'b0;
        end
        else if (id_exe_valid & exe_allowin) begin
            id_exe_bus_vld <= id_exe_bus; 
        end
    end
    assign { 
        exe_rdcn, exe_inst_rdcntvh_w,  //new added
        exe_csr_we, exe_csr_re, exe_csr_waddr, exe_csr_wmask, exe_csr_wdata, exe_csr_rdata,   //112 bits
        exe_inst_ertn, id_exc_type,                                                         //7 bits
        exe_gr_we, exe_mem_we, exe_res_from_mem, 
        alu_op, alu_src1, alu_src2,
        exe_dest, exe_rkd_value, exe_inst, exe_pc
    }=id_exe_bus_vld;
    assign  exe_mem_bus = {
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
    //除法器
    wire    [31:0]  div_src1;//有符号除法被除数
    wire            div_src1_ready;
    wire            div_src1_tvalid;
    reg             div_src1_flag;   

    wire    [31:0]  div_src2;//有符号除法除数
    wire            div_src2_ready;
    wire            div_src2_tvalid;
    reg             div_src2_flag;

    wire    [63:0]  div_res;//有符号除法结果
    wire    [31:0]  div_res_hi;
    wire    [31:0]  div_res_lo;
    wire            div_out_tvalid;//有符号除法返回值有效


    wire    [31:0]  divu_src1;//无符号除法被除数
    wire            divu_src1_ready;
    wire            divu_src1_tvalid;
    reg             divu_src1_flag;

    wire    [31:0]  divu_src2;//无符号除法除数
    wire            divu_src2_ready;
    wire            divu_src2_tvalid;
    reg             divu_src2_flag;

    wire    [63:0]  divu_res;//无符号除法结果
    wire    [31:0]  divu_res_hi;
    wire    [31:0]  divu_res_lo;
    wire            divu_out_tvalid;//无符号除法返回值有效

    //有符号除法
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
    //无符号除法
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
//中断和异常标志
    /**new added**/
    assign inst_ld_b = exe_inst[31:22] == 10'b0010100000;
    assign inst_ld_h = exe_inst[31:22] == 10'b0010100001;
    assign inst_ld_bu = exe_inst[31:22] == 10'b0010101000;
    assign inst_ld_hu = exe_inst[31:22] == 10'b0010101001;
    assign inst_ld_w = exe_inst[31:22] == 10'b0010100010;
    assign  exe_exc_type[`TYPE_SYS]=id_exc_type[`TYPE_SYS];
    assign  exe_exc_type[`TYPE_ADEF]=id_exc_type[`TYPE_ADEF];
    assign  exe_exc_type[`TYPE_ALE]=exe_valid & (exe_res_from_mem | exe_mem_we) & ((inst_ld_h | inst_ld_hu | inst_st_h) & alu_result[0] | (inst_ld_w | inst_st_w) & (|alu_result[1:0]));
    assign  exe_exc_type[`TYPE_BRK]=id_exc_type[`TYPE_BRK];
    assign  exe_exc_type[`TYPE_INE]=id_exc_type[`TYPE_INE];
    assign  exe_exc_type[`TYPE_INT]=id_exc_type[`TYPE_INT];
    /**new added**/
    assign exe_exc = |exe_exc_type & exe_valid; 
    assign exe_ertn = exe_inst_ertn & exe_valid;
//阻塞和前递
    //regfile
    assign  exe_en_bypass = exe_valid & exe_gr_we;
    assign  exe_en_block = exe_valid & exe_res_from_mem;//in case of load
    assign exe_wr_bus = {
        exe_en_bypass, exe_en_block, exe_dest, exe_result
    };
    //csr
    assign exe_csr_blk_bus = {
        exe_csr_we & exe_valid, exe_ertn, exe_csr_waddr
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
    assign  data_sram_req = (is_load || exe_mem_we) && exe_valid && ~is_ertn_exc && ~addr_ok_reg && ~ls_cancel;
    assign  data_sram_wr = exe_valid & exe_mem_we;
    assign  data_sram_wstrb = inst_st_b ? (4'b0001<<alu_result[1:0]) : inst_st_h ? (4'b0011<<{alu_result[1],1'b0}) :
                              inst_st_w ? 4'b1111                    : 4'b0;
    assign  data_sram_size = inst_st_h ? 2'h1 : inst_st_w ? 2'h2 : 2'h0;                
    assign  data_sram_addr = alu_result; //assign  data_sram_addr = {alu_result};
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
//exe阶段最终结果
    assign  exe_result =    {exe_rdcn &  exe_inst_rdcntvh_w} ? countor[63:32] :/**new added**/
                            {exe_rdcn & ~exe_inst_rdcntvh_w} ? countor[31: 0] :/**new added**/
                            exe_csr_re ? exe_csr_rdata:
                            alu_op[15] ? div_res_hi :
                            alu_op[17] ? div_res_lo :
                            alu_op[16] ? divu_res_hi :
                            alu_op[18] ? divu_res_lo :
                                         alu_result;
//add, exp14
    reg addr_ok_reg;
    reg exc_reg;
    reg ertn_reg;
    wire is_load;
    assign is_ertn_exc = (wb_exc | ertn_flush | exc_reg | ertn_reg);
    assign is_load = inst_ld_b | inst_ld_h | inst_ld_bu | inst_ld_hu | inst_ld_w;
    always @(posedge clk) begin
        if(~resetn) begin
            addr_ok_reg <= 1'b0;
        end 
        else if(data_sram_addr_ok & data_sram_req & ~mem_allowin) begin
            addr_ok_reg <= 1'b1;
        end 
        else if(mem_allowin) begin
            addr_ok_reg <= 1'b0;
        end
    end
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
        else if (id_exe_valid & exe_allowin)begin
            exc_reg <= 1'b0;
            ertn_reg <= 1'b0;
        end 
    end
    
endmodule