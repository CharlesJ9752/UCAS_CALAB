`include "csr.h"

module csr(
    input         clk,
    input         reset,

    input         csr_we,
    input [13:0]  csr_wnum,
    input [13:0]  csr_rnum,
    input [31:0]  csr_wvalue,
    output [31:0] csr_rvalue,
    input [31:0]  csr_wmask,

    output        has_int,
    input         ertn_flush, //ertn valid

    input         wb_exc,
    input [ 5:0]  wb_ecode,
    input [ 8:0]  wb_esubcode,
    input [31:0]  wb_pc,//for exp13 ADEF record wrong pc
    input [31:0]  wb_vaddr, //for exp13 ALE record wrong vaddr

    output [31:0] exc_entry,
    output [31:0] exc_retaddr
);

    reg  [ 1:0] csr_crmd_plv;
    reg         csr_crmd_ie;
    wire [31:0] csr_crmd_rvalue;

    reg  [ 1:0] csr_prmd_pplv;
    reg         csr_prmd_pie;
    wire [31:0] csr_prmd_rvalue;

    reg  [12:0] csr_estat_is;
    reg  [ 5:0] csr_estat_ecode;
    reg  [ 8:0] csr_estat_esubcode;
    wire [31:0] csr_estat_rvalue;
    
    reg  [31:0] csr_era_pc;
    wire [31:0] csr_era_rvalue;

    reg  [25:0] csr_eentry_va;
    wire [31:0] csr_eentry_rvalue;

    reg  [31:0] csr_save0_data;
    reg  [31:0] csr_save1_data;
    reg  [31:0] csr_save2_data;
    reg  [31:0] csr_save3_data;

    reg  [12:0] csr_ecfg_lie;
    wire [31:0] csr_ecfg_rvalue;
    
    wire        wb_exc_addr; //ADEF+ALE
    reg  [31:0] csr_badv_vaddr;
    wire [31:0] csr_badv_rvalue;

    reg  [31:0] csr_tid_tid; 
    wire [31:0] csr_tid_rvalue; //rdcntid

    reg         csr_tcfg_en;
    reg         csr_tcfg_periodic;
    reg  [29:0] csr_tcfg_initval;
    wire [31:0] csr_tcfg_rvalue;

    wire [31:0] tcfg_next_value;
    reg  [31:0] timer_cnt;
    wire [31:0] csr_tval_rvalue;

    wire        csr_ticlr_clr;
    wire [31:0] csr_ticlr_rvalue;

//CRMD PLV
always @(posedge clk) begin
    if (reset)
        csr_crmd_plv <= 2'b0;
    else if (wb_exc)
        csr_crmd_plv <= 2'b0;
    else if (ertn_flush)
        csr_crmd_plv <= csr_prmd_pplv;
    else if (csr_we && csr_wnum==`CSR_CRMD)
        csr_crmd_plv <= csr_wmask[`CSR_CRMD_PLV]&csr_wvalue[`CSR_CRMD_PLV]
                        |~csr_wmask[`CSR_CRMD_PLV]&csr_crmd_plv;
end
//CRMD IE
always @(posedge clk) begin
    if (reset)
        csr_crmd_ie <= 1'b0;
    else if (wb_exc)
        csr_crmd_ie <= 1'b0;
    else if (ertn_flush)
        csr_crmd_ie <= csr_prmd_pie;
    else if (csr_we && csr_wnum==`CSR_CRMD)
        csr_crmd_ie <= csr_wmask[`CSR_CRMD_IE]&csr_wvalue[`CSR_CRMD_IE]
                       | ~csr_wmask[`CSR_CRMD_IE]&csr_crmd_ie;
end
assign csr_crmd_rvalue = {28'b0, 1'b1, csr_crmd_ie, csr_crmd_plv};

//PRMD PPLV + PIE
always @(posedge clk) begin
    if (wb_exc) begin
        csr_prmd_pplv <= csr_crmd_plv;
        csr_prmd_pie <= csr_crmd_ie;
    end
    else if (csr_we && csr_wnum==`CSR_PRMD) begin
        csr_prmd_pplv <= csr_wmask[`CSR_PRMD_PPLV]&csr_wvalue[`CSR_PRMD_PPLV] | 
                        ~csr_wmask[`CSR_PRMD_PPLV]&csr_prmd_pplv;
        csr_prmd_pie <= csr_wmask[`CSR_PRMD_PIE]&csr_wvalue[`CSR_PRMD_PIE] | 
                       ~csr_wmask[`CSR_PRMD_PIE]&csr_prmd_pie;
    end
