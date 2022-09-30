//运行alu，写存储�?
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
    //写信�?
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
    assign exe_ready_go    = 
    (alu_op[15] || alu_op[17])     ? signed_dout_tvalid :
    (alu_op[16] || alu_op[18])    ? unsigned_dout_tvalid :
    1'b1;
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
    assign  data_sram_en = 1'b1;
    assign  data_sram_we = {4{exe_mem_we}};
    assign  data_sram_addr = alu_result;
    assign  data_sram_wdata = exe_rkd_value;
    assign  exe_mem_bus = {
        exe_gr_we, exe_res_from_mem, exe_dest,
        exe_pc, exe_inst, exe_result
    };
    //写信�?
    assign  exe_en_bypass = exe_valid & exe_gr_we;
    assign  exe_en_block = exe_valid & exe_res_from_mem;//in case of load
    assign exe_wr_bus = {
        exe_en_bypass, exe_en_block, exe_dest, exe_result
    };
    
//���ó���IP
assign exe_result=(alu_op[15])? signed_divider_res[63:32]:   
                   (alu_op[16])? unsigned_divider_res[63:32]:
                   (alu_op[17])? signed_divider_res[31:0]:   
                   (alu_op[18])? unsigned_divider_res[31:0]:alu_result;
                   
                   
wire [31:0] divider_dividend;
wire [31:0] divider_divisor;
wire [63:0] unsigned_divider_res;
wire [63:0] signed_divider_res;
assign divider_dividend = alu_src1;
assign divider_divisor  = alu_src2;

wire unsigned_dividend_tready;
wire unsigned_dividend_tvalid;
wire unsigned_divisor_tready;
wire unsigned_divisor_tvalid;
wire unsigned_dout_tvalid;

wire signed_dividend_tready;
wire signed_dividend_tvalid;
wire signed_divisor_tready;
wire signed_divisor_tvalid;
wire signed_dout_tvalid;

my_divu u_unsigned_divider (
    .aclk                   (clk),
    .s_axis_dividend_tdata  (divider_dividend),
    .s_axis_dividend_tready (unsigned_dividend_tready),
    .s_axis_dividend_tvalid (unsigned_dividend_tvalid),
    .s_axis_divisor_tdata   (divider_divisor),
    .s_axis_divisor_tready  (unsigned_divisor_tready),
    .s_axis_divisor_tvalid  (unsigned_divisor_tvalid),
    .m_axis_dout_tdata      (unsigned_divider_res),
    .m_axis_dout_tvalid     (unsigned_dout_tvalid)
);

my_div u_signed_divider (
    .aclk                   (clk),
    .s_axis_dividend_tdata  (divider_dividend),
    .s_axis_dividend_tready (signed_dividend_tready),
    .s_axis_dividend_tvalid (signed_dividend_tvalid),
    .s_axis_divisor_tdata   (divider_divisor),
    .s_axis_divisor_tready  (signed_divisor_tready),
    .s_axis_divisor_tvalid  (signed_divisor_tvalid),
    .m_axis_dout_tdata      (signed_divider_res),
    .m_axis_dout_tvalid     (signed_dout_tvalid)
);
    
reg  unsigned_dividend_sent;
reg  unsigned_divisor_sent;

assign unsigned_dividend_tvalid = exe_valid && (alu_op[16] || alu_op[18]) && !unsigned_dividend_sent;
assign unsigned_divisor_tvalid = exe_valid && (alu_op[16] || alu_op[18]) && !unsigned_divisor_sent;

always @ (posedge clk) begin
    if (!resetn) begin
        unsigned_dividend_sent <= 1'b0;
    end else if (unsigned_dividend_tready && unsigned_dividend_tvalid) begin
        unsigned_dividend_sent <= 1'b1;
    end else if (exe_ready_go && mem_allowin) begin
        unsigned_dividend_sent <= 1'b0;
    end
    
    if (!resetn) begin
        unsigned_divisor_sent <= 1'b0;
    end else if (unsigned_divisor_tready && unsigned_divisor_tvalid) begin
        unsigned_divisor_sent <= 1'b1;
    end else if (exe_ready_go && mem_allowin) begin
        unsigned_divisor_sent <= 1'b0;
    end
end

reg  signed_dividend_sent;
reg  signed_divisor_sent;

assign signed_dividend_tvalid = exe_valid && (alu_op[15] || alu_op[17]) && !signed_dividend_sent;
assign signed_divisor_tvalid = exe_valid && (alu_op[15] || alu_op[17]) && !signed_divisor_sent;

always @ (posedge clk) begin
    if (!resetn) begin
        signed_dividend_sent <= 1'b0;
    end else if (signed_dividend_tready && signed_dividend_tvalid) begin
        signed_dividend_sent <= 1'b1;
    end else if (exe_ready_go && mem_allowin) begin
        signed_dividend_sent <= 1'b0;
    end
    
    if (!resetn) begin
        signed_divisor_sent <= 1'b0;
    end else if (signed_divisor_tready && signed_divisor_tvalid) begin
        signed_divisor_sent <= 1'b1;
    end else if (exe_ready_go && mem_allowin) begin
        signed_divisor_sent <= 1'b0;
    end

end

    
    
    
    
endmodule