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
    wire reset=~resetn;
    wire         fs_block;
    wire         fs_allowin;
    wire ds_allowin;

    wire         pfs_to_fs_valid;
    wire [`PFS_TO_FS_BUS_WD - 1:0] pfs_to_fs_bus;

    wire fs_to_ds_valid;
    wire [`BR_BUS_WD-1:0] br_bus;
    wire [`FS_TO_DS_BUS_WD-1:0] fs_to_ds_bus;

    wire [6:0] es_block_bus;
    wire [5:0] ws_block_bus;
    wire [5:0] ms_block_bus;

    wire [31:0] es_forward;
    wire [31:0] ms_forward;
    wire [31:0] ws_forward;
    
    // CSR ports
    wire [13:0] csr_wnum;
    wire        csr_we;
    wire [31:0] csr_wmask;
    wire [31:0] csr_wvalue;
    wire [13:0] csr_rnum;
    wire [31:0] csr_rvalue;

    wire        wb_exc;
    wire [ 5:0] wb_ecode;
    wire [ 8:0] wb_esubcode;
    wire [31:0] wb_pc;
    wire [31:0] wb_vaddr;

    wire        wb_ertn;
    wire        csr_has_int;
    wire [31:0] exc_entry;
    wire [31:0] exc_retaddr;

    wire [`ES_CSR_BLK_BUS_WD-1:0] es_csr_blk_bus;
    wire [`MS_CSR_BLK_BUS_WD-1:0] ms_csr_blk_bus;
    wire [`WS_CSR_BLK_BUS_WD-1:0] ws_csr_blk_bus;

    wire ms_to_es_ls_cancel;

//PRE_IF stage
preIF my_preIF(
    .clk            (clk            ),
    .reset          (reset          ),
    //allowin
    .fs_allowin     (fs_allowin     ),    
    .fs_block (fs_block ),
    //outputs
    .pfs_to_fs_bus  (pfs_to_fs_bus  ),
    .pfs_to_fs_valid(pfs_to_fs_valid),    
    //brbus
    .br_bus         (br_bus         ),
    // inst sram interface
    .inst_sram_req  (inst_sram_req  ),
    .inst_sram_wr   (inst_sram_wr   ),
    .inst_sram_size (inst_sram_size ),
    .inst_sram_wstrb(inst_sram_wstrb),
    .inst_sram_addr (inst_sram_addr ),
    .inst_sram_wdata(inst_sram_wdata),
    .inst_sram_addr_ok(inst_sram_addr_ok),
    .inst_sram_data_ok(inst_sram_data_ok),
    .inst_sram_rdata(inst_sram_rdata),

    .wb_exc         (wb_exc         ),
    .wb_ertn        (wb_ertn        ),
    .exc_entry      (exc_entry      ),
    .exc_retaddr    (exc_retaddr    )
);


IF my_IF(
        .clk(clk),
        .reset(reset),
        .ds_allowin(ds_allowin),
        .fs_to_ds_valid(fs_to_ds_valid),
        .fs_to_ds_bus(fs_to_ds_bus),
        .br_bus(br_bus),
        .pfs_to_fs_valid(pfs_to_fs_valid),  
        .pfs_to_fs_bus  (pfs_to_fs_bus  ),
        //outputs
        .fs_allowin     (fs_allowin     ),
        .fs_block  (fs_block ),
        // inst sram interface
        .inst_sram_addr_ok(inst_sram_addr_ok),
        .inst_sram_data_ok(inst_sram_data_ok),
        .inst_sram_rdata  (inst_sram_rdata  ),
        .wb_exc         (wb_exc         ),
        .wb_ertn        (wb_ertn        )
    );
    assign inst_sram_we = 1'b0;
    assign inst_sram_wdata = 32'h0;

    wire es_allowin;
    wire ds_to_es_valid;
    wire [`DS_TO_ES_BUS_WD-1:0] ds_to_es_bus;
    wire [37:0] ws_to_ds_bus;
ID my_ID(
        .clk(clk),
        .reset(reset),
        .ds_allowin(ds_allowin),
        .fs_to_ds_valid(fs_to_ds_valid),
        .fs_to_ds_bus(fs_to_ds_bus),
        .br_bus(br_bus),
        .es_allowin(es_allowin),
        .ds_to_es_valid(ds_to_es_valid),
        .ds_to_es_bus(ds_to_es_bus),
        .ws_to_ds_bus(ws_to_ds_bus),
        .es_block_bus(es_block_bus),
        .ms_block_bus(ms_block_bus),
        .ws_block_bus(ws_block_bus),
        .es_forward(es_forward),
        .ms_forward(ms_forward),
        .ws_forward(ws_forward),
        .csr_has_int    (csr_has_int    ),
        .wb_exc         (wb_exc         ),
        .wb_ertn        (wb_ertn        ),
        .csr_rnum       (csr_rnum       ),
        .csr_rvalue     (csr_rvalue       ),

        .es_csr_blk_bus (es_csr_blk_bus ),
        .ms_csr_blk_bus (ms_csr_blk_bus ),
        .ws_csr_blk_bus (ws_csr_blk_bus )
    );

    wire es_to_ms_valid;
    wire ms_allowin;
    wire [`ES_TO_MS_BUS_WD-1:0] es_to_ms_bus;
