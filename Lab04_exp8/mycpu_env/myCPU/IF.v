//取指，更新pc
module IF (
    input           clk,
    input           resetn,
    //与ID阶段
    input           id_allowin,
    output          if_id_valid,
    output  [63:0]  if_id_bus,//if_pc+if_inst
    input   [32:0]  id_if_bus,//en_brch+brch_addr
    //与指令存储器
    output          inst_sram_en,
    output  [3:0]   inst_sram_we,
    output  [31:0]  inst_sram_addr,
    output  [31:0]  inst_sram_wdata,
    input   [31:0]  inst_sram_rdata
);
    //信号定义
    reg             if_valid;//有指令在if�?
    wire            if_ready_go;//指令可以去下�?个阶�?
    wire            if_allowin;//可接�?
    wire            en_brch_cancel;//使能跳转
    reg     [31:0]  if_pc;//if阶段的pc�?
    wire    [31:0]  if_inst;//if阶段的指�?
    wire    [31:0]  if_nextpc;//下一个pc
    wire    [31:0]  if_brch_addr;//若跳转的pc
    wire    [31:0]  seq_pc;//若顺序的pc

    assign  if_ready_go = 1'b1;
    assign  if_allowin = ~resetn | if_ready_go & id_allowin;//还没�?始，或当前指令可以去下一�?
    always @(posedge clk ) begin
        if(~resetn)begin
            if_valid <= 1'b0;
        end
        else if(if_allowin)begin
            if_valid <= 1'b1;
        end
        else if(en_brch_cancel)begin
            if_valid <= 1'b0;
        end
    end
    assign  if_id_valid = if_ready_go & if_valid;
    assign  if_id_bus = { if_pc, if_inst };
    //更新pc
    assign  seq_pc = if_pc + 3'h4;
    assign  { en_brch_cancel, if_brch_addr} = id_if_bus;
    assign  if_nextpc = en_brch_cancel ? if_brch_addr : seq_pc;
    always @(posedge clk ) begin
        if(~resetn)begin
            if_pc <= 32'h1bfffffc;
        end
        else if(if_allowin)begin
            if_pc <= if_nextpc;
        end
    end
    //取指
    assign  inst_sram_en = if_allowin;
    assign  inst_sram_addr = if_nextpc;
    assign  if_inst = inst_sram_rdata;
    assign  inst_sram_we = 4'b0;
    assign  inst_sram_wdata = 32'b0;
endmodule