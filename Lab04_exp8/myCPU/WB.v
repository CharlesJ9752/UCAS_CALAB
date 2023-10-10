//写回寄存器
module WB (
    input           clk,
    input           resetn,
    //与MEM阶段
    output          wb_allowin,
    input           mem_wb_valid,
    input   [101:0] mem_wb_bus,
    //与ID阶段
    output  [ 37:0] wb_id_bus,
    //debug信号
    output  [ 31:0] debug_wb_pc,
    output  [  3:0] debug_wb_rf_we,
    output  [  4:0] debug_wb_rf_wnum,
    output  [ 31:0] debug_wb_rf_wdata,
    //写信号
    output  [ 5:0]  wb_wr_bus
);
    //信号定义
    reg             wb_valid;
    reg     [101:0] mem_wb_bus_vld;
    wire            wb_ready_go;
    wire            wb_gr_we;
    wire            rf_we;
    wire    [ 31:0] wb_pc;
    wire    [ 31:0] wb_inst;
    wire    [ 31:0] wb_final_result;
    wire    [  4:0] rf_waddr;
    wire    [ 31:0] rf_wdata;
    wire    [  4:0] wb_dest;
    assign wb_ready_go = 1'b1;
    assign wb_allowin = wb_ready_go | ~wb_valid;
    always @(posedge clk ) begin
        if (~resetn) begin
            wb_valid <= 1'b0;
        end
        else if (wb_allowin) begin
            wb_valid <= mem_wb_valid;
        end
    end
    always @(posedge clk ) begin
        if (mem_wb_valid & wb_allowin) begin
            mem_wb_bus_vld <= mem_wb_bus;
        end
    end
    assign  {
        wb_gr_we, wb_pc, wb_inst, wb_final_result, wb_dest
    } = mem_wb_bus_vld;
    assign  rf_we = wb_valid & wb_gr_we;
    assign  rf_waddr = wb_dest; 
    assign  rf_wdata = wb_final_result;
    assign  wb_id_bus = {
        rf_we, rf_waddr, rf_wdata
    };
    assign  debug_wb_pc = wb_pc;
    assign  debug_wb_rf_we = {4{rf_we}};
    assign  debug_wb_rf_wnum = rf_waddr;
    assign  debug_wb_rf_wdata = wb_final_result;
    //写信号
    wire            to_id_wb_gr_we;
    wire    [4:0]   to_id_wb_dest;
    assign  {to_id_wb_gr_we, to_id_wb_dest} = {{wb_valid & wb_gr_we}, wb_dest};
    assign  wb_wr_bus = {
        to_id_wb_gr_we, to_id_wb_dest
    };
endmodule