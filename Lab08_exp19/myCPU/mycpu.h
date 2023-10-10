`ifndef MYCPU_H
    //buses
    `define PF_IF_BUS_WDTH 47
    `define IF_ID_BUS_WDTH 79 //70
    `define ID_IF_BUS_WDTH 34
    `define ID_EXE_BUS_WDTH 360 //351   
    `define WB_ID_BUS_WDTH 38
    `define EXE_MEM_BUS_WDTH 210 //196
    `define MEM_WB_BUS_WDTH 207 //198
    `define EXE_WR_BUS_WDTH 39
    `define MEM_WR_BUS_WDTH 39
    `define EXE_CSR_BLK_BUS_WDTH 17
    `define MEM_CSR_BLK_BUS_WDTH 17
    `define WB_CSR_BLK_BUS_WDTH 17//16
    //csr
    // exp12 csrs
    `define CSR_CRMD    14'h000
    `define CSR_PRMD    14'h001
    `define CSR_ESTAT   14'h005
    `define CSR_ERA     14'h006
    `define CSR_EENTRY  14'h00c
    `define CSR_SAVE0   14'h030
    `define CSR_SAVE1   14'h031
    `define CSR_SAVE2   14'h032
    `define CSR_SAVE3   14'h033
    // exp13 csrs
    `define CSR_ECFG    14'h004
    `define CSR_BADV    14'h007
    `define CSR_TID     14'h040
    `define CSR_TCFG    14'h041
    `define CSR_TVAL    14'h042
    `define CSR_TICLR   14'h044
    `define CSR_DMW0    14'h180
    `define CSR_DMW1    14'h181
    // CSR write masks
    `define CSR_MASK_CRMD   32'h0000_0007   // only plv, ie
    `define CSR_MASK_PRMD   32'h0000_0007
    `define CSR_MASK_ESTAT  32'h0000_0003   // only SIS RW
    `define CSR_MASK_ERA    32'hffff_ffff
    `define CSR_MASK_EENTRY 32'hffff_ffc0
    `define CSR_MASK_SAVE   32'hffff_ffff

    `define CSR_CRMD_PLV    1:0
    `define CSR_PRMD_PPLV   1:0
    `define CSR_CRMD_PIE    2
    `define CSR_PRMD_PIE    2
    `define CSR_ECFG_LIE    12:0
    `define CSR_ESTAT_IS10  1:0
    `define CSR_ERA_PC      31:0
    `define CSR_EENTRY_VA   31:6
    `define CSR_SAVE_DATA   31:0

    //CSR for exp19

    `define CSR_CRMD_IE     2
    `define CSR_CRMD_DA     3
    `define CSR_CRMD_PG     4
    `define CSR_CRMD_DATF   6:5
    `define CSR_CRMD_DATM   8:7

    //CSR for TLB
    `define CSR_TLBIDX          14'h010
    `define CSR_TLBEHI          14'h011
    `define CSR_TLBELO0         14'h012
    `define CSR_TLBELO1         14'h013
    `define CSR_ASID            14'h018
    `define CSR_TLBRENTRY       14'h088

    //exc types
    `define NUM_TYPES   15
    `define TYPE_SYS    0
    `define TYPE_ADEF   1
    `define TYPE_ALE    2
    `define TYPE_BRK    3
    `define TYPE_INE    4
    `define TYPE_INT    5
    `define TYPE_ADEM    6
    `define TYPE_TLBRF  7
    `define TYPE_PIL     8
    `define TYPE_PIS     9
    `define TYPE_PIF     10
    `define TYPE_PME     11
    `define TYPE_PLVF   12
    `define TYPE_TLBRM  13
    `define TYPE_PLVM   14
    //ecodes
    `define EXC_ECODE_SYS   6'h0B
    `define EXC_ECODE_INT   6'h00
    `define EXC_ECODE_ADE   6'h08
    `define EXC_ECODE_ALE   6'h09
    `define EXC_ECODE_BRK   6'h0C
    `define EXC_ECODE_INE   6'h0D
    `define EXC_ECODE_TLBR  6'h3F
    `define EXC_ECODE_PIL   6'h01
    `define EXC_ECODE_PIS   6'h02
    `define EXC_ECODE_PIF   6'h03
    `define EXC_ECODE_PME   6'h04
    `define EXC_ECODE_PLV   6'h07

    //esubcodes
    `define EXC_ESUBCODE_ADEF   9'h000
    `define EXC_ESUBCODE_ADEM   9'h001
    `define CSR_ECFG_LIE    12:0
    `define CSR_BADV_VAddr  31:0
    `define CSR_TID_TID     31:0
    `define CSR_TCFG_EN      0
    `define CSR_TCFG_PERIOD  1
    `define CSR_TCFG_INITVAL 31:2
    `define CSR_TICLR_CLR   0
    `define CSR_MASK_ECFG   32'h0000_1fff
    `define CSR_MASK_TID    32'hffff_ffff
    `define CSR_MASK_TCFG   32'hffff_ffff
    `define CSR_MASK_TICLR  32'h0000_0001
    `define CSR_MASK_BADV   32'hffff_ffff
    `define CSR_MASK_DMW 32'hee00_0039  

    `define CSR_MASK_TLBIDX     32'hbf00_000f//new added for exp18
    `define CSR_MASK_TLBEHI     32'hffff_e000
    `define CSR_MASK_TLBELO     32'hffff_ff7f
    `define CSR_MASK_ASID       32'h0000_03ff
    `define CSR_MASK_TLBRENTRY  32'hffff_ffc0

    //TLB
    // TLBIDX
    `define CSR_TLBIDX_INDEX    3:0
    `define CSR_TLBIDX_PS       29:24
    `define CSR_TLBIDX_NE       31
    // TLBEHI
    `define CSR_TLBEHI_VPPN     31:13
    // TLBELO0 TLBELO1
    `define CSR_TLBELO_V        0
    `define CSR_TLBELO_D        1
    `define CSR_TLBELO_PLV      3:2
    `define CSR_TLBELO_MAT      5:4
    `define CSR_TLBELO_G        6
    `define CSR_TLBELO_PPN      31:8
    // ASID
    `define CSR_ASID_ASID       9:0
    // TLBRENTRY
    `define CSR_TLBRENTRY_PA    31:6
    //DMW0DMW1
    `define CSR_DMW_PLV0    0
    `define CSR_DMW_PLV3    3
    `define CSR_DMW_MAT     5:4
    `define CSR_DMW_PSEG    27:25
    `define CSR_DMW_VSEG    31:29
`endif