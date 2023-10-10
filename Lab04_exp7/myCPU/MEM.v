//接受读数据存储器
module MEM (
    input           clk,
    input           resetn,
    //与EXE阶段
    output          mem_allowin,
    input           exe_mem_valid,
    input   [102:0] exe_mem_bus,
    //与WB阶段
    output          mem_wb_valid,
    input           wb_allowin,
    output  [101:0] mem_wb_bus,
    //与数据存储器
    input   [ 31:0] data_sram_rdata
);
    //信号定义
    reg             mem_valid;
    wire            mem_ready_go;
    wire    [ 31:0] mem_pc;
    wire    [ 31:0] mem_inst;
    reg     [102:0] exe_mem_bus_vld;
    wire            gr_we;
    wire            res_from_mem;
    wire    [  4:0] dest;
    wire    [ 31:0] alu_result;
    wire    [ 31:0] final_result;

    assign  mem_ready_go = 1'b1;
    assign  mem_wb_valid = mem_ready_go & mem_valid;
    assign  mem_allowin = mem_wb_valid & wb_allowin | ~mem_valid;
    always @(posedge clk ) begin
        if (~resetn) begin
            mem_valid <= 1'b0;
        end
        else if(mem_allowin) begin
            mem_valid <= exe_mem_valid;
        end
    end
    always @(posedge clk ) begin
        if (exe_mem_valid & mem_allowin) begin
            exe_mem_bus_vld <= exe_mem_bus;
        end
    end
    assign {
        gr_we, res_from_mem, dest,
        mem_pc, mem_inst, alu_result
    } = exe_mem_bus_vld;
    assign  final_result = res_from_mem ? data_sram_rdata : alu_result;
    assign  mem_wb_bus = {
        gr_we, mem_pc, mem_inst, final_result, dest
    };
endmodule