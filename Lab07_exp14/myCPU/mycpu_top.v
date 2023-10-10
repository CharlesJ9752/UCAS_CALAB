`include "mycpu.h"
module mycpu_top(
    input  wire        clk,
    input  wire        resetn,
    // inst sram interface
    output        inst_sram_req,
    output        inst_sram_wr,
    output [ 1:0] inst_sram_size,
    output [31:0] inst_sram_addr,
    output [ 3:0] inst_sram_wstrb,
    output [31:0] inst_sram_wdata,
    input         inst_sram_addr_ok,
    input         inst_sram_data_ok,
    input  [31:0] inst_sram_rdata,
    // data sram interface
    output        data_sram_req,
    output        data_sram_wr,
    output [ 1:0] data_sram_size,
    output [31:0] data_sram_addr,
    output [ 3:0] data_sram_wstrb,
    output [31:0] data_sram_wdata,
    input         data_sram_addr_ok,
    input         data_sram_data_ok,
    input  [31:0] data_sram_rdata,
    // trace debug interface
    output wire [31:0] debug_wb_pc,
    output wire [ 3:0] debug_wb_rf_we,
    output wire [ 4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata
);
    //信号定义
    wire                                    id_allowin;
    wire                                    if_id_valid;
    wire    [`IF_ID_BUS_WDTH - 1:0]         if_id_bus;
    wire    [`ID_IF_BUS_WDTH - 1:0]         id_if_bus;
    wire                                    exe_allowin;
    wire                                    id_exe_valid;
    wire    [`ID_EXE_BUS_WDTH - 1:0]        id_exe_bus;
    wire    [`WB_ID_BUS_WDTH - 1:0]         wb_id_bus;
    wire    [`EXE_MEM_BUS_WDTH - 1:0]       exe_mem_bus;
    wire                                    exe_mem_valid;
    wire                                    mem_allowin;
    wire                                    mem_wb_valid;
    wire    [`MEM_WB_BUS_WDTH - 1:0]        mem_wb_bus;
    wire                                    wb_allowin;
    wire    [`EXE_WR_BUS_WDTH - 1:0]        exe_wr_bus;
    wire    [`MEM_WR_BUS_WDTH - 1:0]        mem_wr_bus;
    //csr
    wire    [13:0]                          csr_waddr;
    wire                                    csr_we;
    wire    [31:0]                          csr_wmask;
    wire    [31:0]                          csr_wdata;
    wire    [13:0]                          csr_raddr;
    wire    [31:0]                          csr_rdata;

    wire                                    wb_exc;
    wire    [ 5:0]                          wb_ecode;
    wire    [ 8:0]                          wb_esubcode;
    wire    [31:0]                          wb_pc;

    wire                                    ertn_flush;
    wire    [31:0]                          exc_entaddr;
    wire    [31:0]                          exc_retaddr;
    wire    [`EXE_CSR_BLK_BUS_WDTH - 1:0]   exe_csr_blk_bus;
    wire    [`MEM_CSR_BLK_BUS_WDTH - 1:0]   mem_csr_blk_bus;
    wire    [`WB_CSR_BLK_BUS_WDTH - 1:0]    wb_csr_blk_bus;

    wire                                    mem_exc;
    wire                                    mem_ertn;
    wire                                    exe_ertn;
    wire    [31:0]                          wb_badvaddr;
    wire                                    ldst_cancel;

   //模块调用

    IF my_IF (
        .clk                (clk),
        .resetn             (resetn),
        .id_allowin         (id_allowin),
        .if_id_valid        (if_id_valid),
        .if_id_bus          (if_id_bus),
        .id_if_bus          (id_if_bus),
        .inst_sram_req      (inst_sram_req),
        .inst_sram_wr       (inst_sram_wr),
        .inst_sram_size     (inst_sram_size),
        .inst_sram_wstrb    (inst_sram_wstrb),
        .inst_sram_addr     (inst_sram_addr), 
        .inst_sram_rdata    (inst_sram_rdata),
        .inst_sram_wdata    (inst_sram_wdata),
        .inst_sram_addr_ok  (inst_sram_addr_ok),
        .inst_sram_data_ok  (inst_sram_data_ok),
        .wb_exc             (wb_exc),
        .ertn_flush         (ertn_flush),
        .exc_entaddr        (exc_entaddr),
        .exc_retaddr        (exc_retaddr)
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
        .wb_id_bus          (wb_id_bus),
        .exe_wr_bus         (exe_wr_bus),
        .mem_wr_bus         (mem_wr_bus),
        .wb_exc             (wb_exc),
        .csr_rdata          (csr_rdata),
        .csr_raddr          (csr_raddr),
        .exe_csr_blk_bus    (exe_csr_blk_bus),
        .mem_csr_blk_bus    (mem_csr_blk_bus),
        .wb_csr_blk_bus     (wb_csr_blk_bus),
        .csr_has_int        (csr_has_int)
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
         .data_sram_req    (data_sram_req    ),
        .data_sram_wr     (data_sram_wr     ),
        .data_sram_size   (data_sram_size   ),
        .data_sram_addr   (data_sram_addr   ),
        .data_sram_wstrb  (data_sram_wstrb  ),
        .data_sram_wdata  (data_sram_wdata  ),
        .data_sram_addr_ok(data_sram_addr_ok),
        .exe_wr_bus         (exe_wr_bus),
        .exe_csr_blk_bus    (exe_csr_blk_bus),
        .wb_exc             (wb_exc),
        .ertn_flush            (ertn_flush),
        .mem_ertn           (mem_ertn),
        .mem_exc  (mem_exc),
        .ldst_cancel (ldst_cancel)
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
        .data_sram_rdata    (data_sram_rdata),
        .data_sram_data_ok(data_sram_data_ok),
        .mem_wr_bus         (mem_wr_bus),
        .mem_csr_blk_bus    (mem_csr_blk_bus),
        .wb_exc             (wb_exc),
        .mem_ertn           (mem_ertn),
        .ertn_flush            (ertn_flush),
        .mem_exc  (mem_exc),
        .ldst_cancel (ldst_cancel)
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
        .debug_wb_rf_wdata  (debug_wb_rf_wdata),
        .csr_we             (csr_we),
        .csr_waddr          (csr_waddr),
        .csr_wmask          (csr_wmask),
        .csr_wdata          (csr_wdata),
        .wb_exc             (wb_exc),
        .wb_ecode           (wb_ecode),
        .wb_esubcode        (wb_esubcode),
        .wb_pc              (wb_pc),
        .ertn_flush         (ertn_flush),
        .wb_csr_blk_bus     (wb_csr_blk_bus),
        .wb_badvaddr        (wb_badvaddr)    
    );
    csr my_csr(
        .clk                (clk),
        .resetn             (resetn),
        .csr_we             (csr_we),
        .csr_waddr          (csr_waddr),
        .csr_wmask          (csr_wmask),
        .csr_wdata          (csr_wdata),
        .csr_raddr          (csr_raddr),
        .csr_rdata          (csr_rdata),
        .wb_exc             (wb_exc),
        .wb_ecode           (wb_ecode),
        .wb_esubcode        (wb_esubcode),
        .wb_pc              (wb_pc),
        .ertn_flush         (ertn_flush),
        .has_int            (csr_has_int),
        .exc_entaddr        (exc_entaddr),
        .exc_retaddr        (exc_retaddr),
        .wb_badvaddr        (wb_badvaddr)
    );
endmodule