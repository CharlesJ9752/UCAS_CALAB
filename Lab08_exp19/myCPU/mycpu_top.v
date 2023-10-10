`include "mycpu.h"
module mycpu_top(
    input  wire        aclk,
    input  wire        aresetn,
    output [ 3:0]   arid,
    output [31:0]   araddr,
    output [ 7:0]   arlen,
    output [ 2:0]   arsize,
    output [ 1:0]   arburst,
    output [ 1:0]   arlock,
    output [ 3:0]   arcache,
    output [ 2:0]   arprot,
    output          arvalid,
    input           arready,
    input  [ 3:0]   rid,
    input  [31:0]   rdata,
    input  [ 1:0]   rresp,
    input           rlast,
    input           rvalid,
    output          rready,
    output [ 3:0]   awid,
    output [31:0]   awaddr,
    output [ 7:0]   awlen,
    output [ 2:0]   awsize,
    output [ 1:0]   awburst,
    output [ 1:0]   awlock,
    output [ 3:0]   awcache,
    output [ 2:0]   awprot,
    output          awvalid,
    input           awready,
    output  [ 3:0]  wid,
    output  [31:0]  wdata,
    output  [ 3:0]  wstrb,
    output          wlast,
    output          wvalid,
    input           wready,
    input  [ 3:0]   bid,
    input  [ 1:0]   bresp,
    input           bvalid,
    output          bready,
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
    wire    [31:0]                          flush_pc;

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
    wire                                    refetch;
    wire    [`NUM_TYPES-1:0]                wb_exc_type;

    wire                                    flush;
    wire [31:0]                             wb_flush_target;
    //csr
    wire [ 1:0]                             csr_crmd_plv;
    wire                                    csr_crmd_da;
    wire                                    csr_crmd_pg;
    wire [ 1:0]                             csr_crmd_datf;
    wire [ 1:0]                             csr_crmd_datm;
    wire [ 9:0]                             csr_asid_asid;
    wire [18:0]                             csr_tlbehi_vppn;
    wire [ 3:0]                             csr_tlbidx_index;
    wire                                    csr_dmw0_plv0;
    wire                                    csr_dmw0_plv3;
    wire [ 1:0]                             csr_dmw0_mat;
    wire [ 2:0]                             csr_dmw0_pseg;
    wire [ 2:0]                             csr_dmw0_vseg;
    wire                                    csr_dmw1_plv0;
    wire                                    csr_dmw1_plv3;
    wire [ 1:0]                             csr_dmw1_mat;
    wire [ 2:0]                             csr_dmw1_pseg;
    wire [ 2:0]                             csr_dmw1_vseg;

    wire                                    tlbrd_we;
    wire                                    tlbsrch_we;
    wire                                    tlb_hit;
    wire [ 3:0]                             tlb_hit_index;

    // inst sram interface
    wire                                    inst_sram_req;
    wire                                    inst_sram_wr;
    wire  [ 1:0]                            inst_sram_size;
    wire  [31:0]                            inst_sram_addr;
    wire  [ 3:0]                            inst_sram_wstrb;
    wire  [31:0]                            inst_sram_wdata;
    wire                                    inst_sram_addr_ok;
    wire                                    inst_sram_data_ok;
    wire [31:0]                             inst_sram_rdata;
    // data sram interface
    wire                                    data_sram_req;
    wire                                    data_sram_wr;
    wire  [ 1:0]                            data_sram_size;
    wire  [31:0]                            data_sram_addr;
    wire  [ 3:0]                            data_sram_wstrb;
    wire  [31:0]                            data_sram_wdata;
    wire                                    data_sram_addr_ok;
    wire                                    data_sram_data_ok;
    wire [31:0]                             data_sram_rdata;
    

    //模块调用
    AXI_bridge my_AXI_bridge(
        .aclk                (aclk       ),
        .aresetn             (aresetn    ), 

        .arid               (arid      ),
        .araddr             (araddr    ),
        .arlen              (arlen     ),
        .arsize             (arsize    ),
        .arburst            (arburst   ),
        .arlock             (arlock    ),
        .arcache            (arcache   ),
        .arprot             (arprot    ),
        .arvalid            (arvalid   ),
        .arready            (arready   ),
                    
        .rid                (rid       ),
        .rdata              (rdata     ),
        .rresp              (rresp     ),
        .rlast              (rlast     ),
        .rvalid             (rvalid    ),
        .rready             (rready    ),
                
        .awid               (awid      ),
        .awaddr             (awaddr    ),
        .awlen              (awlen     ),
        .awsize             (awsize    ),
        .awburst            (awburst   ),
        .awlock             (awlock    ),
        .awcache            (awcache   ),
        .awprot             (awprot    ),
        .awvalid            (awvalid   ),
        .awready            (awready   ),
        
        .wid                (wid       ),
        .wdata              (wdata     ),
        .wstrb              (wstrb     ),
        .wlast              (wlast     ),
        .wvalid             (wvalid    ),
        .wready             (wready    ),
        
        .bid                (bid       ),
        .bresp              (bresp     ),
        .bvalid             (bvalid    ),
        .bready             (bready    ),
        .inst_sram_req      (inst_sram_req  ),
        .inst_sram_wr       (inst_sram_wr   ),
        .inst_sram_size     (inst_sram_size ),
        .inst_sram_wstrb    (inst_sram_wstrb),
        .inst_sram_addr     (inst_sram_addr ),
        .inst_sram_wdata    (inst_sram_wdata),
        .inst_sram_addr_ok  (inst_sram_addr_ok),
        .inst_sram_data_ok  (inst_sram_data_ok),
        .inst_sram_rdata    (inst_sram_rdata),
        .data_sram_req      (data_sram_req    ),
        .data_sram_wr       (data_sram_wr     ),
        .data_sram_size     (data_sram_size   ),
        .data_sram_addr     (data_sram_addr   ),
        .data_sram_wstrb    (data_sram_wstrb  ),
        .data_sram_wdata    (data_sram_wdata  ),
        .data_sram_addr_ok  (data_sram_addr_ok),
        .data_sram_data_ok  (data_sram_data_ok),
        .data_sram_rdata    (data_sram_rdata  )
    );

    IF my_IF (
        .clk                (aclk),
        .resetn             (aresetn),
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
        .flush              (flush),
        .flush_pc      (flush_pc),
        .s0_vppn            (s0_vppn),
        .s0_va_bit12        (s0_va_bit12),
        .s0_found           (s0_found),
        .s0_index           (s0_index),
        .s0_ppn             (s0_ppn),
        .s0_ps              (s0_ps),
        .s0_plv             (s0_plv),
        .s0_mat             (s0_mat),
        .s0_d               (s0_d),
        .s0_v               (s0_v),
        .csr_crmd_da        (csr_crmd_da),
        .csr_crmd_pg        (csr_crmd_pg),
        .csr_crmd_plv       (csr_crmd_plv),
        .csr_dmw0_plv0      (csr_dmw0_plv0),
        .csr_dmw0_plv3      (csr_dmw0_plv3),
        .csr_dmw0_mat       (csr_dmw0_mat),
        .csr_dmw0_pseg      (csr_dmw0_pseg),
        .csr_dmw0_vseg      (csr_dmw0_vseg),
        .csr_dmw1_plv0      (csr_dmw1_plv0),
        .csr_dmw1_plv3      (csr_dmw1_plv3),
        .csr_dmw1_mat       (csr_dmw1_mat),
        .csr_dmw1_pseg      (csr_dmw1_pseg),
        .csr_dmw1_vseg      (csr_dmw1_vseg)
    );
    ID my_ID (
        .clk                (aclk),
        .resetn             (aresetn),
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
        .csr_rdata          (csr_rdata),
        .csr_raddr          (csr_raddr),
        .exe_csr_blk_bus    (exe_csr_blk_bus),
        .mem_csr_blk_bus    (mem_csr_blk_bus),
        .wb_csr_blk_bus     (wb_csr_blk_bus),
        .csr_has_int        (csr_has_int),
        .flush              (flush)
    );
    EXE my_EXE (
        .clk                (aclk),
        .resetn             (aresetn),
        .exe_allowin        (exe_allowin),
        .id_exe_valid       (id_exe_valid),
        .id_exe_bus         (id_exe_bus),
        .exe_mem_valid      (exe_mem_valid),
        .mem_allowin        (mem_allowin),
        .exe_mem_bus        (exe_mem_bus),
        .data_sram_req      (data_sram_req    ),
        .data_sram_wr       (data_sram_wr     ),
        .data_sram_size     (data_sram_size   ),
        .data_sram_addr     (data_sram_addr   ),
        .data_sram_wstrb    (data_sram_wstrb  ),
        .data_sram_wdata    (data_sram_wdata  ),
        .data_sram_addr_ok  (data_sram_addr_ok),
        .exe_wr_bus         (exe_wr_bus),
        .exe_csr_blk_bus    (exe_csr_blk_bus),
        .flush              (flush),
        .mem_ertn           (mem_ertn),
        .mem_exc            (mem_exc),
        .ldst_cancel        (ldst_cancel),
        .s1_vppn            (s1_vppn),
        .s1_va_bit12        (s1_va_bit12),
        .s1_asid            (s1_asid),
        .s1_found           (s1_found),
        .s1_index           (s1_index),
        .s1_ppn             (s1_ppn),
        .s1_ps              (s1_ps),
        .s1_plv             (s1_plv),
        .s1_mat             (s1_mat),
        .s1_d               (s1_d),
        .s1_v               (s1_v),
        .invtlb_valid       (invtlb_valid),
        .invtlb_op          (invtlb_op),
        .csr_crmd_da        (csr_crmd_da),
        .csr_crmd_pg        (csr_crmd_pg),
        .csr_crmd_plv       (csr_crmd_plv),

        .csr_dmw0_plv0      (csr_dmw0_plv0),
        .csr_dmw0_plv3      (csr_dmw0_plv3),
        .csr_dmw0_mat       (csr_dmw0_mat),
        .csr_dmw0_pseg      (csr_dmw0_pseg),
        .csr_dmw0_vseg      (csr_dmw0_vseg),

        .csr_dmw1_plv0      (csr_dmw1_plv0),
        .csr_dmw1_plv3      (csr_dmw1_plv3),
        .csr_dmw1_mat       (csr_dmw1_mat),
        .csr_dmw1_pseg      (csr_dmw1_pseg),
        .csr_dmw1_vseg      (csr_dmw1_vseg),
        .csr_asid_asid      (csr_asid_asid),
        .csr_tlbehi_vppn    (csr_tlbehi_vppn)

    );
    MEM my_MEM (
        .clk                (aclk),
        .resetn             (aresetn),
        .mem_allowin        (mem_allowin),
        .exe_mem_valid      (exe_mem_valid),
        .exe_mem_bus        (exe_mem_bus),
        .mem_wb_valid       (mem_wb_valid),
        .wb_allowin         (wb_allowin),
        .mem_wb_bus         (mem_wb_bus),
        .data_sram_rdata    (data_sram_rdata),
        .data_sram_data_ok  (data_sram_data_ok),
        .mem_wr_bus         (mem_wr_bus),
        .mem_csr_blk_bus    (mem_csr_blk_bus),
        .mem_ertn           (mem_ertn),
        .mem_exc            (mem_exc),
        .ldst_cancel        (ldst_cancel),
        .flush              (flush)
    );
    WB my_WB (
        .clk                (aclk),
        .resetn             (aresetn),
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
        .wb_badvaddr        (wb_badvaddr),
        .refetch            (refetch),
        .r_index            (r_index),
        .tlbrd_we           (tlbrd_we),
        .csr_tlbidx_index   (csr_tlbidx_index),
        .w_index            (w_index),
        .we                 (we),
        .tlbsrch_we         (tlbsrch_we),
        .tlb_hit            (tlb_hit),
        .tlb_hit_index      (tlb_hit_index),
        .wb_exc_type        (wb_exc_type)
    );
    csr my_csr(
        .clk                (aclk),
        .resetn             (aresetn),
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
        .wb_badvaddr        (wb_badvaddr),
        .csr_asid_asid      (csr_asid_asid),
        .csr_tlbehi_vppn    (csr_tlbehi_vppn),
        .csr_tlbidx_index   (csr_tlbidx_index),
        .tlbsrch_we         (tlbsrch_we),
        .tlbsrch_hit        (tlb_hit),
        .tlb_hit_index      (tlb_hit_index),
        .tlbrd_we           (tlbrd_we),
        .r_tlb_e            (r_e),
        .r_tlb_ps           (r_ps),
        .r_tlb_vppn         (r_vppn),
        .r_tlb_asid         (r_asid),
        .r_tlb_g            (r_g),
        .r_tlb_ppn0         (r_ppn0),
        .r_tlb_plv0         (r_plv0),
        .r_tlb_mat0         (r_mat0),
        .r_tlb_d0           (r_d0),
        .r_tlb_v0           (r_v0),
        .r_tlb_ppn1         (r_ppn1),
        .r_tlb_plv1         (r_plv1),
        .r_tlb_mat1         (r_mat1),
        .r_tlb_d1           (r_d1),
        .r_tlb_v1           (r_v1),
        .w_tlb_e            (w_e),
        .w_tlb_ps           (w_ps),
        .w_tlb_vppn         (w_vppn),
        .w_tlb_asid         (w_asid),
        .w_tlb_g            (w_g),
        .w_tlb_ppn0         (w_ppn0),
        .w_tlb_plv0         (w_plv0),
        .w_tlb_mat0         (w_mat0),
        .w_tlb_d0           (w_d0),
        .w_tlb_v0           (w_v0),
        .w_tlb_ppn1         (w_ppn1),
        .w_tlb_plv1         (w_plv1),
        .w_tlb_mat1         (w_mat1),
        .w_tlb_d1           (w_d1),
        .w_tlb_v1           (w_v1),
        .wb_exc_type        (wb_exc_type),
        .csr_crmd_plv       (csr_crmd_plv),
        .csr_crmd_da        (csr_crmd_da),
        .csr_crmd_pg        (csr_crmd_pg),
        .csr_crmd_datf      (csr_crmd_datf),
        .csr_crmd_datm      (csr_crmd_datm),
        .csr_dmw0_plv0      (csr_dmw0_plv0),
        .csr_dmw0_plv3      (csr_dmw0_plv3),
        .csr_dmw0_mat       (csr_dmw0_mat),
        .csr_dmw0_pseg      (csr_dmw0_pseg),
        .csr_dmw0_vseg      (csr_dmw0_vseg),
        .csr_dmw1_plv0      (csr_dmw1_plv0),
        .csr_dmw1_plv3      (csr_dmw1_plv3),
        .csr_dmw1_mat       (csr_dmw1_mat),
        .csr_dmw1_pseg      (csr_dmw1_pseg),
        .csr_dmw1_vseg      (csr_dmw1_vseg),
        .refetch            (refetch),
        .flush              (flush),
        .flush_pc           (flush_pc)
    );
    //TLB
    tlb #(.TLBNUM(16)) 
        my_tlb(
        .clk        (aclk),

        .s0_vppn    (s0_vppn),
        .s0_va_bit12(s0_va_bit12),
        .s0_asid    (s0_asid),
        .s0_found   (s0_found),
        .s0_index   (s0_index),
        .s0_ppn     (s0_ppn),
        .s0_ps      (s0_ps),
        .s0_plv     (s0_plv),
        .s0_mat     (s0_mat),
        .s0_d       (s0_d),
        .s0_v       (s0_v),

        .s1_vppn    (s1_vppn),
        .s1_va_bit12(s1_va_bit12),
        .s1_asid    (s1_asid),
        .s1_found   (s1_found),
        .s1_index   (s1_index),
        .s1_ppn     (s1_ppn),
        .s1_ps      (s1_ps),
        .s1_plv     (s1_plv),
        .s1_mat     (s1_mat),
        .s1_d       (s1_d),
        .s1_v       (s1_v),

        .invtlb_op  (invtlb_op),
        .invtlb_valid(invtlb_valid),

        .we         (we),
        .w_index    (w_index),
        .w_e        (w_e),
        .w_vppn     (w_vppn),
        .w_ps       (w_ps),
        .w_asid     (w_asid),
        .w_g        (w_g),

        .w_ppn0     (w_ppn0),
        .w_plv0     (w_plv0),
        .w_mat0     (w_mat0),
        .w_d0       (w_d0),
        .w_v0       (w_v0),

        .w_ppn1     (w_ppn1),
        .w_plv1     (w_plv1),
        .w_mat1     (w_mat1),
        .w_d1       (w_d1),
        .w_v1       (w_v1),

        .r_index    (r_index),
        .r_e        (r_e),
        .r_vppn     (r_vppn),
        .r_ps       (r_ps),
        .r_asid     (r_asid),
        .r_g        (r_g),

        .r_ppn0     (r_ppn0),
        .r_plv0     (r_plv0),
        .r_mat0     (r_mat0),
        .r_d0       (r_d0),
        .r_v0       (r_v0),

        .r_ppn1     (r_ppn1),
        .r_plv1     (r_plv1),
        .r_mat1     (r_mat1),
        .r_d1       (r_d1),
        .r_v1       (r_v1)
    );
    wire [18:0]                         s0_vppn;
    wire                                s0_va_bit12;
    wire [ 9:0]                         s0_asid;
    wire                                s0_found;
    wire [ 3:0]                         s0_index;
    wire [19:0]                         s0_ppn;
    wire [ 5:0]                         s0_ps;
    wire [ 1:0]                         s0_plv;
    wire [ 1:0]                         s0_mat;
    wire                                s0_d;
    wire                                s0_v;
    wire [18:0]                         s1_vppn;
    wire                                s1_va_bit12;
    wire [ 9:0]                         s1_asid;
    wire                                s1_found;
    wire [ 3:0]                         s1_index;
    wire [19:0]                         s1_ppn;
    wire [ 5:0]                         s1_ps;
    wire [ 1:0]                         s1_plv;
    wire [ 1:0]                         s1_mat;
    wire                                s1_d;
    wire                                s1_v;
    wire [ 4:0]                         invtlb_op;
    wire                                invtlb_valid;
    wire                                we;
    wire [ 3:0]                         w_index;
    wire                                w_e;
    wire [18:0]                         w_vppn;
    wire [ 5:0]                         w_ps;
    wire [ 9:0]                         w_asid;
    wire                                w_g;
    wire [19:0]                         w_ppn0;
    wire [ 1:0]                         w_plv0;
    wire [ 1:0]                         w_mat0;
    wire                                w_d0;
    wire                                w_v0;
    wire [19:0]                         w_ppn1;
    wire [ 1:0]                         w_plv1;
    wire [ 1:0]                         w_mat1;
    wire                                w_d1;
    wire                                w_v1;
    wire [ 3:0]                         r_index;
    wire                                r_e;
    wire [18:0]                         r_vppn;
    wire [ 5:0]                         r_ps;
    wire [ 9:0]                         r_asid;
    wire                                r_g;
    wire [19:0]                         r_ppn0;
    wire [ 1:0]                         r_plv0;
    wire [ 1:0]                         r_mat0;
    wire                                r_d0;
    wire                                r_v0;
    wire [19:0]                         r_ppn1;
    wire [ 1:0]                         r_plv1;
    wire [ 1:0]                         r_mat1;
    wire                                r_d1;
    wire                                r_v1;

    assign s0_asid = csr_asid_asid;
endmodule