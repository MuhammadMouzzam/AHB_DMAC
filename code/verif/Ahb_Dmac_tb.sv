// Copyright 2025 Maktab-e-Digital Systems Lahore.
// Licensed under the Apache License, Version 2.0, see LICENSE file for details.
// SPDX-License-Identifier: Apache-2.0
//
// Description: A testbench to enable the DMAC with a request and according to that, the
//              respective channel is enabled. At the end checks if the data in the
//              destination is the same as the data transfered from the source.
//
// Authors: Muhammad Mouzzam and Danish Hassan 
// Date: July 23rd, 2025

`timescale 1ns/1ps

module Ahb_Dmac_tb;

    logic clk, rst;
    logic [31:0] MRData;
    logic write, HSel;
    logic [31:0] HWData, HAddr;
    logic HReadyOut;
    logic [1:0] HResp;
    logic [1:0] DmacReq;
    logic Bus_Grant;

    logic [31:0] MAddress, MWData;
    logic [3:0]  MBurst_Size;
    logic MWrite;
    logic [1:0] MTrans;
    logic [3:0] MWStrb;
    logic Bus_Req, Interrupt;
    logic [1:0] ReqAck;

    logic [9:0] temp_src_addr, temp_dst_addr, temp_trans_size;
    logic [1:0]  temp_hsize;
    logic [3:0]  temp_Strb;

    // Clock
    always #5 clk = ~clk;

    //Ahb-signals
    logic bus_rst;
    logic Hmaster;    
    logic HReady;

    // Instantiate DUT
    Dmac_Top dut (
        .clk(clk), .rst(rst),
        .MRData(MRData), .HReady(HReady), .M_HResp(HResp),
        .DmacReq(DmacReq), .Bus_Grant(Bus_Grant),
        .MAddress(MAddress), .MWData(MWData), .MBurst_Size(MBurst_Size),
        .MWrite(MWrite), .MTrans(MTrans), .Bus_Req(Bus_Req),
        .Interrupt(Interrupt), .ReqAck(ReqAck), .MWStrb(MWStrb)
    );

    ahb_arbiter arbiter (
        .Hclk(clk),
        .Hresetn(bus_rst),
        .Hreq(Bus_Req),       // Master requests
        .Hready(HReady),     // Global Hready
        .Htrans(MTrans),     // Transaction type
        .Hburst(MBurst_Size),     // Burst type

        .Hgrant(Bus_Grant),     // Grant signal to masters
        .Hmaster(Hmaster)     // Index of active master
    );

    //Decoder signals
    logic [1:0] Hsel_From_Decoder;

    decoder decoder(
        .Haddr(MAddress),
        .Hsel(Hsel_From_Decoder)
    );

    // mts outputs (For Writing)
    logic [31:0] Haddr;
    logic [1:0] Htrans;
    logic Hwrite;
    logic [2:0] Hsize;
    logic [2:0] Hburst;
    logic [3:0] Hstrob;
    logic [31:0] Hwdata;
    

    master_to_slave_mux mts (
    .Hmaster(Hmaster),
    .Haddr_M({MAddress}),  
    .Htrans_M({MTrans}), 
    .Hwrite_M({MWrite}), 
    .Hsize_M({Hsize}),  
    .Hburst_M({MBurst_Size}), 
    .Hstrob_M({MWStrb}),
    .Hwdata_M({MWData}),  
    .Haddr(Haddr),
    .Htrans(Htrans),
    .Hwrite(Hwrite),
    .Hsize(Hsize),
    .Hburst(Hburst),
    .Hstrob(Hstrob),
    .Hwdata(Hwdata)
    );

    //stm signals (For Reading)
    logic [31:0] Hrdata_S [2];
    logic [1:0] Hresp_S [2];
    logic Hreadyout_S [2];

    slave_to_master_mux stm (
    .Hclk(clk),
    .Hresetn(bus_rst),
    .Hsel(Hsel_From_Decoder),        
    .Hmaster({Hmaster}),        
    .Hrdata_S(Hrdata_S),    
    .Hresp_S(Hresp_S),  
    .Hreadyout_S(Hreadyout_S), 
    
    .Hrdata({MRData}), 
    .Hresp({HResp}) ,
    .Hready(HReady)         
    );

    mock_ahb_peripheral #(.MEM_DEPTH(256)) source (
        .HCLK(clk),
        .HRESET(rst),
        .HSEL(Hsel_From_Decoder[0]),
        .HADDR(Haddr),
        .HTRANS(Htrans),
        .HWRITE(Hwrite),
        .HREADYIN(HReady),
        .HWDATA(Hwdata),
        .HRDATA(Hrdata_S[0]),  // Output to DMA
        .HREADYOUT(Hreadyout_S[0]),
        .HRESP(Hresp_S[0]),
        .HSIZE(Hsize),
        .WSTRB(Hstrob)
    );

    // Mock destination peripheral (write to memory)
    mock_ahb_peripheral #(.MEM_DEPTH(256)) dest (
        .HCLK(clk),
        .HRESET(rst),
        .HSEL(Hsel_From_Decoder[1]),
        .HADDR(Haddr),
        .HTRANS(Htrans),
        .HWRITE(Hwrite),
        .HREADYIN(HReady),
        .HWDATA(Hwdata),  // Input from DMA
        .HRDATA(Hrdata_S[1]),        // Not used
        .HREADYOUT(Hreadyout_S[1]),
        .HRESP(Hresp_S[1]),
        .HSIZE(Hsize),
        .WSTRB(Hstrob)
    );


    int passed = 0;
    int failed = 0;

    // Select which peripheral is active based on request
    always @(DmacReq) begin
        if (DmacReq[1]) begin
            temp_src_addr   = {dest.mem[32'h0000_00A1][1:0], dest.mem[32'h0000_00A0]};
            temp_dst_addr   = {dest.mem[32'h0000_00A5][1:0], dest.mem[32'h0000_00A4]};
            temp_trans_size = {24'b0, dest.mem[32'h0000_00A8]};
            temp_hsize      = dest.mem[32'h0000_00AC][7:4];
        end
        else begin
            temp_src_addr   = {source.mem[32'h0000_00A1][1:0], source.mem[32'h0000_00A0]};
            temp_dst_addr   = {source.mem[32'h0000_00A5][1:0], source.mem[32'h0000_00A4]};
            temp_trans_size = {24'b0, source.mem[32'h0000_00A8]};
            temp_hsize      = source.mem[32'h0000_00AC][7:4];
        end
    end

    int check = 0;

    initial begin
        // Initial state
        clk = 0;
        rst = 1;
        write = 0;
        HSel = 0;
        HWData = 0;
        HAddr = 0;
        DmacReq = 0;
        bus_rst = 1;
        for (int i = 0; i < 100; i++) begin
            source.mem[i] = i+i;
        end

        for (int i = 100; i < 200; i++) begin
            dest.mem[i - 100] = i+i;
        end


        source.mem[32'h0000_00A3] = 8'h00;
        source.mem[32'h0000_00A2] = 8'h00;
        source.mem[32'h0000_00A1] = 8'h00;
        source.mem[32'h0000_00A0] = 8'h04;

        source.mem[32'h0000_00A7] = 8'h10;
        source.mem[32'h0000_00A6] = 8'h00;
        source.mem[32'h0000_00A5] = 8'h00;
        source.mem[32'h0000_00A4] = 8'h00;

        source.mem[32'h0000_00AB] = 8'h00;
        source.mem[32'h0000_00AA] = 8'h00;
        source.mem[32'h0000_00A9] = 8'h00;
        source.mem[32'h0000_00A8] = 8'd22;

        source.mem[32'h0000_00AF] = 8'h00;
        source.mem[32'h0000_00AE] = 8'h01;
        source.mem[32'h0000_00AD] = 8'h00;
        source.mem[32'h0000_00AC] = 8'h24;

        dest.mem[32'h0000_00A3] = 8'h10;
        dest.mem[32'h0000_00A2] = 8'h00;
        dest.mem[32'h0000_00A1] = 8'h00;
        dest.mem[32'h0000_00A0] = 8'h04;

        dest.mem[32'h0000_00A7] = 8'h00;
        dest.mem[32'h0000_00A6] = 8'h00;
        dest.mem[32'h0000_00A5] = 8'h00;
        dest.mem[32'h0000_00A4] = 8'h00;

        dest.mem[32'h0000_00AB] = 8'h00;
        dest.mem[32'h0000_00AA] = 8'h00;
        dest.mem[32'h0000_00A9] = 8'h00;
        dest.mem[32'h0000_00A8] = 8'd22;

        dest.mem[32'h0000_00AF] = 8'h00;
        dest.mem[32'h0000_00AE] = 8'h01;
        dest.mem[32'h0000_00AD] = 8'h00;
        dest.mem[32'h0000_00AC] = 8'h24;
        

        // Wait a few cycles
        repeat (5) @(posedge clk);
        rst = 0;
        bus_rst = 0;

        // temp_src_addr = {source.mem[32'h0000_00A1][1:0], source.mem[32'h0000_00A0]};
        // temp_dst_addr = {source.mem[32'h0000_00A5][1:0], source.mem[32'h0000_00A4]};
        // temp_trans_size = {24'b0, source.mem[32'h0000_00A8]};
        // temp_hsize = source.mem[32'h0000_00AC][7:4];


        // Request from Peripheral 
        @(posedge clk);
        DmacReq = 2'b10;

        case (temp_hsize)
            2'b00: begin  // Byte
                case (temp_src_addr[1:0])
                    2'b00: temp_Strb = 4'b0001;
                    2'b01: temp_Strb = 4'b0010;
                    2'b10: temp_Strb = 4'b0100;
                    2'b11: temp_Strb = 4'b1000;
                    default: temp_Strb = 4'b0000;
                endcase
            end
            2'b01: begin  // Halfword
                case (temp_src_addr[1:0])
                    2'b00: temp_Strb = 4'b0011;  
                    2'b10: temp_Strb = 4'b1100;
                    default: temp_Strb = 4'b0000; 
                endcase
            end
            2'b10: temp_Strb = 4'b1111;  // Word — all bytes active
            default: temp_Strb = 4'b0000;
        endcase


        // Wait until transfer is done
        while (!check) begin
            wait (Interrupt == 1)
            @(negedge clk)
            if (Interrupt == 1)
                check = 1;
        end


        repeat(2) @(posedge clk)
        $display("Time = %0t ps, Interrupt asserted!", $time);
        // Verify destination memory
        $display("\033[1;36mDMA transfer completed. Checking destination memory...\033[0m");
        monitor(temp_trans_size, temp_src_addr, temp_dst_addr);
        $stop;
    end

task monitor(input logic [31:0] transfer_size, input logic [9:0] src_addr, dst_addr);
    for(int i = src_addr[9:2] << 2, j = dst_addr, k = 0; k < transfer_size; i=i+4, j=j+4, k++) begin
        $display("\033[1;36m---------Word No. %-2d---------\033[0m", k+1);
        for (int a = i, b = j, c = 0; (a < i+4) && (b < j+4) && (c < 4); a++, b++, c++) begin
            if (temp_Strb[c])
                check_byte(a, b, dut.DmacReq_Reg[1]? dest.mem[32'h0000_00A3][4] ? 1:0 : source.mem[32'h0000_00A3][4] ? 1:0);
            else
                $display("\033[1;35mInvalid Byte\033[0m");
        end
    end
    $display("\033[1;35mTest Cases:\033[0m\n    \033[1;32mPassed = %d\033[0m, \033[1;31mFailed = %d\033[0m", passed, failed);
endtask

task check_byte(input int saddr, daddr, input bit dir);
    byte sdata, ddata;

    if (dir == 0) begin
        // Source -> Dest
        sdata = source.mem[saddr];
        ddata = dest.mem[daddr];
    end else begin
        // Dest -> Source
        sdata = dest.mem[saddr];
        ddata = source.mem[daddr];
    end

    if (sdata == ddata) begin
        $display("\033[1;32mPASS: {[%0s][%-2d] = %x} == {[%0s][%-2d] = %x}\033[0m",
                 (dir==1)?"Source":"Dest", (dir==1)?saddr:daddr, ddata,
                 (dir==1)?"Dest":"Source", (dir==1)?daddr:saddr, sdata);
        passed += 1;
    end else begin
        $display("\033[1;31mFAIL: {[%0s][%-2d] = %x} != {[%0s][%-2d] = %x}\033[0m",
                 (dir==1)?"Source":"Dest", (dir==1)?saddr:daddr, ddata,
                 (dir==1)?"Dest":"Source", (dir==1)?daddr:saddr, sdata);
        failed += 1;
    end
endtask


endmodule