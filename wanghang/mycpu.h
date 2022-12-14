`ifndef MYCPU_H
    `define MYCPU_H
    `define BR_BUS_WD 34
    `define PFS_TO_FS_BUS_WD 32
    `define FS_TO_DS_BUS_WD 70
    `define DS_TO_ES_BUS_WD 284
    `define ES_TO_MS_BUS_WD 164
    `define MS_TO_WS_BUS_WD 156

    `define EXC_NUM 6
    `define EXC_FLG_SYS 0
    `define EXC_FLG_ADEF 1
    `define EXC_FLG_ALE 2
    `define EXC_FLG_BRK 3
    `define EXC_FLG_INE 4
    `define EXC_FLG_INT 5

    `define ES_CSR_BLK_BUS_WD 16
    `define MS_CSR_BLK_BUS_WD 16
    `define WS_CSR_BLK_BUS_WD 16

    `define ES_FWD_BLK_BUS_WD 39
    `define MS_FWD_BLK_BUS_WD 39
`endif
