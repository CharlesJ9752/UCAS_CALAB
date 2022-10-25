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
    output        has_int
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
            csr_prmd_pplv <= csr_wmask[`CSR_PRMD_PPLV]&csr_wdata[`CSR_PRMD_PPLV] | ~csr_wmask[`CSR_PRMD_PPLV]&csr_prmd_pplv;
            csr_prmd_pie <= csr_wmask[`CSR_PRMD_PIE]&csr_wdata[`CSR_PRMD_PIE] | ~csr_wmask[`CSR_PRMD_PIE]&csr_prmd_pie;
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
            csr_ecfg_lie <= csr_wmask[`CSR_ECFG_LIE]&csr_wdata[`CSR_ECFG_LIE] | ~csr_wmask[`CSR_ECFG_LIE]&csr_ecfg_lie;
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
            csr_estat_is[1:0] <= csr_wmask[`CSR_ESTAT_IS10]&csr_wdata[`CSR_ESTAT_IS10] | ~csr_wmask[`CSR_ESTAT_IS10]&csr_estat_is[1:0];
        csr_estat_is[9:2] <= 8'b0;//hwint=0
        csr_estat_is[10] <= 1'b0;//eternal 0
        csr_estat_is[11] <= 1'b0;//exp13要改
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
    assign has_int     = (|(csr_estat_is & csr_ecfg_lie)) & csr_crmd_ie;
    assign csr_rdata =  {32{csr_raddr == `CSR_CRMD  }} & csr_crmd_rdata     |
                        {32{csr_raddr == `CSR_PRMD  }} & csr_prmd_rdata     |
                        {32{csr_raddr == `CSR_ESTAT }} & csr_estat_rdata    |
                        {32{csr_raddr == `CSR_ERA   }} & csr_era_rdata      |
                        {32{csr_raddr == `CSR_EENTRY}} & csr_eentry_rdata   |
                        {32{csr_raddr == `CSR_SAVE0 }} & csr_save0_rdata    |
                        {32{csr_raddr == `CSR_SAVE1 }} & csr_save1_rdata    |
                        {32{csr_raddr == `CSR_SAVE2 }} & csr_save2_rdata    |
                        {32{csr_raddr == `CSR_SAVE3 }} & csr_save3_rdata    ;

endmodule