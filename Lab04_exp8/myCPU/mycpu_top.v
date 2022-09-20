module mycpu_top(
    input  wire        clk,
    input  wire        resetn,
    // inst sram interface
    output wire        inst_sram_en,
    output wire [ 3:0] inst_sram_we,
    output wire [31:0] inst_sram_addr,
    output wire [31:0] inst_sram_wdata,
    input  wire [31:0] inst_sram_rdata,
    // data sram interface
    output wire        data_sram_en,
    output wire [ 3:0] data_sram_we,
    output wire [31:0] data_sram_addr,
    output wire [31:0] data_sram_wdata,
    input  wire [31:0] data_sram_rdata,
    // trace debug interface
    output wire [31:0] debug_wb_pc,
    output wire [ 3:0] debug_wb_rf_we,
    output wire [ 4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata
);
    //信号定义
    wire            id_allowin;
    wire            if_id_valid;
    wire    [ 63:0] if_id_bus;
    wire    [ 32:0] id_if_bus;
    wire            exe_allowin;
    wire            id_exe_valid;
    wire    [179:0] id_exe_bus;
    wire    [ 37:0] wb_id_bus;
    wire    [102:0] exe_mem_bus;
    wire            exe_mem_valid;
    wire            mem_allowin;
    wire            mem_wb_valid;
    wire    [101:0] mem_wb_bus;
    wire            wb_allowin;
    //模块调用
    IF my_IF (
        .clk                (clk),
        .resetn             (resetn),
        .id_allowin         (id_allowin),
        .if_id_valid        (if_id_valid),
        .if_id_bus          (if_id_bus),
        .id_if_bus          (id_if_bus),
        .inst_sram_en       (inst_sram_en),
        .inst_sram_we       (inst_sram_we),
        .inst_sram_addr     (inst_sram_addr),
        .inst_sram_rdata    (inst_sram_rdata),
        .inst_sram_wdata    (inst_sram_wdata)
    );
    ID my_ID (
        .clk                (clk),
        .resetn             (resetn),
        .if_id_valid        (if_id_valid),
        .id_allowin         (id_allowin),
        .if_id_bus          (if_id_bus),
        .id_if_bus          (id_if_bus),
        .exe_allowin        (exe_allowin),
        .id_exe_valid       (id_exe_valid),
        .id_exe_bus         (id_exe_bus),
        .wb_id_bus          (wb_id_bus)
    );
    EXE my_EXE (
        .clk                (clk),
        .resetn             (resetn),
        .exe_allowin        (exe_allowin),
        .id_exe_valid       (id_exe_valid),
        .id_exe_bus         (id_exe_bus),
        .exe_mem_valid      (exe_mem_valid),
        .mem_allowin        (mem_allowin),
        .exe_mem_bus        (exe_mem_bus),
        .data_sram_en       (data_sram_en),
        .data_sram_we       (data_sram_we),
        .data_sram_addr     (data_sram_addr),
        .data_sram_wdata    (data_sram_wdata)
    );
    MEM my_MEM (
        .clk                (clk),
        .resetn             (resetn),
        .mem_allowin        (mem_allowin),
        .exe_mem_valid      (exe_mem_valid),
        .exe_mem_bus        (exe_mem_bus),
        .mem_wb_valid       (mem_wb_valid),
        .wb_allowin         (wb_allowin),
        .mem_wb_bus         (mem_wb_bus),
        .data_sram_rdata    (data_sram_rdata)
    );
    WB my_WB (
        .clk                (clk),
        .resetn             (resetn),
        .wb_allowin         (wb_allowin),
        .mem_wb_valid       (mem_wb_valid),
        .mem_wb_bus         (mem_wb_bus),
        .wb_id_bus          (wb_id_bus),
        .debug_wb_pc        (debug_wb_pc),
        .debug_wb_rf_we     (debug_wb_rf_we),
        .debug_wb_rf_wnum   (debug_wb_rf_wnum),
        .debug_wb_rf_wdata  (debug_wb_rf_wdata)
    );
endmodule