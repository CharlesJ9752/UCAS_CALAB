//译码，生成操作数，写回寄存器�?
module ID (
    input           clk,
    input           resetn,
    //与IF阶段
    input           if_id_valid,
    output          id_allowin,
    input   [ 63:0] if_id_bus,//pc+inst
    output  [ 32:0] id_if_bus,//en_brch+brch_addr
    //与EXE阶段
    input           exe_allowin,
    output          id_exe_valid,
    output  [179:0] id_exe_bus,
    //来自WB阶段
    input   [ 37:0] wb_id_bus,
    //来自各级的写使能和写地址信号，用于判断阻�?
    input   [ 38:0]  exe_wr_bus,
    input   [ 37:0]  mem_wr_bus
);
    //信号定义
    reg             id_valid;//指令在id�?
    wire    [31:0]  id_inst;
    wire    [31:0]  id_pc;
    wire            id_en_brch;
    wire    [31:0]  id_brch_addr;
    reg     [63:0]  if_id_bus_vld;
    //判断是否阻塞
    wire            exe_en_bypass;
    wire            exe_en_block;
    wire            exe_res_from_mem;
    wire            mem_en_bypass;
    wire            mem_en_block;
    wire    [31:0]  exe_wdata;
    wire    [31:0]  mem_wdata;
    wire    [ 4:0]  exe_dest;
    wire    [ 4:0]  mem_dest;
    wire    [ 4:0]  wb_dest;
    wire            en_brch_cancel;

    assign  {
        exe_en_bypass, exe_en_block, exe_dest, exe_wdata
    } = exe_wr_bus;
    assign  {
        mem_en_bypass, mem_dest, mem_wdata
    } = mem_wr_bus;
    assign addr1_valid = inst_add_w | inst_sub_w | inst_slt | inst_addi_w | inst_sltu | 
                            inst_nor | inst_and | inst_or | inst_xor | inst_srli_w | 
                            inst_slli_w | inst_srai_w | inst_ld_w | inst_st_w |inst_bne  | inst_beq | inst_jirl;
    assign addr2_valid = inst_add_w | inst_sub_w | inst_slt | inst_sltu | inst_and | 
                         inst_or | inst_nor | inst_xor | inst_st_w | inst_beq | inst_bne;

    assign id_ready_go = ~( exe_en_block & ((exe_dest==rf_raddr1) & addr1_valid
                                            |(exe_dest==rf_raddr2) & addr2_valid));//in case of load
    assign id_exe_valid = id_ready_go & id_valid;
    assign id_allowin = id_exe_valid & exe_allowin | ~id_valid;
    always @(posedge clk ) begin
        if(~resetn) begin
            id_valid <= 1'b0;
        end
        else if(en_brch_cancel) begin
            id_valid <= 1'b0;
        end
        else if(id_allowin) begin
            id_valid <= if_id_valid;
        end
    end
    always @(posedge clk ) begin
        if(if_id_valid & id_allowin)begin
            if_id_bus_vld <= if_id_bus;
        end
    end
    assign {
        id_pc, id_inst
    } = if_id_bus_vld;
    //译码
    wire [ 5:0] op_31_26;
    wire [ 3:0] op_25_22;
    wire [ 1:0] op_21_20;
    wire [ 4:0] op_19_15;
    wire [ 4:0] rd;
    wire [ 4:0] rj;
    wire [ 4:0] rk;
    wire [11:0] i12;
    wire [19:0] i20;
    wire [15:0] i16;
    wire [25:0] i26;

    wire [63:0] op_31_26_d;
    wire [15:0] op_25_22_d;
    wire [ 3:0] op_21_20_d;
    wire [31:0] op_19_15_d;

    wire        inst_add_w;
    wire        inst_sub_w;
    wire        inst_slt;
    wire        inst_sltu;
    wire        inst_nor;
    wire        inst_and;
    wire        inst_or;
    wire        inst_xor;
    wire        inst_slli_w;
    wire        inst_srli_w;
    wire        inst_srai_w;
    wire        inst_addi_w;
    wire        inst_ld_w;
    wire        inst_st_w;
    wire        inst_jirl;
    wire        inst_b;
    wire        inst_bl;
    wire        inst_beq;
    wire        inst_bne;
    wire        inst_lu12i_w;

    wire        need_ui5;
    wire        need_si12;
    wire        need_si16;
    wire        need_si20;
    wire        need_si26;
    wire        src2_is_4;

    wire [ 4:0] rf_raddr1;
    wire [31:0] rf_rdata1;
    wire [ 4:0] rf_raddr2;
    wire [31:0] rf_rdata2;
    wire        rf_we   ;
    wire [ 4:0] rf_waddr;
    wire [31:0] rf_wdata;
    wire [11:0] id_alu_op;
    wire [31:0] id_alu_src1   ;
    wire [31:0] id_alu_src2   ;
    wire [31:0] alu_result ;

    wire [31:0] mem_result;
    wire [31:0] final_result;
    wire [4:0]  id_dest;

    wire [31:0] imm;
    wire [31:0] rj_value;
    wire [31:0] id_rkd_value;
    wire [31:0] br_offs;

    assign op_31_26  = id_inst[31:26];
    assign op_25_22  = id_inst[25:22];
    assign op_21_20  = id_inst[21:20];
    assign op_19_15  = id_inst[19:15];

    assign rd   = id_inst[ 4: 0];
    assign rj   = id_inst[ 9: 5];
    assign rk   = id_inst[14:10];

    assign i12  = id_inst[21:10];
    assign i20  = id_inst[24: 5];
    assign i16  = id_inst[25:10];
    assign i26  = {id_inst[ 9: 0], id_inst[25:10]};

    decoder_6_64 u_dec0(.in(op_31_26 ), .out(op_31_26_d ));
    decoder_4_16 u_dec1(.in(op_25_22 ), .out(op_25_22_d ));
    decoder_2_4  u_dec2(.in(op_21_20 ), .out(op_21_20_d ));
    decoder_5_32 u_dec3(.in(op_19_15 ), .out(op_19_15_d ));

    assign inst_add_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h00];
    assign inst_sub_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h02];
    assign inst_slt    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h04];
    assign inst_sltu   = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h05];
    assign inst_nor    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h08];
    assign inst_and    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h09];
    assign inst_or     = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0a];
    assign inst_xor    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0b];
    assign inst_slli_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h01];
    assign inst_srli_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h09];
    assign inst_srai_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h11];
    assign inst_addi_w = op_31_26_d[6'h00] & op_25_22_d[4'ha];
    assign inst_ld_w   = op_31_26_d[6'h0a] & op_25_22_d[4'h2];
    assign inst_st_w   = op_31_26_d[6'h0a] & op_25_22_d[4'h6];
    assign inst_jirl   = op_31_26_d[6'h13];
    assign inst_b      = op_31_26_d[6'h14];
    assign inst_bl     = op_31_26_d[6'h15];
    assign inst_beq    = op_31_26_d[6'h16];
    assign inst_bne    = op_31_26_d[6'h17];
    assign inst_lu12i_w= op_31_26_d[6'h05] & ~id_inst[25];

    assign id_alu_op[ 0] = inst_add_w | inst_addi_w | inst_ld_w | inst_st_w
                        | inst_jirl | inst_bl;
    assign id_alu_op[ 1] = inst_sub_w;
    assign id_alu_op[ 2] = inst_slt;
    assign id_alu_op[ 3] = inst_sltu;
    assign id_alu_op[ 4] = inst_and;
    assign id_alu_op[ 5] = inst_nor;
    assign id_alu_op[ 6] = inst_or;
    assign id_alu_op[ 7] = inst_xor;
    assign id_alu_op[ 8] = inst_slli_w;
    assign id_alu_op[ 9] = inst_srli_w;
    assign id_alu_op[10] = inst_srai_w;
    assign id_alu_op[11] = inst_lu12i_w;

    assign need_ui5   =  inst_slli_w | inst_srli_w | inst_srai_w;
    assign need_si12  =  inst_addi_w | inst_ld_w | inst_st_w;
    assign need_si16  =  inst_jirl | inst_beq | inst_bne;
    assign need_si20  =  inst_lu12i_w;
    assign need_si26  =  inst_b | inst_bl;
    assign src2_is_4  =  inst_jirl | inst_bl;

    assign imm = src2_is_4 ? 32'h4                      :
                need_si20 ? {i20[19:0], 12'b0}         :
    /*need_ui5 || need_si12*/{{20{i12[11]}}, i12[11:0]} ;

    assign br_offs = need_si26 ? {{ 4{i26[25]}}, i26[25:0], 2'b0} :
                                {{14{i16[15]}}, i16[15:0], 2'b0} ;

    assign jirl_offs = {{14{i16[15]}}, i16[15:0], 2'b0};

    assign src_reg_is_rd = inst_beq | inst_bne | inst_st_w;

    assign src1_is_pc    = inst_jirl | inst_bl;

    assign src2_is_imm   = inst_slli_w |
                        inst_srli_w |
                        inst_srai_w |
                        inst_addi_w |
                        inst_ld_w   |
                        inst_st_w   |
                        inst_lu12i_w|
                        inst_jirl   |
                        inst_bl     ;

    assign id_res_from_mem  = inst_ld_w;
    assign dst_is_r1     = inst_bl;
    assign id_gr_we         = ~inst_st_w & ~inst_beq & ~inst_bne & ~inst_b;
    assign id_mem_we        = inst_st_w;
    assign id_dest          = dst_is_r1 ? 5'd1 : rd;

    assign rf_raddr1 = rj;
    assign rf_raddr2 = src_reg_is_rd ? rd :rk;
    assign {
        rf_we, rf_waddr, rf_wdata
    } = wb_id_bus;
    regfile u_regfile(
        .clk    (clk      ),
        .raddr1 (rf_raddr1),
        .rdata1 (rf_rdata1),
        .raddr2 (rf_raddr2),
        .rdata2 (rf_rdata2),
        .we     (rf_we    ),
        .waddr  (rf_waddr ),
        .wdata  (rf_wdata )
        );

    assign rj_value  =  (exe_en_bypass & (exe_dest == rf_raddr1) & addr1_valid)? exe_wdata :
                        (mem_en_bypass & (mem_dest == rf_raddr1) & addr1_valid)? mem_wdata :
                        (rf_we         & (rf_waddr == rf_raddr1) & addr1_valid)? rf_wdata  : rf_rdata1;
    assign id_rkd_value =   (exe_en_bypass & (exe_dest == rf_raddr2) & addr2_valid)? exe_wdata :
                            (mem_en_bypass & (mem_dest == rf_raddr2) & addr2_valid)? mem_wdata :
                            (rf_we         & (rf_waddr == rf_raddr2) & addr2_valid)? rf_wdata  : rf_rdata2;

    assign rj_eq_rd = (rj_value == id_rkd_value);
    assign id_en_brch = (   inst_beq  &&  rj_eq_rd
                    || inst_bne  && !rj_eq_rd
                    || inst_jirl
                    || inst_bl
                    || inst_b
    ) & id_valid;
    assign en_brch_cancel = id_en_brch & id_ready_go;
    assign id_brch_addr = (inst_beq || inst_bne || inst_bl || inst_b) ? (id_pc + br_offs) :
                                                    /*inst_jirl*/ (rj_value + jirl_offs);
    assign id_if_bus = {
        en_brch_cancel, id_brch_addr
    };
    assign id_alu_src1 = src1_is_pc  ? id_pc : rj_value;
    assign id_alu_src2 = src2_is_imm ? imm : id_rkd_value;
    assign id_exe_bus = {
        id_gr_we, id_mem_we, id_res_from_mem, 
        id_alu_op, id_alu_src1, id_alu_src2,
        id_dest, id_rkd_value, id_inst, id_pc
    };
    
    
endmodule