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
    output  [31:0]  data_sram_wdata
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
    wire            gr_we;
    wire            mem_we;
    wire            res_from_mem;
    wire    [11:0]  alu_op;
    wire    [31:0]  alu_src1;
    wire    [31:0]  alu_src2;
    wire    [ 4:0]  dest;
    wire    [31:0]  rkd_value;
    assign {
        gr_we, mem_we, res_from_mem,
        alu_op, alu_src1, alu_src2,
        dest, rkd_value, exe_inst, exe_pc
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
    assign  data_sram_we = {4{mem_we}};
    assign  data_sram_addr = alu_result;
    assign  data_sram_wdata = rkd_value;
    assign exe_mem_bus = {
        gr_we, res_from_mem, dest,
        exe_pc, exe_inst, alu_result
    };
endmodule