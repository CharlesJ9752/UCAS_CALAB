//运行alu，写存储器
module EXE (
    input           clk,
    input           resetn,
    //与ID阶段
    output          exe_allowin,
    input           id_exe_valid,
    input   [179:0] id_exe_bus,
    //与MEM阶段
    output          exe_mem_valid,
    input           mem_allowin,
    output  [102:0] exe_mem_bus,
    //与数据存储器
    output          data_sram_en,
    output  [ 3:0]  data_sram_we,
    output  [31:0]  data_sram_addr,
    output  [31:0]  data_sram_wdata,
    //写信号
    output  [ 5:0]  exe_wr_bus
);
    //信号定义
    reg             exe_valid;
    wire            exe_ready_go;
    wire    [ 31:0] exe_inst;
    wire    [ 31:0] exe_pc;
    reg     [179:0] id_exe_bus_vld;
    
    assign  exe_ready_go = 1'b1;
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
    wire    [11:0]  alu_op;
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
        exe_pc, exe_inst, alu_result
    };
    //写信号
    wire            to_id_exe_gr_we;
    wire    [4:0]   to_id_exe_dest;
    assign  {to_id_exe_gr_we, to_id_exe_dest} = {{exe_valid & exe_gr_we}, exe_dest};
    assign  exe_wr_bus = {
        to_id_exe_gr_we, to_id_exe_dest
    };
endmodule