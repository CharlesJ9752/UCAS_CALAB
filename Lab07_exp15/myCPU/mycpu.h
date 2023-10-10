`ifndef MYCPU_H
    //buses
    `define IF_ID_BUS_WDTH 70
    `define ID_IF_BUS_WDTH 34
    `define ID_EXE_BUS_WDTH 308   //lzc: add 2 bits for [ds_rdcn_en] and [ds_rdcn_sel]
    `define WB_ID_BUS_WDTH 38
    `define EXE_MEM_BUS_WDTH 191
    `define MEM_WB_BUS_WDTH 188
    `define EXE_WR_BUS_WDTH 39
    `define MEM_WR_BUS_WDTH 39
    `define EXE_CSR_BLK_BUS_WDTH 16
    `define MEM_CSR_BLK_BUS_WDTH 16
    `define WB_CSR_BLK_BUS_WDTH 16
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
    // CSR write masks
    `define CSR_MASK_CRMD   32'h0000_0007   // only plv, ie
    `define CSR_MASK_PRMD   32'h0000_0007
    `define CSR_MASK_ESTAT  32'h0000_0003   // only SIS RW
    `define CSR_MASK_ERA    32'hffff_ffff
    `define CSR_MASK_EENTRY 32'hffff_ffc0
    `define CSR_MASK_SAVE   32'hffff_ffff

    `define CSR_CRMD_PLV 1:0
    `define CSR_PRMD_PPLV 1:0
    `define CSR_CRMD_PIE 2
    `define CSR_PRMD_PIE 2
    `define CSR_ECFG_LIE 12:0
    `define CSR_ESTAT_IS10 1:0
    `define CSR_ERA_PC  31:0
    `define CSR_EENTRY_VA 31:6
    `define CSR_SAVE_DATA 31:0

    //exc types
    `define NUM_TYPES   6
    `define TYPE_SYS    0
    `define TYPE_ADEF   1
    `define TYPE_ALE    2
    `define TYPE_BRK    3
    `define TYPE_INE    4
    `define TYPE_INT    5
    //ecodes
    `define EXC_ECODE_SYS   6'h0B
    `define EXC_ECODE_INT   6'h00
    `define EXC_ECODE_ADE   6'h08
    `define EXC_ECODE_ALE   6'h09
    `define EXC_ECODE_BRK   6'h0C
    `define EXC_ECODE_INE   6'h0D
    //esubcodes
    `define EXC_ESUBCODE_ADEF   9'h000
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
`endif