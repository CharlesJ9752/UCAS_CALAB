//运行alu，写存储�??
module EXE (
    input           clk,
    input           resetn,
    //与ID阶段
    output          exe_allowin,
    input           id_exe_valid,
    input   [186:0] id_exe_bus,
    //与MEM阶段
    output          exe_mem_valid,
    input           mem_allowin,
    output  [102:0] exe_mem_bus,
    //与数据存储器
    output          data_sram_en,
    output  [ 3:0]  data_sram_we,
    output  [31:0]  data_sram_addr,
    output  [31:0]  data_sram_wdata,
    //写信�??
    output  [ 38:0]  exe_wr_bus
);
    //信号定义
    reg             exe_valid;
    wire            exe_ready_go;
    wire    [ 31:0] exe_inst;
    wire    [ 31:0] exe_pc;
    reg     [186:0] id_exe_bus_vld;
    wire            exe_en_bypass;
    wire            exe_en_block;
    assign exe_ready_go    = (alu_op[15] | alu_op[17]) & div_out_tvalid | 
                             (alu_op[16] | alu_op[18]) & divu_out_tvalid |
                             (~(alu_op[15]|alu_op[16]|alu_op[17]|alu_op[18]));
    assign  exe_mem_valid = exe_ready_go & exe_valid;
    assign  exe_allowin = exe_mem_valid & mem_allowin | ~exe_valid;
    always @(posedge clk ) begin
        if (~resetn) begin
            exe_valid <= 1'b0;
        end
        else if(exe_allowin) begin
            exe_valid <= id_exe_valid;
        end
    end
    always @(posedge clk ) begin
        if (id_exe_valid & exe_allowin) begin
            id_exe_bus_vld <= id_exe_bus; 
        end
    end
    //接bus
    wire            exe_gr_we;
    wire            exe_mem_we;
    wire            exe_res_from_mem;
    wire    [18:0]  alu_op;
    wire    [31:0]  alu_src1;
    wire    [31:0]  alu_src2;
    wire    [ 4:0]  exe_dest;
    wire    [31:0]  exe_rkd_value;
    assign {
        exe_gr_we, exe_mem_we, exe_res_from_mem,
        alu_op, alu_src1, alu_src2,
        exe_dest, exe_rkd_value, exe_inst, exe_pc
    } = id_exe_bus_vld;
    //运行alu
    wire    [31:0]  alu_result;
    wire    [31:0]  exe_result;
    alu my_alu (
        .alu_op(alu_op),
        .alu_src1(alu_src1),
        .alu_src2(alu_src2),
        .alu_result(alu_result)
    );
    //与数据存储器
    wire            inst_st_w;
    wire            inst_st_h;
    wire            inst_st_b;

    assign  inst_st_w = exe_inst[31:22] == 10'b0010100110;
    assign  inst_st_h = exe_inst[31:22] == 10'b0010100101;
    assign  inst_st_b = exe_inst[31:22] == 10'b0010100100;

    wire    [ 1:0]  vaddr;
    wire    [ 3:0]  strb;
    wire    [31:0]  wr_data;
    
    assign  vaddr   =   alu_result[1:0];
    assign  strb    =   {4{inst_st_w}} & 4'b1111 |
                        {4{inst_st_h}} & {{2{vaddr[1]}},{2{~vaddr[1]}}} |
                        {4{inst_st_b}} & {vaddr[1]&vaddr[0],vaddr[1]&~vaddr[0],~vaddr[1]&vaddr[0],~vaddr[1]&~vaddr[0]};
    assign  wr_data =   {32{inst_st_w}} & exe_rkd_value |
                        {32{inst_st_h}} & {2{exe_rkd_value[15:0]}} |
                        {32{inst_st_b}} & {4{exe_rkd_value[7:0]}};

    assign  data_sram_en = 1'b1;
    assign  data_sram_we = {4{exe_mem_we}} & strb;
    assign  data_sram_addr = {alu_result[31:2],2'b00}; //assign  data_sram_addr = {alu_result};
    assign  data_sram_wdata = wr_data;
    assign  exe_mem_bus = {
        exe_gr_we, exe_res_from_mem, exe_dest,
        exe_pc, exe_inst, exe_result
    };

    //前递和阻塞
    assign  exe_en_bypass = exe_valid & exe_gr_we;
    assign  exe_en_block = exe_valid & exe_res_from_mem;//in case of load
    assign exe_wr_bus = {
        exe_en_bypass, exe_en_block, exe_dest, exe_result
    };

  
//做除法
    
    //信号定义
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

    assign  exe_result =    alu_op[15] ? div_res_hi :
                            alu_op[17] ? div_res_lo :
                            alu_op[16] ? divu_res_hi :
                            alu_op[18] ? divu_res_lo :
                                         alu_result;

endmodule