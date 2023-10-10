`include "mycpu.h"
//���룬���ɲ�����
module ID (
    input                                   clk,
    input                                   resetn,
    //��IF�׶�
    input                                   if_id_valid,
    output                                  id_allowin,
    input   [`IF_ID_BUS_WDTH - 1:0]         if_id_bus,//exc_type + pc + inst
    output  [`ID_IF_BUS_WDTH - 1:0]         id_if_bus,//en_brch+br_target
    //��EXE�׶�
    input                                   exe_allowin,
    output                                  id_exe_valid,
    output  [`ID_EXE_BUS_WDTH - 1:0]        id_exe_bus,//add 2bits
    //����WB�׶�
    input   [`WB_ID_BUS_WDTH - 1:0]         wb_id_bus,
    //������ǰ���ź�
    input   [`EXE_WR_BUS_WDTH - 1:0]        exe_wr_bus,
    input   [`MEM_WR_BUS_WDTH - 1:0]        mem_wr_bus,
    //�쳣&�ж�
    input                                   wb_exc,
    input                                   csr_has_int,
    //��csr�Ĵ���
    input   [31:0]                          csr_rdata,
    output  [13:0]                          csr_raddr,
    input   [`EXE_CSR_BLK_BUS_WDTH - 1:0]   exe_csr_blk_bus,
    input   [`MEM_CSR_BLK_BUS_WDTH - 1:0]   mem_csr_blk_bus,
    input   [`WB_CSR_BLK_BUS_WDTH - 1:0]    wb_csr_blk_bus//ertn_flush in this
);
//�źŶ���
    //�����ź�
    reg                                     id_valid;
    wire                                    id_ready_go;
    wire                                    id_en_brch;
    //ָ���pc
    wire    [31:0]                          id_br_target;
    wire    [31:0]                          id_inst;
    wire    [31:0]                          id_pc;
    //bus
    reg     [`IF_ID_BUS_WDTH - 1:0]         if_id_bus_vld;
    //������ǰ��
    wire                                    exe_en_bypass;
    wire                                    exe_en_block;
    wire                                    exe_res_from_mem;
    wire                                    mem_en_bypass;
    wire                                    mem_en_block;
    wire    [31:0]                          exe_wdata;
    wire    [31:0]                          mem_wdata;
    wire    [ 4:0]                          exe_dest;
    wire    [ 4:0]                          mem_dest;
    wire    [ 4:0]                          wb_dest;
    wire                                    en_brch_cancel;
    //�쳣���ж�
    wire [`NUM_TYPES - 1:0]                 id_exc_type;
    //csr
    wire                                    id_csr_we;
    wire                                    id_csr_re;
    wire [13:0]                             id_csr_waddr;
    wire [13:0]                             id_csr_raddr;
    wire [31:0]                             id_csr_wdata;
    wire [31:0]                             id_csr_rdata;
    wire [31:0]                             id_csr_wmask;
    wire [31:0]                             pre_mask;
    wire                                    exe_csr_we;
    wire [13:0]                             exe_csr_waddr;

    wire                                    mem_csr_we;
    wire [13:0]                             mem_csr_waddr;

    wire                                    wb_csr_we;
    wire [13:0]                             wb_csr_waddr;

    wire                                    csr_blk;
            


