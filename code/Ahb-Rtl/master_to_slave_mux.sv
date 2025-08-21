// Copyright 2025 Maktab-e-Digital Systems Lahore.
// Licensed under the Apache License, Version 2.0, see LICENSE file for details.
// SPDX-License-Identifier: Apache-2.0
//
// Description: 
// 
// This module is the master to slave multiplexer for AHB bus.
// That uses the slected master signal form the Arbiter module.
// To derive the DATA ADDRESS and CONTROL SIGNAL on the bus.
//
// Author: Muhammad Yousaf and Ali Tahir
// Date:   07-August-2025


`include "../defines/parameters.svh"
localparam MASTER_WIDTH = (`NUM_MASTERS > 1) ? $clog2(`NUM_MASTERS) : 1;

module master_to_slave_mux (

    input  logic [MASTER_WIDTH -1:0]        Hmaster,   // Selected master index
    input  logic [`DATA_WIDTH-1:0]                 Haddr_M  [`NUM_MASTERS],
    input  logic [1:0]                             Htrans_M [`NUM_MASTERS],
    input  logic                                   Hwrite_M [`NUM_MASTERS],
    input  logic [2:0]                             Hsize_M  [`NUM_MASTERS],
    input  logic [2:0]                             Hburst_M [`NUM_MASTERS],
    input  logic [`DATA_WIDTH/8-1:0]               Hstrob_M [`NUM_MASTERS],
    input  logic [`DATA_WIDTH-1:0]                 Hwdata_M [`NUM_MASTERS],
    output logic [`DATA_WIDTH-1:0]                 Haddr,
    output logic [1:0]                             Htrans,
    output logic                                   Hwrite,
    output logic [2:0]                             Hsize,
    output logic [2:0]                             Hburst,
    output logic [`DATA_WIDTH/8-1:0]               Hstrob,
    output logic [`DATA_WIDTH-1:0]                 Hwdata

);

    assign Haddr   = Haddr_M[Hmaster];
    assign Htrans  = Htrans_M[Hmaster];
    assign Hwrite  = Hwrite_M[Hmaster];
    assign Hsize   = Hsize_M[Hmaster];
    assign Hburst  = Hburst_M[Hmaster];
    assign Hstrob  = Hstrob_M[Hmaster];
    assign Hwdata  = Hwdata_M[Hmaster];

endmodule