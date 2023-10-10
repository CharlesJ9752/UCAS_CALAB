`define WAIT 5'b00001
`define LOOK 5'b00010
`define MISS 5'b00100
`define RPLC 5'b01000
`define RFLL 5'b10000
`define WR_WT 2'b01
`define WR_WR 2'b10
module cache(
    input              clk,
    input              resetn,
    input              valid,
	input              op,
	output             addr_ok,
	output             data_ok,
	output    [ 31:0]  rdata,
	input     [  7:0]  index, 
	input     [ 19:0]  tag, 
	input     [  3:0]  offset,
	input     [  3:0]  wstrb,
	input     [ 31:0]  wdata,
    output             rd_req,
	input              rd_rdy,
	input              ret_valid,
	output    [  2:0]  rd_type,
	output    [ 31:0]  rd_addr,
	input     [  1:0]  ret_last,
	input     [ 31:0]  ret_data,
    output             wr_req,  
	input              wr_rdy,
	output    [  2:0]  wr_type,
	output    [ 31:0]  wr_addr,
	output    [  3:0]  wr_wstrb,
	output    [127:0]  wr_data  
);
    //信号定义
    reg               op_r;
	reg      [  7:0]  index_r; 
	reg      [ 19:0]  tag_r; 
	reg      [  3:0]  offset_r; 
    //状态机
    reg     [4:0]   state;
    reg     [4:0]   next_state;
    always @(posedge clk ) begin
        if(~resetn)begin
            state<=`WAIT;
        end
        else begin
            state<=next_state;
        end
    end
    always @(*) begin
        case (state)
            `WAIT:
                if(~write_hit_blk&valid)
                    next_state<=`LOOK;
                else
                    next_state<=`WAIT; 
            `LOOK:
                if(cache_hit&(write_hit_blk|~valid))
                    next_state<=`WAIT;
				else if(cache_hit&valid)
					next_state<=`LOOK;
				else if(~dirty[rplc_way][index_r]|~valid_array[rplc_way][index_r])
					next_state<=`RPLC;
                else 
                    next_state<=`MISS;
            `MISS:
                if(~wr_rdy)begin
                    next_state<=`MISS;
                end
                else begin
                    next_state<=`RPLC;
                end
            `RPLC:
                if(rd_rdy)begin
                    next_state<=`RFLL;
                end
                else 
                    next_state<=`RPLC;
            `RFLL:
                if(ret_valid&ret_last)
                    next_state<=`WAIT;
                else
                    next_state<=`RFLL;
            default: next_state<=`WAIT;
        endcase
    end
    assign r_offset = offset_r[3:2];
    //写状态机
    wire    write_hit_blk;
    wire    write_hit;
    reg     [1:0]   wr_state;
    reg     [1:0]   wr_next_state;
    assign  write_hit=cache_hit&&state[1]&&op_r;
    assign  write_hit_blk=(write_hit&&valid&&~op&&index==index_r&&offset==offset_r)||(wr_state[1]&&valid&&offset[3:2]==offset_r[3:2]&&~op);
    always @(posedge clk ) begin
        if(~resetn)
            wr_state<=`WR_WT;
        else
            wr_state<=wr_next_state;
    end
    always @(*) begin
        case (wr_state)
            `WR_WT:
                if(write_hit)
                    wr_next_state<=`WR_WR;
                else
                    wr_next_state<=`WR_WT;
            `WR_WR:
                if(write_hit)
                    wr_next_state<=`WR_WR;
                else
                    wr_next_state<=`WR_WT;
            default: wr_next_state<=`WR_WT;
        endcase
    end
	wire 		wrbuff_way;
	reg			wrbuff_way_r;
	wire [7:0]	wrbuff_index;
	reg  [7:0]	wrbuff_index_r;
	always @(posedge clk ) begin
		if(~resetn)begin
			wrbuff_way_r<=1'b0;
			wrbuff_index_r<=8'b0;
		end
		else if(write_hit)begin
			wrbuff_way_r<=way1_hit;
			wrbuff_index_r<=index_r;
		end
	end
	assign wrbuff_way=wrbuff_way_r;
	assign wrbuff_index=wrbuff_index_r;
    //axi
	//rd
	reg      [  3:0]  wstrb_r;
    wire      [  1:0]  r_offset;
	reg      [ 31:0]  wdata_r;
    assign rd_req = state[3];
	assign rd_addr = {tag_r,index_r,4'b00};
	assign rd_type = 3'b100;  
	reg [1:0] rd_cnt;
	always @(posedge clk) begin
		if(~resetn)
			rd_cnt <= 2'b0;
		else if(ret_valid)
			rd_cnt <= rd_cnt + 2'b1;
	end
	reg [31:0] rdata_r;
	//wr
	reg wr_req_r;
	always@(posedge clk) begin
		if(~resetn)
			wr_req_r <= 1'b0;
		else if(~wr_rdy&state[2]&next_state[3])
			wr_req_r <= 1'b1;
		else if(wr_rdy)
			wr_req_r <= 1'b0;
	end
	assign wr_addr = {
		rplc_addr,index_r,4'b0
	};
	assign wr_wstrb = 4'b1111;
	assign wr_data = rplc_data;	
	assign wr_req = wr_req_r;
	assign wr_type = 3'b100;
	reg                busy;
	wire               rplc_way;
	wire      [127:0]  rplc_data;  
	reg       [127:0]  rplc_data_r;
	wire      [ 19:0]  rplc_addr;
	always@(posedge clk) begin
		if(~resetn) begin
			rdata_r <= 0;
		end
		else if(state[1]&cache_hit)
			rdata_r <= ld_res;
		else if(r_offset==rd_cnt&ret_valid)
			rdata_r <= ret_data;
	end
	assign rdata = rdata_r;
    //处理器信号
    reg data_ok_vld;
    always @(posedge clk ) begin
        if(~resetn)begin
            data_ok_vld<=1'b0;
        end
        else if(valid)begin
            data_ok_vld<=1'b1;
        end
        else if(data_ok)begin
            data_ok_vld<=1'b0;
        end
    end
    assign data_ok = state[0]&data_ok_vld;
	assign addr_ok = state[1]|state[0]&~valid;
    //tagv
	wire 	   tag0_we;
	wire [20:0]tag0_rdata;
	wire  	   tag1_we;
	wire [20:0]tag1_rdata;
	wire         way0_hit;
	wire         way1_hit;
	wire         cache_hit;
	wire [7:0]	way_tagv_addr;
	wire [20:0]	way_tagv_wdata;
	assign way_tagv_addr 	= busy?index_r:valid?index:8'b0;
	assign way_tagv_wdata	= {tag_r,1'b1};
	assign tag0_we 	= state[4]&~rplc_way;
	assign tag1_we 	= state[4]&rplc_way;
	tagv_ram way0_tagv(
		.clka(clk), 
		.wea(tag0_we),     
		.addra(way_tagv_addr), 
		.dina(way_tagv_wdata), 
		.douta(tag0_rdata) 
	);
	tagv_ram way1_tagv(
		.clka(clk),  
		.wea(tag1_we),   
		.addra(way_tagv_addr),  
		.dina(way_tagv_wdata),
		.douta(tag1_rdata) 
	);
	//lfsr_rdm
    reg     [7:0]  lfsr_rdm;
    always @(posedge clk ) begin
        if(~resetn)
            lfsr_rdm<=8'b1;
        else if(ret_valid&&ret_last)
            lfsr_rdm<={lfsr_rdm[6:0],lfsr_rdm[7] ^~ lfsr_rdm[5] ^~ lfsr_rdm[4] ^~ lfsr_rdm[3]};
    end
    assign  rplc_way = lfsr_rdm[0];
    always@(posedge clk)begin
        if(~resetn|busy&data_ok) begin
            op_r<=1'b0;
			index_r<=8'b0;
			tag_r<=20'b0;
			offset_r<=4'b0;
			wstrb_r<=4'b0;
			wdata_r<=32'b0;
        end
        if(state[0]&valid) begin
            op_r<=op;
			index_r<=index;
			tag_r<=tag;
			offset_r<=offset;
			wstrb_r<=wstrb;
			wdata_r<=wdata;
        end
    end
	always@(posedge clk)begin
        if(~resetn|busy&data_ok) begin
            busy <= 1'b0;
        end
        if(state[0]&valid) begin
            busy <= 1'b1;
        end
    end
	//dirty
	reg [255:0] dirty [1:0];
	always @(posedge clk ) begin
		if(~resetn)begin
			dirty[0]<=256'b0;dirty[1]<=256'b0;
		end
		else if(wr_state[1])begin
			dirty[wrbuff_way][wrbuff_index]<=1'b1;
		end
		else if(ret_last&ret_valid)begin
			dirty[rplc_way][index_r]<=op_r;
		end
	end
	//valid
	reg [255:0] valid_array [1:0];
	always @(posedge clk ) begin
		if(~resetn)begin
			valid_array[0]<=256'b0;valid_array[1]<=256'b0;
		end
		else if(ret_last&ret_valid)begin
			valid_array[rplc_way][index_r]<=1'b1;
		end
	end
	wire [19:0]  way0_tag;
	wire [19:0]  way1_tag;
	assign way0_tag = tag0_rdata[20:1];
	assign way1_tag = tag1_rdata[20:1];
	assign way0_hit = tag0_rdata[0]&&(way0_tag==tag_r);
	assign way1_hit = tag1_rdata[0]&&(way1_tag==tag_r);
    //way
	wire [31:0]   way0_ld_w;
	wire [31:0]   way1_ld_w;
	wire [31:0]   ld_res;
	assign way0_ld_w = ({32{offset_r==4'b0000}}&rdata_00)|({32{offset_r==4'b0100}}&rdata_01)|
				       ({32{offset_r==4'b1000}}&rdata_02)|({32{offset_r==4'b1100}}&rdata_03);
	assign way1_ld_w = ({32{offset_r==4'b0000}}&rdata_10)|({32{offset_r==4'b0100}}&rdata_11)|
					   ({32{offset_r==4'b1000}}&rdata_12)|({32{offset_r==4'b1100}}&rdata_13);
	assign ld_res 	  = {32{way0_hit}} & way0_ld_w|{32{way1_hit}} & way1_ld_w;
	assign rplc_data   = rplc_way? {rdata_13,rdata_12,rdata_11,rdata_10}:{rdata_03,rdata_02,rdata_01,rdata_00};

	wire [31:0] cache_write_data;
	assign cache_write_data[31:24]= wstrb_r[3]?wdata_r[31:24]:ret_data[31:24];
	assign cache_write_data[23:16]= wstrb_r[2]?wdata_r[23:16]: ret_data[23:16];
	assign cache_write_data[15:8]= wstrb_r[1]?wdata_r[15:8]: ret_data[15:8];
	assign cache_write_data[7:0]= wstrb_r[0]?wdata_r[7:0]: ret_data[7:0];
	assign cache_hit = way0_hit|way1_hit;
	assign rplc_addr = rplc_way? way1_tag : way0_tag;
	
    wire [3:0] en_00;
	wire [7:0] addr_00;
	wire [31:0] wdata_00;
	wire [31:0] rdata_00;
	assign en_00 	=(state[1] & way0_hit &r_offset == 2'b00 & op_r)?wstrb_r:(state[4]&rd_cnt==2'b0&ret_valid&~rplc_way)?4'b1111:4'b0;
	assign addr_00 	=(state[0])?index:index_r;
	assign wdata_00 =(state[1] & cache_hit & r_offset == 2'b00)?wdata_r:(state[4])&(r_offset==2'b0)?cache_write_data:4'b0;
	data_bank_ram bank00(
		.clka(clk), 
		.wea(en_00),
		.addra(addr_00),
		.dina(wdata_00),
		.douta(rdata_00)
	);
	
	wire [3:0] en_01;
	wire [7:0] addr_01;
	wire [31:0] wdata_01;
	wire [31:0] rdata_01;
	assign en_01 	= (state[1] & way0_hit &r_offset == 2'b01 & op_r)?wstrb_r:(state[4] & rd_cnt == 2'b01 & ret_valid &~rplc_way)?4'b1111:4'b0;
	assign addr_01 	=(state[0])?index:index_r;
	assign wdata_01 =(state[1] & cache_hit & r_offset == 2'b01)?wdata_r:(state[4])& (r_offset == 2'b01)? cache_write_data:4'b0;
	data_bank_ram bank01(
		.clka(clk), 
		.wea(en_01),
		.addra(addr_01),
		.dina(wdata_01),
		.douta(rdata_01)
	);

	wire [3:0] en_02;
	wire [7:0] addr_02;
	wire [31:0] wdata_02;
	wire [31:0] rdata_02;
	assign en_02 	=  	(state[1] & way0_hit &r_offset == 2'b10 & op_r)?wstrb_r:(state[4]&rd_cnt==2'b10&ret_valid&~rplc_way)?4'b1111:4'b0;
	assign addr_02 	= 	(state[0])?index:index_r;
	assign wdata_02 = 	(state[1] & cache_hit & r_offset == 2'b10)?wdata_r:(state[4])&(r_offset == 2'b10)? cache_write_data:4'b0;				

	data_bank_ram bank02(
		.clka(clk), 
		.wea(en_02),
		.addra(addr_02),
		.dina(wdata_02),
		.douta(rdata_02)
	);
	wire [3:0] en_03;
	wire [7:0] addr_03;
	wire [31:0] wdata_03;
	wire [31:0] rdata_03;
	assign en_03 	=   (state[1]&way0_hit&r_offset==2'b11 & op_r)?wstrb_r:(state[4] & rd_cnt==2'b11 & ret_valid &~rplc_way)?4'b1111:4'b0;								
	assign addr_03 	= 	(state[0])?index:index_r;
	assign wdata_03 = 	(state[1]&cache_hit&r_offset==2'b11)?wdata_r:(state[4])& (r_offset==2'b11)? cache_write_data:4'b0;
	data_bank_ram bank03(
		.clka(clk), 
		.wea(en_03),
		.addra(addr_03),
		.dina(wdata_03),
		.douta(rdata_03)
	);
	wire [3:0] en_10;
	wire [7:0] addr_10;
	wire [31:0] wdata_10;
	wire [31:0] rdata_10;

	assign en_10 	=  	(state[1] & way1_hit &r_offset==2'b00 & op_r)?wstrb_r:(state[4] & rd_cnt==2'b00&ret_valid & rplc_way)?4'b1111:4'b0;
	assign addr_10 	= 	(state[0])?index:index_r;
	assign wdata_10 = 	(state[1] & cache_hit & r_offset==2'b00)?wdata_r:(state[4])& (r_offset==2'b00)?cache_write_data:4'b0;

	data_bank_ram bank10(
		.clka(clk), 
		.wea(en_10),
		.addra(addr_10),
		.dina(wdata_10),
		.douta(rdata_10)
	);
	wire [3:0] en_11;
	wire [7:0] addr_11;
	wire [31:0] wdata_11;
	wire [31:0] rdata_11;
	assign en_11 	=  	(state[1] & way1_hit &r_offset==2'b01&op_r)?wstrb_r:(state[4]&rd_cnt==2'b01&ret_valid&rplc_way)?4'b1111:4'b0;
	assign addr_11 	= 	(state[0])?index:index_r;
	assign wdata_11 = 	(state[1] & cache_hit & r_offset==2'b01)?wdata_r:(state[4])& (r_offset==2'b01)? cache_write_data:4'b0;


	data_bank_ram bank11(
		.clka(clk), 
		.wea(en_11),
		.addra(addr_11),
		.dina(wdata_11),
		.douta(rdata_11)
	);

	wire [3:0] en_12;
	wire [7:0] addr_12;
	wire [31:0] wdata_12;
	wire [31:0] rdata_12;
	assign en_12 	=  	(state[1] & way1_hit &r_offset == 2'b10&op_r)?wstrb_r:(state[4]&rd_cnt==2'b10&ret_valid&rplc_way)?4'b1111:4'b0;							
	assign addr_12	= 	(state[0])?index:index_r;
	assign wdata_12 = 	(state[1]&cache_hit & r_offset == 2'b10)?wdata_r:(state[4])& (r_offset==2'b10)?cache_write_data:4'b0;

	data_bank_ram bank12(
		.clka(clk), 
		.wea(en_12),
		.addra(addr_12),
		.dina(wdata_12),
		.douta(rdata_12)
	);

	wire [3:0] en_13;
	wire [7:0] addr_13;
	wire [31:0] wdata_13;
	wire [31:0] rdata_13;
	assign en_13	=  	(state[1]&way1_hit&r_offset==2'b11&op_r)?wstrb_r:(state[4]&rd_cnt==2'b11&ret_valid&rplc_way)?4'b1111:4'b0;	
	assign addr_13 	= 	(state[0])?index:index_r;
	assign wdata_13 = 	(state[1]&cache_hit&r_offset==2'b11)?wdata_r:(state[4])&(r_offset==2'b11)?cache_write_data:4'b0;

	data_bank_ram bank13(
		.clka(clk), 
		.wea(en_13),
		.addra(addr_13),
		.dina(wdata_13),
		.douta(rdata_13)
	);
endmodule