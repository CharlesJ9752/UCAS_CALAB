module mycpu_top(
    input  wire        clk,
    input  wire        resetn,
    // inst sram interface
    output wire        inst_sram_we,
    output wire [31:0] inst_sram_addr,
    output wire [31:0] inst_sram_wdata,
    input  wire [31:0] inst_sram_rdata,
    // data sram interface
    output wire        data_sram_we,
    output wire [31:0] data_sram_addr,
    output wire [31:0] data_sram_wdata,
    input  wire [31:0] data_sram_rdata,
    // trace debug interface
    output wire [31:0] debug_wb_pc,
    output wire [ 3:0] debug_wb_rf_we,
    output wire [ 4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata
);
    wire ds_allowin;
    wire fs_to_ds_valid;
    wire [32:0] ds_to_fs_bus;
    wire [63:0] fs_to_ds_bus;
IF my_IF(
        .clk(clk),
        .resetn(resetn),
        .ds_allowin(ds_allowin),
        .fs_to_ds_valid(fs_to_ds_valid),
        .ds_to_fs_bus(ds_to_fs_bus),
        .fs_to_ds_bus(fs_to_ds_bus),
        .inst_sram_en(inst_sram_en),
        .inst_sram_addr(inst_sram_addr),
        .inst_sram_rdata(inst_sram_rdata)
    );
    assign inst_sram_we = 1'b0;
    assign inst_sram_wdata = 32'h0;

    wire es_allowin;
    wire ds_to_es_valid;
    wire [147:0] ds_to_es_bus;
    wire [37:0] ws_to_ds_bus;
ID my_ID(
        .clk(clk),
        .resetn(resetn),
        .ds_allowin(ds_allowin),
        .fs_to_ds_valid(fs_to_ds_valid),
        .fs_to_ds_bus(fs_to_ds_bus),
        .ds_to_fs_bus(ds_to_fs_bus),
        .es_allowin(es_allowin),
        .ds_to_es_valid(ds_to_es_valid),
        .ds_to_es_bus(ds_to_es_bus),
        .ws_to_ds_bus(ws_to_ds_bus)
    );

    wire [70:0] es_to_ms_bus;
    wire es_to_ms_valid;
    wire ms_allowin;
EXE my_EXE(
        .clk(clk),
        .resetn(resetn),
        .es_allowin(es_allowin),
        .ds_to_es_valid(ds_to_es_valid),
        .ds_to_es_bus(ds_to_es_bus),
        .es_to_ms_valid(es_to_ms_valid),
        .es_to_ms_bus(es_to_ms_bus),
        .ms_allowin(ms_allowin),
        .data_sram_en(data_sram_en),
        .data_sram_we(data_sram_we),
        .data_sram_addr(data_sram_addr),
        .data_sram_wdata(data_sram_wdata)
    );

    wire ms_to_ws_valid;
    wire [69:0] ms_to_ws_bus;
    wire ws_allowin;
MEM my_MEM(
        .clk(clk),
        .resetn(resetn),
        .ms_allowin(ms_allowin),
        .es_to_ms_valid(es_to_ms_valid),
        .es_to_ms_bus(es_to_ms_bus),
        .ms_to_ws_valid(ms_to_ws_valid),
        .ms_to_ws_bus(ms_to_ws_bus),
        .ws_allowin(ws_allowin),
        .data_sram_rdata(data_sram_rdata)
    );

WB my_WB(
        .clk(clk),
        .resetn(resetn),
        .ws_allowin(ws_allowin),
        .ms_to_ws_valid(ms_to_ws_valid),
        .ms_to_ws_bus(ms_to_ws_bus),
        .ws_to_ds_bus(ws_to_ds_bus),
        .debug_wb_pc(debug_wb_pc),
        .debug_wb_rf_we(debug_wb_rf_we),
        .debug_wb_rf_wnum(debug_wb_rf_wnum),
        .debug_wb_rf_wdata(debug_wb_rf_wdata)
    );
endmodule