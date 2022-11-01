`include "mycpu.h"
module preIF (
    input                            clk              ,
    input                            resetn           ,

    input                            if_allowin       ,
    input                            if_block   ,

    output [31:0] pf_if_bus    ,
    output                           pf_if_valid  ,

    input [`ID_IF_BUS_WDTH - 1:0] id_if_bus           ,

    output                           inst_sram_req,
    output                           inst_sram_wr,
    output [ 1:0]                    inst_sram_size,
    output [ 3:0]                    inst_sram_wstrb,
    output [31:0]                    inst_sram_addr,
    output [31:0]                    inst_sram_wdata,
    input                            inst_sram_addr_ok,
    input                            inst_sram_data_ok,
    input  [31:0]                    inst_sram_rdata,

    input                            wb_exc,
    input                            ertn_flush,
    input  [31:0]                    exc_entaddr,
    input  [31:0]                    exc_retaddr
);

    reg  pf_valid;
    wire pf_ready_go;
    
    reg        inst_sram_addr_ok_reg;
    reg        inst_sram_data_ok_reg;
    reg [31:0] inst_buff;

    wire br_stall;
    wire br_taken;
    wire [31:0]  br_target;
    assign {br_taken, br_stall, br_target} = id_if_bus;
    reg        br_taken_reg;
    reg [31:0] br_target_reg;

    reg  [31:0] pf_pc;
    wire [31:0] nextpc;
    wire [31:0] seq_pc;

    reg        wb_exc_reg;
    reg        ertn_flush_reg;
    reg [31:0] exc_entaddr_reg;
    reg [31:0] exc_retaddr_reg;

    reg inst_cancel;

    //control signals
    assign pf_ready_go = (inst_sram_addr_ok && inst_sram_req) || inst_sram_addr_ok_reg && ~(ertn_flush | wb_exc);
    assign pf_if_valid = pf_valid && pf_ready_go;
    always @(posedge clk) begin
        if (~resetn) begin
            pf_valid <= 1'b0;
        end
        else begin
            pf_valid <= 1'b1;
        end
    end

    //to fs
    assign pf_if_bus = nextpc;

    //inst_sram
    always @(posedge clk) begin
        if (~resetn) begin
            inst_sram_addr_ok_reg <= 1'b0;
        end else if (inst_sram_addr_ok && inst_sram_req && !if_allowin) begin
            inst_sram_addr_ok_reg <= 1'b1;
        end else if (if_allowin || (ertn_flush | wb_exc)) begin
            inst_sram_addr_ok_reg <= 1'b0;
        end
    end

    always @(posedge clk ) begin
        if (~resetn || if_allowin || (ertn_flush | wb_exc)) begin
            inst_sram_data_ok_reg <= 1'b0;
            inst_buff <= 32'b0;
        end else if (inst_sram_data_ok && if_block && !inst_cancel) begin
            inst_sram_data_ok_reg <= 1'b1;
            inst_buff <= inst_sram_rdata;
        end
    end

    assign inst_sram_req = pf_valid && !inst_sram_addr_ok_reg && !br_stall && if_allowin;
    assign inst_sram_wr = 1'b0;
    assign inst_sram_size = 2'b10;
    assign inst_sram_wstrb = 4'b0;
    assign inst_sram_wdata = 32'b0;
    assign inst_sram_addr = nextpc;

    always @(posedge clk ) begin
        if (~resetn) begin
            inst_cancel <= 1'b0;
        end else if (pf_ready_go && ((ertn_flush | wb_exc) || (ertn_flush_reg | wb_exc_reg) || br_taken || br_taken_reg)) begin
            inst_cancel <= 1'b1;
        end else if (inst_sram_data_ok) begin
            inst_cancel <= 1'b0;
        end
    end
  
    always @(posedge clk) begin
        if (~resetn) begin
            br_taken_reg <= 1'b0;
            br_target_reg <= 32'b0;
        end else if (pf_ready_go && if_allowin)begin
            br_taken_reg <= 1'b0;
            br_target_reg <= 32'b0;
        end else if (br_taken && !br_stall) begin
            br_taken_reg <= 1'b1;
            br_target_reg <= br_target;
        end
    end
    always @(posedge clk) begin
        if (~resetn) begin
            wb_exc_reg <= 1'b0;
            ertn_flush_reg <= 1'b0;
            exc_entaddr_reg <= 32'b0;
            exc_retaddr_reg <= 32'b0;
        end else if (pf_ready_go && if_allowin)begin
            wb_exc_reg <= 1'b0;
            ertn_flush_reg <= 1'b0;
            exc_entaddr_reg <= 32'b0;
            exc_retaddr_reg <= 32'b0;
        end else if (wb_exc) begin
            wb_exc_reg <= 1'b1;
            exc_entaddr_reg <= exc_entaddr;
        end else if (ertn_flush) begin
            ertn_flush_reg <= 1'b1;
            exc_retaddr_reg <= exc_retaddr;
        end
    end
    
    assign seq_pc = pf_pc + 32'h4;
    assign nextpc   = wb_exc   ? exc_entaddr       :
                      wb_exc_reg   ? exc_entaddr_reg   :
                      ertn_flush  ? exc_retaddr     :
                      ertn_flush_reg  ? exc_retaddr_reg :
                      br_taken_reg ? br_target_reg   :
                      (br_taken && !br_stall) ? br_target :seq_pc;
    always @(posedge clk ) begin
        if (~resetn) begin
            pf_pc <= 32'h1bfffffc;
        end else if (pf_ready_go && if_allowin) begin
            pf_pc <= nextpc;
        end
    end
endmodule