end
assign csr_prmd_rvalue = {29'b0, csr_prmd_pie, csr_prmd_pplv};

//ESTAT IS
always @(posedge clk) begin
    if (reset)
        csr_estat_is[1:0] <= 2'b0;
    else if (csr_we && csr_wnum==`CSR_ESTAT)
        csr_estat_is[1:0] <= csr_wmask[`CSR_ESTAT_IS10]&csr_wvalue[`CSR_ESTAT_IS10]
                             | ~csr_wmask[`CSR_ESTAT_IS10]&csr_estat_is[1:0];
        csr_estat_is[9:2] <= 8'b0; //hardware int
        csr_estat_is[10] <= 1'b0;
        if (timer_cnt[31:0]==32'b0)
            csr_estat_is[11] <= 1'b1;
        else if (csr_we && csr_wnum==`CSR_TICLR && csr_wmask[`CSR_TICLR_CLR]&& csr_wvalue[`CSR_TICLR_CLR])
            csr_estat_is[11] <= 1'b0;
            csr_estat_is[12] <= 1'b0; //ipi int
end
//ESTAT Ecode + EsubCode
always @(posedge clk) begin
    if (wb_exc) begin
        csr_estat_ecode <= wb_ecode;
        csr_estat_esubcode <= wb_esubcode;
    end
end
assign csr_estat_rvalue = {1'b0,csr_estat_esubcode,csr_estat_ecode,3'b0,csr_estat_is};

// ERA
always @ (posedge clk) begin
    if (wb_exc) begin
        csr_era_pc <= wb_pc;
    end else if (csr_we && csr_wnum == `CSR_ERA) begin
        csr_era_pc <= csr_wmask[`CSR_ERA_PC] & csr_wvalue[`CSR_ERA_PC] |
                     ~csr_wmask[`CSR_ERA_PC] & csr_era_pc;
    end
end
assign csr_era_rvalue = csr_era_pc;

//EENTRY VA
always @(posedge clk) begin
    if (csr_we && csr_wnum==`CSR_EENTRY)
            csr_eentry_va <= csr_wmask[`CSR_EENTRY_VA] & csr_wvalue[`CSR_EENTRY_VA] |
                            ~csr_wmask[`CSR_EENTRY_VA] & csr_eentry_va;
        
end
assign csr_eentry_rvalue = {csr_eentry_va, 6'b0};


//SAVE0~3
always @(posedge clk) begin
    if (csr_we && csr_wnum==`CSR_SAVE0)
        csr_save0_data <= csr_wmask[`CSR_SAVE_DATA]&csr_wvalue[`CSR_SAVE_DATA]
                          | ~csr_wmask[`CSR_SAVE_DATA]&csr_save0_data;
    if (csr_we && csr_wnum==`CSR_SAVE1)
        csr_save1_data <= csr_wmask[`CSR_SAVE_DATA]&csr_wvalue[`CSR_SAVE_DATA]
                          | ~csr_wmask[`CSR_SAVE_DATA]&csr_save1_data;
    if (csr_we && csr_wnum==`CSR_SAVE2)
        csr_save2_data <= csr_wmask[`CSR_SAVE_DATA]&csr_wvalue[`CSR_SAVE_DATA]
                          | ~csr_wmask[`CSR_SAVE_DATA]&csr_save2_data;
    if (csr_we && csr_wnum==`CSR_SAVE3)
        csr_save3_data <= csr_wmask[`CSR_SAVE_DATA]&csr_wvalue[`CSR_SAVE_DATA]
                          | ~csr_wmask[`CSR_SAVE_DATA]&csr_save3_data;
end

//ECFG LIE
always @(posedge clk) begin
    if (reset)
        csr_ecfg_lie <= 13'b0;
    else if (csr_we && csr_wnum==`CSR_ECFG)
        csr_ecfg_lie <= csr_wmask[`CSR_ECFG_LIE]&csr_wvalue[`CSR_ECFG_LIE]
                        | ~csr_wmask[`CSR_ECFG_LIE]&csr_ecfg_lie;
end
assign csr_ecfg_rvalue = {19'b0,csr_ecfg_lie};

//BADV Vaddr
assign wb_exc_addr = wb_ecode==`ECODE_ADE || wb_ecode==`ECODE_ALE;
always @(posedge clk) begin
    if (wb_exc && wb_exc_addr)
        csr_badv_vaddr <= (wb_ecode==`ECODE_ADE && wb_esubcode==`ESUBCODE_ADEF) ? wb_pc : wb_vaddr;
end
assign csr_badv_rvalue = csr_badv_vaddr;

//TID
always @(posedge clk) begin
    if (reset)
        csr_tid_tid <= 32'b0;
    else if (csr_we && csr_wnum==`CSR_TID)
        csr_tid_tid <= csr_wmask[`CSR_TID_TID]&csr_wvalue[`CSR_TID_TID]
                       | ~csr_wmask[`CSR_TID_TID]&csr_tid_tid;
end
assign csr_tid_rvalue = csr_tid_tid;

//TCFG En + Periodic + InitVal
always @(posedge clk) begin
    if (reset)
        csr_tcfg_en <= 1'b0;
    else if (csr_we && csr_wnum==`CSR_TCFG)
        csr_tcfg_en <= csr_wmask[`CSR_TCFG_EN]&csr_wvalue[`CSR_TCFG_EN]
                       | ~csr_wmask[`CSR_TCFG_EN]&csr_tcfg_en;
    if (csr_we && csr_wnum==`CSR_TCFG) begin
        csr_tcfg_periodic <= csr_wmask[`CSR_TCFG_PERIOD]&csr_wvalue[`CSR_TCFG_PERIOD]
                             | ~csr_wmask[`CSR_TCFG_PERIOD]&csr_tcfg_periodic;
        csr_tcfg_initval <= csr_wmask[`CSR_TCFG_INITVAL]&csr_wvalue[`CSR_TCFG_INITVAL]
                            | ~csr_wmask[`CSR_TCFG_INITVAL]&csr_tcfg_initval;
    end
end
assign csr_tcfg_rvalue = {csr_tcfg_initval,csr_tcfg_periodic,csr_tcfg_en};

//TVAL TimeVal
assign tcfg_next_value = csr_wmask[31:0] & csr_wvalue[31:0]
                         | ~csr_wmask[31:0] & csr_tcfg_rvalue;
always @(posedge clk) begin
    if (reset)
        timer_cnt <= 32'hffffffff;
    else if (csr_we && csr_wnum==`CSR_TCFG && tcfg_next_value[`CSR_TCFG_EN])
        timer_cnt <= {tcfg_next_value[`CSR_TCFG_INITVAL], 2'b0};
    else if (csr_tcfg_en && timer_cnt!=32'hffffffff) begin
        if (timer_cnt[31:0]==32'b0 && csr_tcfg_periodic)
            timer_cnt <= {csr_tcfg_initval, 2'b0};
        else
            timer_cnt <= timer_cnt - 1'b1;
        end
    end
assign csr_tval_rvalue = timer_cnt[31:0];

//TICLR CLR
assign csr_ticlr_clr = 1'b0;
assign csr_ticlr_rvalue = {31'b0,csr_ticlr_clr}; //can be improved (strange)

assign csr_rvalue = {32{csr_rnum == `CSR_CRMD  }} & csr_crmd_rvalue |
                    {32{csr_rnum == `CSR_PRMD  }} & csr_prmd_rvalue |
                    {32{csr_rnum == `CSR_ESTAT }} & csr_estat_rvalue |
                    {32{csr_rnum == `CSR_ERA   }} & csr_era_rvalue |
                    {32{csr_rnum == `CSR_EENTRY}} & csr_eentry_rvalue |
                    {32{csr_rnum == `CSR_SAVE0 }} & csr_save0_data |
                    {32{csr_rnum == `CSR_SAVE1 }} & csr_save1_data |
                    {32{csr_rnum == `CSR_SAVE2 }} & csr_save2_data |
                    {32{csr_rnum == `CSR_SAVE3 }} & csr_save3_data |
                    {32{csr_rnum == `CSR_ECFG  }} & csr_ecfg_rvalue |
                    {32{csr_rnum == `CSR_BADV  }} & csr_badv_rvalue |
                    {32{csr_rnum == `CSR_TID   }} & csr_tid_rvalue |
                    {32{csr_rnum == `CSR_TCFG  }} & csr_tcfg_rvalue |
                    {32{csr_rnum == `CSR_TVAL  }} & csr_tval_rvalue |
                    {32{csr_rnum == `CSR_TICLR }} & csr_ticlr_rvalue;
                      
assign has_int   = (|(csr_estat_is & csr_ecfg_lie)) & csr_crmd_ie;
assign exc_entry = csr_eentry_rvalue;
assign exc_retaddr = csr_era_rvalue;

endmodule