//�����źŵĸ�ֵ
    assign id_ready_go = ~csr_blk & ~( exe_en_block & ((exe_dest==rf_raddr1) & addr1_valid //untest
                                    |(exe_dest==rf_raddr2) & addr2_valid)) 
                                    & ~( mem_en_block & ((mem_dest==rf_raddr1) & addr1_valid //untest
                                    |(mem_dest==rf_raddr2) & addr2_valid));//in case of load
    reg exc_reg;
    reg ertn_reg;
    always @(posedge clk) begin
        if (~resetn) begin
            exc_reg <= 1'b0;
            ertn_reg <= 1'b0;
        end 
        else if (wb_exc) begin
            exc_reg <= 1'b1;
        end 
        else if (ertn_flush) begin
            ertn_reg <= 1'b1;
        end 
        else if (if_id_valid & id_allowin)begin
            exc_reg <= 1'b0;
            ertn_reg <= 1'b0;
        end 
    end


    assign is_ertn_exc = (wb_exc | ertn_flush | exc_reg | ertn_reg);
    assign id_exe_valid = id_ready_go && id_valid &  ~is_ertn_exc;
    assign id_allowin = id_ready_go && exe_allowin || ~id_valid;
    always @(posedge clk ) begin
        if(~resetn) begin
            id_valid <= 1'b0;
        end
        else if(id_allowin) begin
            id_valid <= if_id_valid;
        end
    end
