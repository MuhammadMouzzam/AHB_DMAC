// Copyright 2025 Maktab-e-Digital Systems Lahore.
// Licensed under the Apache License, Version 2.0, see LICENSE file for details.
// SPDX-License-Identifier: Apache-2.0
//
// Description: 
// 
// This module is the slave to master multiplexer for AHB bus.
// That uses the slected slave signal form the Decoder module.
// To derive the DATA and RESPONSE SIGNAL on the bus.
//
// Author: Muhammad Yousaf and Ali Tahir
// Date:   11-August-2025

`include "../defines/parameters.svh"
localparam MASTER_WIDTH = (`NUM_MASTERS > 1) ? $clog2(`NUM_MASTERS) : 1;

module slave_to_master_mux (

    input  logic                                Hclk,
    input  logic                                Hresetn,
    input  logic [`NUM_SLAVES-1:0]              Hsel,         // One-hot signal from decoder
    input  logic [MASTER_WIDTH -1:0]            Hmaster,            // Selected master index
    input  logic [`DATA_WIDTH-1:0]              Hrdata_S [`NUM_SLAVES],         // From slaves
    input  logic [1:0]                          Hresp_S  [`NUM_SLAVES],
    input  logic                                Hreadyout_S [`NUM_SLAVES],
    
    output logic [`DATA_WIDTH-1:0]              Hrdata, // [`NUM_MASTERS],
    output logic [1:0]                          Hresp, // [`NUM_MASTERS],
    output logic                                Hready               // Global Hready for master
);

    // Register selected slave (for pipelined response)
    logic [`NUM_SLAVES-1:0] selected_slave;
    logic [`NUM_MASTERS-1:0] selected_master;
    logic over;

    always_ff @(posedge Hclk or posedge Hresetn) begin
        if (Hresetn) begin
            selected_slave <= 4'b0000;
        end 
        else if (Hready) begin // Only update on valid transfer complete
            selected_slave <= Hsel;
            selected_master <= Hmaster;
        end
    end

    always_comb begin
        // Default Assignments 
        for (int m = 0; m < `NUM_MASTERS; m++) begin
            Hrdata[m] = 32'hDEADBEEF;
            Hresp[m]  = 2'b00;
        end
        Hready = 1'b1;
        over = 1'b0;
        for (int i = 0; i < `NUM_SLAVES; i++) begin
            if (selected_slave[i] == 1'b1 && !over) begin
                Hrdata = Hrdata_S[i]; //[selected_master]
                Hresp  = Hresp_S[i]; //[selected_master]
                Hready = Hreadyout_S[i];
                over = 1'b1;
            end
        end
    end

endmodule