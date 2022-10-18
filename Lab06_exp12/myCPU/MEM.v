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
    input   [ 31:0] data_sram_rdata,
    //写信号
    output  [ 37:0] mem_wr_bus
);
    //信号定义
    reg             mem_valid;
    wire            mem_ready_go;
    wire    [ 31:0] mem_pc;
    wire    [ 31:0] mem_inst;
    reg     [102:0] exe_mem_bus_vld;
    wire            mem_gr_we;
    wire            res_from_mem;
    wire    [  4:0] mem_dest;
    wire    [ 31:0] alu_result;
    wire    [ 31:0] mem_final_result;
    wire            mem_en_bypass;
    wire    [ 31:0] mem_ld_result;

    //load类型
    assign inst_ld_b = mem_inst[31:22] == 10'b0010100000;
    assign inst_ld_h = mem_inst[31:22] == 10'b0010100001;
    assign inst_ld_bu = mem_inst[31:22] == 10'b0010101000;
    assign inst_ld_hu = mem_inst[31:22] == 10'b0010101001;
    assign inst_ld_w = mem_inst[31:22] == 10'b0010100010;

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
        mem_gr_we, res_from_mem, mem_dest,
        mem_pc, mem_inst, alu_result
    } = exe_mem_bus_vld;

    //处理load的值
    wire    [ 1:0]  vaddr;
    wire    [31:0]  word;
    wire    [15:0]  half;
    wire    [ 7:0]  byte;
    wire    [31:0]  half_xtnd;
    wire    [31:0]  byte_xtnd;
    
    assign  vaddr = alu_result[1:0];
    assign  word  = data_sram_rdata;
    assign  half  = vaddr[1] ? word[31:16] : word[15:0];
    assign  byte  = vaddr[1] & vaddr[0] ? word[31:24] :
                    vaddr[1] &~vaddr[0] ? word[23:16] :
                   ~vaddr[1] & vaddr[0] ? word[15: 8] :
                                          word[ 7: 0] ;
    assign  half_xtnd = {32{inst_ld_h}} & {{16{half[15]}}, half} | {32{inst_ld_hu}} & {16'b0, half};
    assign  byte_xtnd = {32{inst_ld_b}} & {{24{byte[ 7]}}, byte} | {32{inst_ld_bu}} & {24'b0, byte};

    assign  mem_ld_result = {32{inst_ld_b | inst_ld_bu}} & byte_xtnd |
                            {32{inst_ld_h | inst_ld_hu}} & half_xtnd |
                            {32{inst_ld_w             }} & word      ;

    assign  mem_final_result = res_from_mem ? mem_ld_result : alu_result;
    assign  mem_wb_bus = {
        mem_gr_we, mem_pc, mem_inst, mem_final_result, mem_dest
    };
    //写信号
    assign  mem_en_bypass = mem_valid & mem_gr_we;
    assign  mem_wr_bus = {
        mem_en_bypass, mem_dest, mem_final_result
    };
endmodule