//��bus����
    always @(posedge clk ) begin
        if(~resetn)begin
            if_id_bus_vld <= `IF_ID_BUS_WDTH'b0;
        end
        else if(if_id_valid & id_allowin)begin
            if_id_bus_vld <= if_id_bus;
        end
    end
    wire    [5:0]   if_exc_type;
    assign {
        if_exc_type, id_pc, id_inst
    } = if_id_bus_vld;
    assign id_exe_bus = {
        id_rdcn, inst_rdcntvh_w, //lzc: new added
        id_csr_we, id_csr_re, id_csr_waddr, id_csr_wmask, id_csr_wdata, id_csr_rdata,   //112 bits
        inst_ertn, id_exc_type,                                                         //7 bits
        id_gr_we, id_mem_we, id_res_from_mem, 
        id_alu_op, id_alu_src1, id_alu_src2,
        id_dest, id_rkd_value, id_inst, id_pc
    };
//���룬���ɲ�����
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
    wire        inst_slti;
    wire        inst_sltui;
    wire        inst_andi;
    wire        inst_ori;
    wire        inst_xori;
    wire        inst_sll_w;
    wire        inst_srl_w;
    wire        inst_sra_w;
    wire        inst_slli_w;
    wire        inst_srli_w;
    wire        inst_srai_w;
    wire        inst_addi_w;
    wire        inst_pcaddu12i;
    wire        inst_ld_w;
    wire        inst_st_w;
    wire        inst_jirl;
    wire        inst_b;
    wire        inst_bl;
    wire        inst_beq;
    wire        inst_bne;
    wire        inst_lu12i_w;
    wire        inst_mul_w;
    wire        inst_mulh_w;
    wire        inst_mulh_wu;
    wire        inst_blt;
    wire        inst_bge;
    wire        inst_bltu;
    wire        inst_bgeu;
    wire        inst_ld_b;
    wire        inst_ld_h;
    wire        inst_ld_bu;
    wire        inst_ld_hu;
    wire        inst_st_b;
    wire        inst_st_h;    

    /************************/
    //�쳣&�ж�
    wire        inst_syscall;
    wire        inst_csrrd;
    wire        inst_csrwr;
    wire        inst_csrxchg;
    wire        inst_ertn;


    /**new added**/
    //break
    wire        inst_break;     
    //timer inst
    wire        inst_rdcntid_w; 
    wire        inst_rdcntvl_w; 
    wire        inst_rdcntvh_w; 
    wire        id_rdcn;      
    assign id_rdcn  = inst_rdcntvh_w | inst_rdcntvl_w;
    /**new added**/



    /************************/


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
    wire [18:0] id_alu_op;
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
    assign inst_slti   = op_31_26_d[6'h00] & op_25_22_d[4'h8];
    assign inst_sltui  = op_31_26_d[6'h00] & op_25_22_d[4'h9];
    assign inst_andi   = op_31_26_d[6'h00] & op_25_22_d[4'hd];
    assign inst_ori    = op_31_26_d[6'h00] & op_25_22_d[4'he];
    assign inst_xori   = op_31_26_d[6'h00] & op_25_22_d[4'hf];
    assign inst_sll_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0e];
    assign inst_srl_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0f];
    assign inst_sra_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h10];
    assign inst_pcaddu12i = op_31_26_d[6'h07] & ~id_inst[25];
    assign inst_mul_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h18];
    assign inst_mulh_w = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h19];
    assign inst_mulh_wu= op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h1a];
    assign inst_div_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h00];
    assign inst_mod_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h01];
    assign inst_div_wu = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h02];
    assign inst_mod_wu = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h03];
    assign inst_blt    = op_31_26_d[6'h18];
    assign inst_bge    = op_31_26_d[6'h19];
    assign inst_bltu   = op_31_26_d[6'h1a];
    assign inst_bgeu   = op_31_26_d[6'h1b];
    assign inst_ld_b   = op_31_26_d[6'h0a] & op_25_22_d[4'h0];
    assign inst_ld_h   = op_31_26_d[6'h0a] & op_25_22_d[4'h1];
    assign inst_ld_bu  = op_31_26_d[6'h0a] & op_25_22_d[4'h8];
    assign inst_ld_hu  = op_31_26_d[6'h0a] & op_25_22_d[4'h9];
    assign inst_st_b   = op_31_26_d[6'h0a] & op_25_22_d[4'h4];
    assign inst_st_h   = op_31_26_d[6'h0a] & op_25_22_d[4'h5];

    /************************/
    //�쳣&�ж�
    assign inst_syscall= op_31_26_d[6'b000000] & op_25_22_d[4'b0000] & op_21_20_d[2'b10] & op_19_15_d[5'b10110];
    assign inst_csrrd  = (id_inst[31:24]==8'b00000100) & (rj==5'b00000);
    assign inst_csrwr  = (id_inst[31:24]==8'b00000100) & (rj==5'b00001);
    assign inst_csrxchg= (id_inst[31:24]==8'b00000100) & (rj[4:1]!=4'b0);
    assign inst_ertn   = id_inst[31:10]==22'b00000_11001_00100_00011_10;
    
    assign inst_break     = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'b10] & op_19_15_d[5'h14];
    assign inst_rdcntid_w = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'b00] & op_19_15_d[5'h00] & rk == 5'h18 & rd == 5'h00;
    assign inst_rdcntvl_w = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'b00] & op_19_15_d[5'h00] & rk == 5'h18 & rj == 5'h00;
    assign inst_rdcntvh_w = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'b00] & op_19_15_d[5'h00] & rk == 5'h19 & rj == 5'h00;
    
    /************************/
    assign is_b = inst_beq | inst_bne | inst_blt | inst_bge | inst_bltu | inst_bgeu | inst_bl | inst_jirl | inst_b;

    assign id_alu_op[ 0] = inst_add_w | inst_addi_w | inst_ld_w | inst_st_w
                        | inst_jirl | inst_bl | inst_pcaddu12i | inst_ld_b | inst_ld_bu | inst_ld_h | inst_ld_hu | inst_st_b | inst_st_h;
    assign id_alu_op[ 1] = inst_sub_w;
    assign id_alu_op[ 2] = inst_slt | inst_slti;
    assign id_alu_op[ 3] = inst_sltu | inst_sltui;
    assign id_alu_op[ 4] = inst_and | inst_andi;
    assign id_alu_op[ 5] = inst_nor;
    assign id_alu_op[ 6] = inst_or | inst_ori;
    assign id_alu_op[ 7] = inst_xor | inst_xori;
    assign id_alu_op[ 8] = inst_slli_w | inst_sll_w;
    assign id_alu_op[ 9] = inst_srli_w | inst_srl_w;
    assign id_alu_op[10] = inst_srai_w | inst_sra_w;
    assign id_alu_op[11] = inst_lu12i_w;
    assign id_alu_op[12] = inst_mul_w;
    assign id_alu_op[13] = inst_mulh_w;
    assign id_alu_op[14] = inst_mulh_wu;
    assign id_alu_op[15] = inst_div_w;
    assign id_alu_op[16] = inst_div_wu;
    assign id_alu_op[17] = inst_mod_w;
    assign id_alu_op[18] = inst_mod_wu;

    assign need_ui5   =  inst_slli_w | inst_srli_w | inst_srai_w;
    assign need_si12  =  inst_addi_w | inst_ld_w | inst_ld_b | inst_ld_bu | inst_ld_h | inst_st_w | inst_ld_hu | inst_st_h | inst_st_b;//add st,ld
    assign need_si16  =  inst_jirl | inst_beq | inst_bne;
    assign need_si20  =  inst_lu12i_w | inst_pcaddu12i;
    assign need_si26  =  inst_b | inst_bl;
    assign need_zero_xtnd = inst_ori | inst_andi | inst_xori;
    assign src2_is_4  =  inst_jirl | inst_bl;

    assign imm = src2_is_4 ? 32'h4                      :
                need_si20 ? {i20[19:0], 12'b0}          :
                need_zero_xtnd ? {20'b0, i12[11:0]}     :
                                {{20{i12[11]}}, i12[11:0]} ;

    assign br_offs = need_si26 ? {{ 4{i26[25]}}, i26[25:0], 2'b0} :
                                {{14{i16[15]}}, i16[15:0], 2'b0} ;

    assign jirl_offs = {{14{i16[15]}}, i16[15:0], 2'b0};

    assign src_reg_is_rd =  inst_beq | inst_bne | inst_st_w  | inst_st_b  | inst_st_h |
                            inst_blt  | inst_bge | inst_bltu | inst_bgeu |                            //change 1
                            inst_csrwr | inst_csrxchg; //add
    assign src1_is_pc    = inst_jirl | inst_bl | inst_pcaddu12i;

    assign src2_is_imm   =  inst_slli_w |
                            inst_srli_w |
                            inst_srai_w |
                            inst_addi_w |
                            inst_ld_w   |
                            inst_st_w   |
                            inst_lu12i_w|
                            inst_jirl   |
                            inst_bl     |
                            inst_slti   |
                            inst_sltui  |
                            inst_andi   |
                            inst_ori    |
                            inst_xori   |
                            inst_pcaddu12i |
                            inst_ld_b |
                            inst_ld_bu |
                            inst_ld_h |
                            inst_ld_hu |
                            inst_st_b |
                            inst_st_h;                                                               //change 2

    assign id_res_from_mem  = inst_ld_w | inst_ld_b | inst_ld_bu | inst_ld_h | inst_ld_hu;       //change 3
    assign dst_is_r1        = inst_bl;
    assign id_gr_we         = ~inst_st_w & ~inst_beq & ~inst_bne & ~inst_b &
                              ~inst_st_b & ~inst_st_h & ~inst_blt & ~inst_bge & ~inst_bltu & ~inst_bgeu & //change 4
                              ~inst_syscall & ~inst_ertn & 
                              ~inst_break & ~id_exc_type[`TYPE_INE]; //add
    assign id_mem_we        = inst_st_w | inst_st_b | inst_st_h;                                 //change 5
    assign id_dest          = dst_is_r1 ? 5'd1 :  inst_rdcntid_w ? rj : rd;

    assign rf_raddr1 = rj;
    assign rf_raddr2 = src_reg_is_rd ? rd :rk;
    assign rj_eq_rd = (rj_value == id_rkd_value);
    assign rj_less_rd =($signed(rj_value) < $signed(id_rkd_value));   //��Ҫ����signed                                      //change 6
    assign rj_lessu_rd =($unsigned(rj_value) < $unsigned(id_rkd_value));                    //change 7
    assign id_en_brch = (   inst_beq  &&  rj_eq_rd
                    || inst_bne  && !rj_eq_rd
                    || inst_blt && rj_less_rd
                    || inst_bltu && rj_lessu_rd
                    || inst_bge && !rj_less_rd
                    || inst_bgeu && !rj_lessu_rd                                         //change 8
                    || inst_jirl
                    || inst_bl
                    || inst_b
    ) & id_valid & id_ready_go;//jyh1031
    assign br_taken = id_en_brch;//jyh1031
    assign br_stall = !id_ready_go && is_b;
    assign id_br_target = (inst_beq || inst_bne || inst_bl || inst_b || inst_blt || inst_bge || inst_bltu || inst_bgeu) 
    ? (id_pc + br_offs) :    /*inst_jirl*/ (rj_value + jirl_offs);                     // change 9
    assign id_if_bus = {
        br_taken,br_stall, id_br_target
    };
    assign id_alu_src1 = src1_is_pc  ? id_pc : rj_value;
    assign id_alu_src2 = src2_is_imm ? imm : id_rkd_value;