EXE my_EXE(
        .clk(clk),
        .reset(reset),
        .es_allowin(es_allowin),
        .ds_to_es_valid(ds_to_es_valid),
        .ds_to_es_bus(ds_to_es_bus),
        .es_to_ms_valid(es_to_ms_valid),
        .es_to_ms_bus(es_to_ms_bus),
        .ms_allowin(ms_allowin),
        // data sram interface
        .data_sram_req    (data_sram_req    ),
        .data_sram_wr     (data_sram_wr     ),
        .data_sram_size   (data_sram_size   ),
        .data_sram_addr   (data_sram_addr   ),
        .data_sram_wstrb  (data_sram_wstrb  ),
        .data_sram_wdata  (data_sram_wdata  ),
        .data_sram_addr_ok(data_sram_addr_ok),

        .es_block_bus(es_block_bus),
        .es_forward(es_forward),
        .wb_exc         (wb_exc         ),
        .wb_ertn        (wb_ertn        ),
        .ms_to_es_ls_cancel(ms_to_es_ls_cancel),

        .es_csr_blk_bus (es_csr_blk_bus )
    );

    wire ms_to_ws_valid;
    wire ws_allowin;
    wire [`MS_TO_WS_BUS_WD-1:0] ms_to_ws_bus;
MEM my_MEM(
        .clk(clk),
        .reset(reset),
        .ms_allowin(ms_allowin),
        .es_to_ms_valid(es_to_ms_valid),
        .es_to_ms_bus(es_to_ms_bus),
        .ms_to_ws_valid(ms_to_ws_valid),
        .ms_to_ws_bus(ms_to_ws_bus),
        .ws_allowin(ws_allowin),
        .data_sram_data_ok(data_sram_data_ok),
        .data_sram_rdata(data_sram_rdata),
        .ms_block_bus(ms_block_bus),
        .ms_forward(ms_forward),
        .wb_exc         (wb_exc         ),
        .wb_ertn        (wb_ertn        ),
        .ms_to_es_ls_cancel(ms_to_es_ls_cancel),
        .ms_csr_blk_bus (ms_csr_blk_bus )
    );

WB my_WB(
        .clk(clk),
        .reset(reset),
        .ws_allowin(ws_allowin),
        .ms_to_ws_valid(ms_to_ws_valid),
        .ms_to_ws_bus(ms_to_ws_bus),
        .ws_to_ds_bus(ws_to_ds_bus),
        .debug_wb_pc(debug_wb_pc),
        .debug_wb_rf_we(debug_wb_rf_we),
        .debug_wb_rf_wnum(debug_wb_rf_wnum),
        .debug_wb_rf_wdata(debug_wb_rf_wdata),
        .ws_block_bus(ws_block_bus),
        .ws_forward(ws_forward),

        .csr_we         (csr_we         ),
        .csr_wnum       (csr_wnum       ),
        .csr_wmask      (csr_wmask      ),
        .csr_wvalue     (csr_wvalue     ),

        .wb_exc         (wb_exc         ),
        .wb_ecode       (wb_ecode       ),
        .wb_esubcode    (wb_esubcode    ),
        .wb_pc          (wb_pc),
        .wb_vaddr       (wb_vaddr),
        .ertn_flush     (wb_ertn        ),

        .ws_csr_blk_bus (ws_csr_blk_bus )
    );

csr my_csr(
    .clk        (clk        ),
    .reset      (reset      ),
    
    .csr_wnum   (csr_wnum   ),
    .csr_we     (csr_we     ),
    .csr_wmask  (csr_wmask  ),
    .csr_wvalue (csr_wvalue ),

    .csr_rnum   (csr_rnum   ),
    .csr_rvalue (csr_rvalue ),

    .wb_exc     (wb_exc     ),
    .wb_ecode   (wb_ecode   ),
    .wb_esubcode(wb_esubcode),
    .wb_pc      (wb_pc      ),
    .wb_vaddr   (wb_vaddr   ),
    .ertn_flush (wb_ertn    ),
    
    .has_int    (csr_has_int),
    .exc_entry  (exc_entry  ),
    .exc_retaddr(exc_retaddr)
);
endmodule