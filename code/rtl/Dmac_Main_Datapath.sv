// Copyright 2025 Maktab-e-Digital Systems Lahore.
// Licensed under the Apache License, Version 2.0, see LICENSE file for details.
// SPDX-License-Identifier: Apache-2.0
//
// Description: Main Datapath of the DMAC, Contains 2 Channels and handles only 1 request
//              at a time, which the lower priority or late request has to wait untill the
//              one being attended to isn't complete. Contains the Slave and Master
//              Interface as well.
//
// Authors: Muhammad Mouzzam and Danish Hassan 
// Date: July 23rd, 2025

module Dmac_Main_Datapath(
    input logic clk,
    input logic rst,
    input logic config_write,
    input logic channel_en_1,
    input logic channel_en_2,
    input logic [31:0] MRData,
    input logic HReady,
    input logic [1:0] M_HResp,
    input logic [1:0] DmacReq, addr_inc_sel, config_HTrans, 
    input logic con_en,
    input logic [1:0] con_sel,
    input logic DmacReq_Reg_en, SAddr_Reg_en, DAddr_Reg_en, Trans_sz_Reg_en, Ctrl_Reg_en,
    input logic PeriAddr_reg_en,

    output logic C_config,
    output logic irq,
    output logic [1:0] con_new_sel,
    output logic [31:0] MAddress,
    output logic [31:0] MWData,
    output logic [3:0] MBurst_Size,
    output logic MWrite,
    output logic [3:0] MWStrb,
    output logic [1:0] MTrans,
    output logic [1:0] DmacReq_Reg
);

logic [31:0] Size_Reg, SAddr_Reg, DAddr_Reg, Ctrl_Reg, PeriAddr_Reg;
logic [31:0] decoded_Peri_addr, config_SAddr;
logic [3:0] config_strbs;
logic [1:0] config_HSize, config_BurstSize;

assign config_HSize = 2'b10;
assign config_BurstSize = 2'b01;
assign config_strbs = 4'b1111;
assign C_config = Ctrl_Reg[16];

always_comb begin
    case(DmacReq)
        2'b01: decoded_Peri_addr = 32'h0000_0000;
        2'b10: decoded_Peri_addr = 32'h1000_0000;
        2'b11: decoded_Peri_addr = 32'h1000_0000;
        default: 
            decoded_Peri_addr = 32'h0000_0000;
    endcase
end

always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
        Size_Reg <= 32'b0;
        SAddr_Reg <= 32'b0;
        DAddr_Reg <= 32'b0;
        Ctrl_Reg <= 32'b0;
    end
    else if (irq)
        Ctrl_Reg <= 32'b0;
    else if (SAddr_Reg_en)
        SAddr_Reg <= MRData;
    else if (DAddr_Reg_en)
        DAddr_Reg <= MRData;
    else if (Trans_sz_Reg_en)
        Size_Reg <= MRData;
    else if (Ctrl_Reg_en)
        Ctrl_Reg <= MRData;
end

always_ff @(posedge clk) begin
    if (rst)
        PeriAddr_Reg = 32'b0;
    else if (PeriAddr_reg_en)
        PeriAddr_Reg <= decoded_Peri_addr;
end

always_ff @(posedge clk or posedge rst) begin
    if(rst)
        DmacReq_Reg = 32'b0;
    else if (DmacReq_Reg_en)
        DmacReq_Reg <= DmacReq;
end

always_comb begin
    case(addr_inc_sel)
        2'b00:  config_SAddr = PeriAddr_Reg + 32'h0000_00A0;
        2'b01:  config_SAddr = PeriAddr_Reg + 32'h0000_00A4;
        2'b10:  config_SAddr = PeriAddr_Reg + 32'h0000_00A8;
        2'b11:  config_SAddr = PeriAddr_Reg + 32'h0000_00AC;
    endcase
end

// Channel 1 signals

logic irq_1;
logic write_1;
logic [1:0]  MTrans_1;
logic [31:0] MAddress_1;
logic [31:0] MWData_1;
logic [3:0] MWStrb_1;

Dmac_Channel channel_1 (
    .clk(clk),
    .rst(rst),
    .channel_en(channel_en_1),
    .readyIn(HReady),
    .M_HResp(M_HResp),
    .S_Address(SAddr_Reg),
    .D_Address(DAddr_Reg),
    .T_Size(Size_Reg),
    .B_Size({{28{1'b0}}, {Ctrl_Reg[3:0]}}),
    .R_Data(MRData),
    .HSize(Ctrl_Reg[5:4]),

    .irq(irq_1),
    .write(write_1),
    .HTrans(MTrans_1),
    .MAddress(MAddress_1),
    .MWData(MWData_1),
    .MWStrb(MWStrb_1)
);

// Channel 2 signals

logic irq_2;
logic write_2;
logic [1:0]  MTrans_2;
logic [31:0] MAddress_2;
logic [31:0] MWData_2;
logic [3:0] MWStrb_2;

Dmac_Channel channel_2 (
    .clk(clk),
    .rst(rst),
    .channel_en(channel_en_2),
    .readyIn(HReady),
    .M_HResp(M_HResp),
    .S_Address(SAddr_Reg),
    .D_Address(DAddr_Reg),
    .T_Size(Size_Reg),
    .B_Size({{28{1'b0}}, {Ctrl_Reg[3:0]}}) ,
    .R_Data(MRData),
    .HSize(Ctrl_Reg[5:4]),

    .irq(irq_2),
    .write(write_2),
    .HTrans(MTrans_2),
    .MAddress(MAddress_2),
    .MWData(MWData_2),
    .MWStrb(MWStrb_2)
);

always_comb begin
    if(con_sel == 2'b00) begin
        MAddress = MAddress_1;
        MWData = MWData_1;
        MTrans = MTrans_1;
        MBurst_Size = Ctrl_Reg[3:0];
        MWrite = write_1;
        MWStrb = MWStrb_1;
    end else if (con_sel == 2'b01) begin
        MAddress = MAddress_2;
        MWData = MWData_2;
        MTrans = MTrans_2;
        MBurst_Size = Ctrl_Reg[3:0];
        MWrite = write_2;
        MWStrb = MWStrb_2;
    end else if (con_sel == 2'b10) begin
        MAddress = config_SAddr;
        MWData = 32'h0000_0000;
        MTrans = config_HTrans;
        MBurst_Size = 2'b00;
        MWrite = config_write;
        MWStrb = 4'b1111;
    end
end

assign irq = irq_1 || irq_2; 

always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
        con_new_sel <= 0;
        // irq <= 0;
    end
    else if (con_en) begin
        con_new_sel <= con_sel;
    end
    // irq <= irq_1 || irq_2;

end



    
endmodule