//����������ǰ�ݣ�regfile�Ĵ�����csr�Ĵ�����
    //regfile
    assign  {
        exe_en_bypass, exe_en_block, exe_dest, exe_wdata
    } = exe_wr_bus;
    assign  {
        mem_en_bypass, mem_en_block,mem_dest, mem_wdata
    } = mem_wr_bus;
    assign addr1_valid = ~id_exc_type[`TYPE_INE] & 
                    ~(inst_b | inst_bl | inst_csrrd | inst_csrwr | inst_syscall | inst_ertn | inst_break |
                    inst_rdcntid_w | inst_rdcntvh_w | inst_rdcntvl_w);
    
    assign addr2_valid =    inst_add_w | inst_sub_w | inst_slt | inst_sltu | inst_and | 
                            inst_or | inst_nor | inst_xor |
                            inst_sll_w | inst_srl_w | inst_sra_w | inst_mul_w | inst_mulh_w | inst_mulh_wu |
                            inst_div_w | inst_mod_w | inst_div_wu | inst_mod_wu |
                            inst_beq | inst_bne | inst_blt | inst_bge | inst_bltu | inst_bgeu | inst_st_w | inst_st_b | inst_st_h |
                            inst_csrwr | inst_csrxchg;
    assign rj_value  =  (exe_en_bypass & (exe_dest == rf_raddr1) & addr1_valid & |rf_raddr1)? exe_wdata :
                        (mem_en_bypass & (mem_dest == rf_raddr1) & addr1_valid & |rf_raddr1)? mem_wdata :
                        (rf_we         & (rf_waddr == rf_raddr1) & addr1_valid & |rf_raddr1)? rf_wdata  : rf_rdata1;
    assign id_rkd_value =   (exe_en_bypass & (exe_dest == rf_raddr2) & addr2_valid & |rf_raddr2)? exe_wdata :
                            (mem_en_bypass & (mem_dest == rf_raddr2) & addr2_valid & |rf_raddr2)? mem_wdata :
                            (rf_we         & (rf_waddr == rf_raddr2) & addr2_valid & |rf_raddr2)? rf_wdata  : rf_rdata2;

    //csr�Ĵ���
    assign {exe_csr_we, exe_ertn, exe_csr_waddr} = exe_csr_blk_bus;
    assign {mem_csr_we, mem_ertn, mem_csr_waddr} = mem_csr_blk_bus;
    assign {wb_csr_we, ertn_flush, wb_csr_waddr}    = wb_csr_blk_bus;

    assign csr_blk = id_csr_re & (//�����ź�
                        exe_csr_we&csr_raddr==exe_csr_waddr&(|exe_csr_waddr)|
                        mem_csr_we&csr_raddr==mem_csr_waddr&(|mem_csr_waddr)|
                        wb_csr_we&csr_raddr==wb_csr_waddr&(|wb_csr_waddr)|
                        (ertn_flush)&(exe_csr_waddr==`CSR_ERA|exe_csr_waddr==`CSR_PRMD|csr_raddr==`CSR_CRMD)|
                        (ertn_flush)&(mem_csr_waddr==`CSR_ERA|mem_csr_waddr==`CSR_PRMD|csr_raddr==`CSR_CRMD)|
                        (ertn_flush)&(wb_csr_waddr==`CSR_ERA|wb_csr_waddr==`CSR_PRMD|csr_raddr==`CSR_CRMD)//jyh
                    );

