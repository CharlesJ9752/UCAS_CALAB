module tlb #(
        parameter TLBNUM = 16
    )(
        input  wire                 clk,
        input  wire [              18:0] s0_vppn,
        input  wire                      s0_va_bit12,
        input  wire [               9:0] s0_asid,
        output wire                      s0_found,
        output wire [$clog2(TLBNUM)-1:0] s0_index,
        output wire [              19:0] s0_ppn,
        output wire [               5:0] s0_ps,
        output wire [               1:0] s0_plv,
        output wire [               1:0] s0_mat,
        output wire                      s0_d,
        output wire                      s0_v,

        input  wire [              18:0] s1_vppn,
        input  wire                      s1_va_bit12,
        input  wire [               9:0] s1_asid,
        output wire                      s1_found,
        output wire [$clog2(TLBNUM)-1:0] s1_index,
        output wire [              19:0] s1_ppn,
        output wire [               5:0] s1_ps,
        output wire [               1:0] s1_plv,
        output wire [               1:0] s1_mat,
        output wire                      s1_d,
        output wire                      s1_v,

        input  wire                      invtlb_valid,
        input  wire [               4:0] invtlb_op,

        input  wire                      we,
        input  wire [$clog2(TLBNUM)-1:0] w_index,
        input  wire                      w_e,
        input  wire [              18:0] w_vppn,
        input  wire [               5:0] w_ps,
        input  wire [               9:0] w_asid,
        input  wire                      w_g,

        input  wire [              19:0] w_ppn0,
        input  wire [               1:0] w_plv0,
        input  wire [               1:0] w_mat0,
        input  wire                      w_d0,
        input  wire                      w_v0,

        input  wire [              19:0] w_ppn1,
        input  wire [               1:0] w_plv1,
        input  wire [               1:0] w_mat1,
        input  wire                      w_d1,
        input  wire                      w_v1,

        input  wire [$clog2(TLBNUM)-1:0] r_index,
        output wire                      r_e,
        output wire [              18:0] r_vppn,
        output wire [               5:0] r_ps,
        output wire [               9:0] r_asid,
        output wire                      r_g,

        output wire [              19:0] r_ppn0,
        output wire [               1:0] r_plv0,
        output wire [               1:0] r_mat0,
        output wire                      r_d0,
        output wire                      r_v0,

        output wire [              19:0] r_ppn1,
        output wire [               1:0] r_plv1,
        output wire [               1:0] r_mat1,
        output wire                      r_d1,
        output wire                      r_v1
    );
    reg  [TLBNUM-1:0] tlb_e                ;//存在位
    reg  [TLBNUM-1:0] tlb_ps4MB            ;//大小标志位 
    reg  [      18:0] tlb_vppn [TLBNUM-1:0];//虚双页号
    reg  [       9:0] tlb_asid [TLBNUM-1:0];//地址空间标志
    reg               tlb_g    [TLBNUM-1:0];//全局标志位，为1时不进行比对asid
    reg  [      19:0] tlb_ppn0 [TLBNUM-1:0];//物理页号
    reg  [       1:0] tlb_plv0 [TLBNUM-1:0];//特权级
    reg  [       1:0] tlb_mat0 [TLBNUM-1:0];//访存类型
    reg               tlb_d0   [TLBNUM-1:0];//脏位
    reg               tlb_v0   [TLBNUM-1:0];//有效位
    reg  [      19:0] tlb_ppn1 [TLBNUM-1:0];
    reg  [       1:0] tlb_plv1 [TLBNUM-1:0];
    reg  [       1:0] tlb_mat1 [TLBNUM-1:0];
    reg               tlb_d1   [TLBNUM-1:0];
    reg               tlb_v1   [TLBNUM-1:0];
    wire [TLBNUM-1:0] match0;
    wire [TLBNUM-1:0] match1;
    //match
    genvar i;
    generate 
        for (i = 0; i < TLBNUM; i = i + 1) begin
            assign match0[i] =  (s0_vppn[18:10]==tlb_vppn[i][18:10]) && tlb_e[i]
                            &&  (tlb_ps4MB[ i] || s0_vppn[9:0]==tlb_vppn[ i][9:0])
                            &&  ((s0_asid==tlb_asid[ i]) || tlb_g[ i]);
            assign match1[i] =  (s1_vppn[18:10]==tlb_vppn[i][18:10]) && tlb_e[i]
                            &&  (tlb_ps4MB[ i] || s1_vppn[9:0]==tlb_vppn[ i][9:0])
                            &&  ((s1_asid==tlb_asid[ i]) || tlb_g[ i]);
            //4MB: s_vppn[18:0]==tlb_vppn[18:0]; 4KB: s_vppn==tlb_vppn
            /*
                4KB:
                |31 ---- 12|11 ---- 0|
                |   vppn   |  offset |
                //vppn = vppn + va_bit12

                4MB:
                |31 ---- 22|21 ---- 0|
                |   vppn   |  offset |

                vppn[18:0] = va[31:13]
                va_bit12 = va[12]
            */
        end
    endgenerate
    //s0
    wire    s0_odd;
    wire    s0_even;
    assign s0_found = |match0;
    assign s0_index =   match0[ 0] ? 4'b0000: match0[ 1] ? 4'b0001: match0[ 2] ? 4'b0010: match0[ 3] ? 4'b0011:
                        match0[ 4] ? 4'b0100: match0[ 5] ? 4'b0101: match0[ 6] ? 4'b0110: match0[ 7] ? 4'b0111:
                        match0[ 8] ? 4'b1000: match0[ 9] ? 4'b1001: match0[10] ? 4'b1010: match0[11] ? 4'b1011:
                        match0[12] ? 4'b1100: match0[13] ? 4'b1101: match0[14] ? 4'b1110: match0[15] ? 4'b1111: 4'b0000;
    assign s0_odd         = tlb_ps4MB[s0_index] ? s0_vppn[9]/*4MB:va[22]*/ :s0_va_bit12/*4KB:va[12]*/;
    assign s0_even         = ~s0_odd;
    assign s0_ps        = tlb_ps4MB[s0_index] ? 6'd22 : 6'd12;
    assign s0_ppn       = {20{ s0_odd}}&tlb_ppn1[s0_index]|{20{ s0_even}}&tlb_ppn0[s0_index];
    assign s0_plv       = { 2{ s0_odd}}&tlb_plv1[s0_index]|{ 2{ s0_even}}&tlb_plv0[s0_index];
    assign s0_mat       = { 2{ s0_odd}}&tlb_mat1[s0_index]|{ 2{ s0_even}}&tlb_mat0[s0_index];
    assign s0_d         = { 1{ s0_odd}}&tlb_d1  [s0_index]|{ 1{ s0_even}}&tlb_d0  [s0_index];
    assign s0_v         = { 1{ s0_odd}}&tlb_v1  [s0_index]|{ 1{ s0_even}}&tlb_v0  [s0_index];
    //s1
    wire    s1_odd;
    wire    s1_even;
    assign s1_found = |match1;
    assign s1_index =   match1[ 0] ? 4'b0000: match1[ 1] ? 4'b0001: match1[ 2] ? 4'b0010: match1[ 3] ? 4'b0011:
                        match1[ 4] ? 4'b0100: match1[ 5] ? 4'b0101: match1[ 6] ? 4'b0110: match1[ 7] ? 4'b0111:
                        match1[ 8] ? 4'b1000: match1[ 9] ? 4'b1001: match1[10] ? 4'b1010: match1[11] ? 4'b1011:
                        match1[12] ? 4'b1100: match1[13] ? 4'b1101: match1[14] ? 4'b1110: match1[15] ? 4'b1111: 4'b0000;
    assign s1_odd         = tlb_ps4MB[s1_index] ? s1_vppn[9] : s1_va_bit12;
    assign s1_even         = ~s1_odd;
    assign s1_ps        = tlb_ps4MB[s1_index] ? 6'd22 : 6'd12;
    assign s1_ppn       = {20{ s1_odd}}&tlb_ppn1[s1_index]|{20{ s1_even}}&tlb_ppn0[s1_index];
    assign s1_plv       = { 2{ s1_odd}}&tlb_plv1[s1_index]|{ 2{ s1_even}}&tlb_plv0[s1_index];
    assign s1_mat       = { 2{ s1_odd}}&tlb_mat1[s1_index]|{ 2{ s1_even}}&tlb_mat0[s1_index];
    assign s1_d         = { 1{ s1_odd}}&tlb_d1  [s1_index]|{ 1{ s1_even}}&tlb_d0  [s1_index];
    assign s1_v         = { 1{ s1_odd}}&tlb_v1  [s1_index]|{ 1{ s1_even}}&tlb_v0  [s1_index];
    
    /************************/
    wire [TLBNUM-1:0] inv_match [3:0];
    wire [TLBNUM-1:0] inv_op_mask [31:0];
    /************************/

    always @ (posedge clk) begin
        if (we) begin
            tlb_e[w_index] <= w_e;
            tlb_ps4MB[w_index] <= w_ps==6'd22;
            tlb_vppn[w_index] <= w_vppn;
            tlb_asid[w_index] <= w_asid;
            tlb_g[w_index] <= w_g;
            tlb_ppn0[w_index] <= w_ppn0;
            tlb_plv0[w_index] <= w_plv0;
            tlb_mat0[w_index] <= w_mat0;
            tlb_d0[w_index] <= w_d0;
            tlb_v0[w_index] <= w_v0;
            tlb_ppn1[w_index] <= w_ppn1;
            tlb_plv1[w_index] <= w_plv1;
            tlb_mat1[w_index] <= w_mat1;
            tlb_d1[w_index] <= w_d1;
            tlb_v1[w_index] <= w_v1;
        end 
        else if(invtlb_valid) begin
            tlb_e <= ~inv_op_mask[invtlb_op] & tlb_e;   //new added
        end
    end

    /************************/
    //inv_match
    generate 
        for (i = 0; i < TLBNUM; i = i + 1) begin
            assign inv_match[0][i] = ~tlb_g[i];
            assign inv_match[1][i] =  tlb_g[i];
            assign inv_match[2][i] = s1_asid == tlb_asid[i];
            assign inv_match[3][i] = (s1_vppn[18:10] == tlb_vppn[i][18:10]) && (s1_vppn[9:0] == tlb_vppn[i][9:0]||tlb_ps4MB[i]);
        end        
    endgenerate
    /************************/



    /************************/
    //inv_op_mask
    //0-6
    assign inv_op_mask[0] = 16'hffff;//unsure
    assign inv_op_mask[1] = 16'hffff;
    assign inv_op_mask[2] = inv_match[1];
    assign inv_op_mask[3] = inv_match[0];
    assign inv_op_mask[4] = inv_match[0] & inv_match[2];
    assign inv_op_mask[5] = inv_match[0] & inv_match[2] & inv_match[3];
    assign inv_op_mask[6] = (inv_match[0] | inv_match[2]) & inv_match[3];
    //7-31
    generate for (i = 7; i < 32; i = i + 1) begin
        assign inv_op_mask[i] = 16'b0; 
    end
    endgenerate

    /************************/
    assign  r_e = tlb_e[r_index];
    assign  r_vppn = tlb_vppn[r_index];
    assign  r_ps = tlb_ps4MB[r_index]?6'd22:6'd12;
    assign  r_asid = tlb_asid[r_index];
    assign  r_g = tlb_g[r_index];
    assign  r_ppn0 = tlb_ppn0[r_index];
    assign  r_plv0 = tlb_plv0[r_index];
    assign  r_mat0 = tlb_mat0[r_index];
    assign  r_d0 = tlb_d0[r_index];
    assign  r_v0 = tlb_v0[r_index];
    assign  r_ppn1 = tlb_ppn1[r_index];
    assign  r_plv1 = tlb_plv1[r_index];
    assign  r_mat1 = tlb_mat1[r_index];
    assign  r_d1 = tlb_d1[r_index];
    assign  r_v1 = tlb_v1[r_index];
endmodule