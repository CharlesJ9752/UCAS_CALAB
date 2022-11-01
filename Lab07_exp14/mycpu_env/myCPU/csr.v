`include "mycpu.h"
module csr(
    input clk,
    input resetn,

    input         csr_we,
    input  [13:0] csr_waddr,
    input  [31:0] csr_wmask,
    input  [31:0] csr_wdata,
    input  [13:0] csr_raddr,
    output [31:0] csr_rdata,
    output [31:0] exc_entaddr,
    output [31:0] exc_retaddr,
    input         wb_exc,
    input  [ 5:0] wb_ecode,
    input  [ 8:0] wb_esubcode,
    input  [31:0] wb_pc,
    input         ertn_flush,
    output        has_int,


    //exp13 jyh
    input  [31:0] wb_badvaddr
);

    //CRMD
    reg     [ 1:0]  csr_crmd_plv;
    reg             csr_crmd_ie;
    reg             csr_crmd_da;
    reg             csr_crmd_pg;
    wire    [31:0]  csr_crmd_rdata;
    //CRMD-PLV
    always @(posedge clk) begin
        if (~resetn)
            csr_crmd_plv <= 2'b0;
        else if (wb_exc)
            csr_crmd_plv <= 2'b0;
        else if (ertn_flush)
            csr_crmd_plv <= csr_prmd_pplv;
        else if (csr_we && csr_waddr==`CSR_CRMD)
            csr_crmd_plv <= csr_wmask[`CSR_CRMD_PLV]&csr_wdata[`CSR_CRMD_PLV]| ~csr_wmask[`CSR_CRMD_PLV]&csr_crmd_plv;
    end
    //CRMD-IE
    always @(posedge clk) begin
        if (~resetn)
            csr_crmd_ie <= 1'b0;
        else if (wb_exc)
            csr_crmd_ie <= 1'b0;
        else if (ertn_flush)
            csr_crmd_ie <= csr_prmd_pie;
        else if (csr_we && csr_waddr==`CSR_CRMD)
            csr_crmd_ie <= csr_wmask[`CSR_CRMD_PIE]&csr_wdata[`CSR_CRMD_PIE]| ~csr_wmask[`CSR_CRMD_PIE]&csr_crmd_ie;
    end
    //CRMD-DA
    always @(posedge clk) begin
        if (ertn_flush&&csr_estat_ecode==6'h3f)
            csr_crmd_da <= 1'b0;
        else 
            csr_crmd_da <= 1'b1;
    end
    //CRMD-PG
    always @(posedge clk) begin
        if (ertn_flush&&csr_estat_ecode==6'h3f)
            csr_crmd_pg <= 1'b1;
        else 
            csr_crmd_pg <= 1'b0;
    end
    assign  csr_crmd_rdata = {27'b0, csr_crmd_pg, csr_crmd_da, csr_crmd_ie, csr_crmd_plv};


    //PRMD
    reg     [ 1:0]  csr_prmd_pplv;
    reg             csr_prmd_pie;
    wire    [31:0]  csr_prmd_rdata;
    //PRMD-PPLV,PIE
    always @(posedge clk) begin
        if (wb_exc) begin
            csr_prmd_pplv <= csr_crmd_plv;
            csr_prmd_pie <= csr_crmd_ie;
        end
        else if (csr_we && csr_waddr==`CSR_PRMD) begin
            csr_prmd_pplv <= csr_wmask[`CSR_PRMD_PPLV]&csr_wdata[`CSR_PRMD_PPLV] 
            | ~csr_wmask[`CSR_PRMD_PPLV]&csr_prmd_pplv;
            csr_prmd_pie <= csr_wmask[`CSR_PRMD_PIE]&csr_wdata[`CSR_PRMD_PIE] 
            | ~csr_wmask[`CSR_PRMD_PIE]&csr_prmd_pie;
        end
    end
    assign  csr_prmd_rdata = {29'b0, csr_prmd_pie, csr_prmd_pplv};

    //ECFG
    reg     [12:0]  csr_ecfg_lie;
    wire    [31:0]  csr_ecfg_rdata;
    //ECFG-LIE
    always @(posedge clk) begin
        if (~resetn)
            csr_ecfg_lie <= 13'b0;
        else if (csr_we && csr_waddr==`CSR_ECFG)
            csr_ecfg_lie <= csr_wmask[`CSR_ECFG_LIE]&csr_wdata[`CSR_ECFG_LIE] 
            | ~csr_wmask[`CSR_ECFG_LIE]&csr_ecfg_lie;
    end
    assign  csr_ecfg_rdata = {19'b0, csr_ecfg_lie};

    //ESTAT
    reg     [ 5:0]  csr_estat_ecode;
    reg     [ 8:0]  csr_estat_esubcode;
    reg     [12:0]  csr_estat_is;
    wire    [31:0]  csr_estat_rdata;
    always @(posedge clk) begin
        if (~resetn)
            csr_estat_is[1:0] <= 2'b0;
        else if (csr_we && csr_waddr==`CSR_ESTAT)
            csr_estat_is[1:0] <= csr_wmask[`CSR_ESTAT_IS10]&csr_wdata[`CSR_ESTAT_IS10] 
            | ~csr_wmask[`CSR_ESTAT_IS10]&csr_estat_is[1:0];
        csr_estat_is[9:2] <= 8'b0;//hwint=0
        csr_estat_is[10] <= 1'b0;//eternal 0
        if (csr_tcfg_en & timer_cnt == 32'b0) begin
            csr_estat_is[11] <= 1'b1;
        end
        else if (csr_we && csr_waddr == `CSR_TICLR    &&
                               csr_wmask[`CSR_TICLR_CLR] &&
                               csr_wdata[`CSR_TICLR_CLR]) begin
            csr_estat_is[11] <= 1'b0;//软件通过向CLR写1来将estatis第十一位清零
        end
        csr_estat_is[12] <= 1'b0;//ipiint=0
    end
    always @(posedge clk) begin
        if (wb_exc) begin
            csr_estat_ecode <= wb_ecode;
            csr_estat_esubcode <= wb_esubcode;
        end
    end
    assign  csr_estat_rdata = {
        1'b0, csr_estat_esubcode, csr_estat_ecode, 3'b0, csr_estat_is
    };

    //ERA
    reg     [31:0]  csr_era_pc;
    wire    [31:0]  csr_era_rdata;
    //ERA-PC
    always @(posedge clk) begin
        if (wb_exc)
            csr_era_pc <= wb_pc;
        else if (csr_we && csr_waddr==`CSR_ERA)
            csr_era_pc <= csr_wmask[`CSR_ERA_PC]&csr_wdata[`CSR_ERA_PC] | ~csr_wmask[`CSR_ERA_PC]&csr_era_pc;
    end
    assign  csr_era_rdata = csr_era_pc;

    //EENTRY
    reg     [25:0]  csr_eentry_va;
    wire    [31:0]  csr_eentry_rdata;
    //EENTRY-VA
    always @(posedge clk) begin
        if (csr_we && csr_waddr==`CSR_EENTRY)
            csr_eentry_va <= csr_wmask[`CSR_EENTRY_VA]&csr_wdata[`CSR_EENTRY_VA] | ~csr_wmask[`CSR_EENTRY_VA]&csr_eentry_va;
    end
    assign  csr_eentry_rdata = {
        csr_eentry_va , 6'b0 
    };

    //SAVE 0~3
    reg     [31:0]  csr_save0_data;
    reg     [31:0]  csr_save1_data;
    reg     [31:0]  csr_save2_data;
    reg     [31:0]  csr_save3_data;
    wire    [31:0]  csr_save0_rdata;
    wire    [31:0]  csr_save1_rdata;
    wire    [31:0]  csr_save2_rdata;
    wire    [31:0]  csr_save3_rdata;
    //SAVE 0~3
    always @(posedge clk) begin
        if (csr_we && csr_waddr==`CSR_SAVE0)
            csr_save0_data <= csr_wmask[`CSR_SAVE_DATA]&csr_wdata[`CSR_SAVE_DATA] | ~csr_wmask[`CSR_SAVE_DATA]&csr_save0_data;
        if (csr_we && csr_waddr==`CSR_SAVE1)
            csr_save1_data <= csr_wmask[`CSR_SAVE_DATA]&csr_wdata[`CSR_SAVE_DATA] | ~csr_wmask[`CSR_SAVE_DATA]&csr_save1_data;
        if (csr_we && csr_waddr==`CSR_SAVE2)
            csr_save2_data <= csr_wmask[`CSR_SAVE_DATA]&csr_wdata[`CSR_SAVE_DATA] | ~csr_wmask[`CSR_SAVE_DATA]&csr_save2_data;
        if (csr_we && csr_waddr==`CSR_SAVE3)
            csr_save3_data <= csr_wmask[`CSR_SAVE_DATA]&csr_wdata[`CSR_SAVE_DATA] | ~csr_wmask[`CSR_SAVE_DATA]&csr_save3_data;
    end
    assign {
        csr_save0_rdata, csr_save1_rdata, csr_save2_rdata, csr_save3_rdata
    } = {
        csr_save0_data,  csr_save1_data,  csr_save2_data,  csr_save3_data
    };
    assign exc_entaddr  = csr_eentry_rdata;
    assign exc_retaddr  = csr_era_rdata;
    //TCFG
    reg         csr_tcfg_en;
    reg         csr_tcfg_periodic;
    reg  [29:0] csr_tcfg_initdata;
    wire [31:0] csr_tcfg_rdata;
    always @ (posedge clk) begin
        if (~resetn) begin
            csr_tcfg_en <= 1'b0;
        end else if (csr_we && csr_waddr == `CSR_TCFG) begin
            csr_tcfg_en      <= csr_wmask[`CSR_TCFG_EN] & csr_wdata[`CSR_TCFG_EN] |
                               ~csr_wmask[`CSR_TCFG_EN] & csr_tcfg_en;
            csr_tcfg_periodic  <= csr_wmask[`CSR_TCFG_PERIOD] & csr_wdata[`CSR_TCFG_PERIOD] |
                               ~csr_wmask[`CSR_TCFG_PERIOD] & csr_tcfg_periodic;
            csr_tcfg_initdata <= csr_wmask[`CSR_TCFG_INITVAL] & csr_wdata[`CSR_TCFG_INITVAL] |
                               ~csr_wmask[`CSR_TCFG_INITVAL] & csr_tcfg_initdata;
        end
    end
    assign csr_tcfg_rdata = {csr_tcfg_initdata, csr_tcfg_periodic, csr_tcfg_en};

    //TVAL
    wire [31:0] tcfg_next_data;
    wire [31:0] csr_tval_rdata;
    reg  [31:0] timer_cnt;
    assign      tcfg_next_data = csr_wmask & csr_wdata |~csr_wmask & csr_tcfg_rdata;
    always @ (posedge clk) begin
        if (~resetn) begin
            timer_cnt <= 32'hffffffff;
        end 
        else if (csr_we && csr_waddr == `CSR_TCFG && tcfg_next_data[`CSR_TCFG_EN]) begin
            timer_cnt <= {tcfg_next_data[`CSR_TCFG_INITVAL], 2'b0};
        end 
        else if (csr_tcfg_en && timer_cnt != 32'hffffffff) begin
            if (timer_cnt == 32'b0 && csr_tcfg_periodic) begin
                timer_cnt <= {csr_tcfg_initdata, 2'b0};
            end 
            else begin
                timer_cnt <= timer_cnt - 1'b1;
            end
        end
    end
    assign csr_tval_rdata = timer_cnt;
    
    //TICLR
    wire    [31:0] csr_ticlr_rdata;
    assign  csr_ticlr_rdata = 32'b0;

    //TID
    reg     [31:0] csr_tid_tid;
    wire    [31:0] csr_tid_rdata;
    always @ (posedge clk) begin
        if (~resetn) begin
            csr_tid_tid <= 32'b0;
        end else if (csr_we && csr_waddr == `CSR_TID) begin
            csr_tid_tid <= csr_wmask[`CSR_TID_TID] & csr_wdata[`CSR_TID_TID]
                        | ~csr_wmask[`CSR_TID_TID] & csr_tid_tid;
        end
    end
    assign  csr_tid_rdata = csr_tid_tid;
    
    //BADV
    reg  [31:0] csr_badv_vaddr;
    wire [31:0] csr_badv_rdata;
    assign wb_exc_addr_err = wb_ecode==`EXC_ECODE_ADE || wb_ecode==`EXC_ECODE_ALE;
    always @(posedge clk) begin
        if (wb_exc && wb_exc_addr_err)
            csr_badv_vaddr <= (wb_ecode==`EXC_ECODE_ADE && 
                               wb_esubcode==`EXC_ESUBCODE_ADEF) ? wb_pc : wb_badvaddr;
    end
    assign csr_badv_rdata = csr_badv_vaddr;
    assign has_int = ((csr_estat_is[11:0] & csr_ecfg_lie[11:0]) != 12'b0)
                        && (csr_crmd_ie == 1'b1);
    assign csr_rdata =  {32{csr_raddr == `CSR_CRMD  }} & csr_crmd_rdata     |
                        {32{csr_raddr == `CSR_PRMD  }} & csr_prmd_rdata     |
                        {32{csr_raddr == `CSR_ESTAT }} & csr_estat_rdata    |
                        {32{csr_raddr == `CSR_ERA   }} & csr_era_rdata      |
                        {32{csr_raddr == `CSR_EENTRY}} & csr_eentry_rdata   |
                        {32{csr_raddr == `CSR_SAVE0 }} & csr_save0_rdata    |
                        {32{csr_raddr == `CSR_SAVE1 }} & csr_save1_rdata    |
                        {32{csr_raddr == `CSR_SAVE2 }} & csr_save2_rdata    |
                        {32{csr_raddr == `CSR_SAVE3 }} & csr_save3_rdata    |
                        {32{csr_raddr == `CSR_ECFG  }} & csr_ecfg_rdata    |
                        {32{csr_raddr == `CSR_BADV  }} & csr_badv_rdata    |
                        {32{csr_raddr == `CSR_TID   }} & csr_tid_rdata     |
                        {32{csr_raddr == `CSR_TCFG  }} & csr_tcfg_rdata    |
                        {32{csr_raddr == `CSR_TVAL  }} & csr_tval_rdata    |
                        {32{csr_raddr == `CSR_TICLR }} & csr_ticlr_rdata;

endmodule