//��дregfile�Ĵ���
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
//��дcsr�Ĵ���
    assign id_csr_we    = inst_csrwr | inst_csrxchg;
    assign id_csr_re    = inst_csrrd | inst_csrwr | inst_csrxchg | inst_rdcntid_w;
    assign id_csr_waddr = id_inst[23:10];
    assign id_csr_raddr = inst_rdcntid_w ? `CSR_TID : id_inst[23:10];
    assign id_csr_wdata = id_rkd_value;
    assign id_csr_rdata = csr_rdata;
    assign id_csr_wmask = inst_csrxchg ? rj_value : pre_mask;
    assign csr_raddr    = id_csr_raddr;
    assign pre_mask =       {32{id_csr_waddr == `CSR_CRMD  }} & `CSR_MASK_CRMD   |
                            {32{id_csr_waddr == `CSR_PRMD  }} & `CSR_MASK_PRMD   |
                            {32{id_csr_waddr == `CSR_ESTAT }} & `CSR_MASK_ESTAT  |
                            {32{id_csr_waddr == `CSR_ERA   }} & `CSR_MASK_ERA    |
                            {32{id_csr_waddr == `CSR_EENTRY}} & `CSR_MASK_EENTRY |
                            {32{id_csr_waddr == `CSR_SAVE0 ||
                                id_csr_waddr == `CSR_SAVE1 ||
                                id_csr_waddr == `CSR_SAVE2 ||
                                id_csr_waddr == `CSR_SAVE3 }} & `CSR_MASK_SAVE   |
                            {32{id_csr_waddr == `CSR_ECFG  }} & `CSR_MASK_ECFG   |
                            {32{id_csr_waddr == `CSR_BADV  }} & `CSR_MASK_BADV   |
                            {32{id_csr_waddr == `CSR_TID   }} & `CSR_MASK_TID    |
                            {32{id_csr_waddr == `CSR_TCFG  }} & `CSR_MASK_TCFG   |
                            {32{id_csr_waddr == `CSR_TICLR }} & `CSR_MASK_TICLR;


//�жϺ��쳣��־
    /**new added**/
    assign  id_exc_type[`TYPE_SYS]=inst_syscall;
    assign  id_exc_type[`TYPE_ADEF]=if_exc_type[`TYPE_ADEF];
    assign  id_exc_type[`TYPE_ALE]=1'b0;
    assign  id_exc_type[`TYPE_BRK]=inst_break;
    assign  id_exc_type[`TYPE_INE]=~(id_exc_type[`TYPE_ADEF]) & ~(inst_add_w | inst_sub_w | inst_slt | inst_sltu | 
    inst_nor | inst_and | inst_or | inst_xor | inst_slti | inst_sltui | inst_andi | inst_ori | inst_xori | inst_sll_w |
    inst_srl_w | inst_sra_w | inst_slli_w | inst_srli_w | inst_srai_w | inst_addi_w | inst_pcaddu12i | inst_ld_w |
    inst_st_w | inst_jirl | inst_b | inst_bl | inst_beq | inst_bne | inst_lu12i_w | inst_mul_w | inst_mulh_w|
    inst_mulh_wu | inst_blt | inst_bge | inst_bltu | inst_bgeu | inst_ld_b | inst_ld_h | inst_ld_bu | inst_ld_hu |
    inst_st_b | inst_st_h | inst_syscall | inst_csrrd | inst_csrwr | inst_csrxchg | inst_ertn | inst_break |
    inst_rdcntid_w | inst_rdcntvl_w | inst_rdcntvh_w | inst_mod_w | inst_mod_wu | inst_div_w | inst_div_wu);
    assign  id_exc_type[`TYPE_INT]=csr_has_int;
    /**new added**/
//add

endmodule