// Copyright 2025 Maktab-e-Digital Systems Lahore.
// Licensed under the Apache License, Version 2.0, see LICENSE file for details.
// SPDX-License-Identifier: Apache-2.0
//
// Description: 
// This module Arbiter for AHB bus.
// That uses the Round ROibin Priority Algorithm.
// To Grant Bus Access to a Master.
// It can handle multiple masters.
//
// Author: Muhammad Yousaf and Ali Tahir
// Date:   07-August-2025

`include "../defines/parameters.svh"

localparam MASTER_WIDTH = (`NUM_MASTERS > 1) ? $clog2(`NUM_MASTERS) : 1;

module ahb_arbiter (

    input  logic                                            Hclk,
    input  logic                                            Hresetn,
    input  logic [`NUM_MASTERS-1:0]                         Hreq,       // Master requests
    input  logic                                            Hready,     // Global Hready
    input  logic [1:0]                                      Htrans,     // Transaction type
    input  logic [2:0]                                      Hburst,     // Burst type

    output logic [`NUM_MASTERS-1:0]                         Hgrant,     // Grant signal to masters
    output logic [MASTER_WIDTH -1:0]                        Hmaster     // Index of active master

);

    localparam IDLE   = 2'b00;
    localparam NONSEQ = 2'b10;
    localparam SEQ    = 2'b11;

    // === Internal State ===
    logic [MASTER_WIDTH -1:0] current_master;
    logic [MASTER_WIDTH -1:0] next_master;
    logic [MASTER_WIDTH -1:0] granted_master;

    logic [4:0] burst_counter;
    logic       in_burst;
    logic       is_incr;
    logic       valid_transfer;

    logic ready_for_handover;
    logic [$clog2(`NUM_MASTERS)-1:0] idx;

    // Burst length decoding
    logic [4:0] burst_len;
    always_comb begin
        case (Hburst)
            3'b000: burst_len = 5'd1;    // SINGLE
            3'b010, 3'b011: burst_len = 5'd4;    // WRAP4 / INCR4
            3'b100, 3'b101: burst_len = 5'd8;    // WRAP8 / INCR8
            3'b110, 3'b111: burst_len = 5'd16;   // WRAP16 / INCR16
            default: burst_len = 5'd0;           // INCR or undefined
        endcase
    end

    // Round-robin master selection
    always_comb begin
        next_master = current_master;
        for (int i = 1; i < `NUM_MASTERS; i++) begin
            idx = (current_master + i < `NUM_MASTERS) ? (current_master + i) : (current_master + i - `NUM_MASTERS);
            if (Hreq[idx]) begin
                next_master = idx[$clog2(`NUM_MASTERS)-1:0];
                break;
            end
        end
    end

    always_comb begin
        ready_for_handover = (!in_burst) || 
                             (!is_incr && burst_counter == 0 && Hready) ||
                             (is_incr && !Hreq[current_master] && Hready);
    end

    // Grant decision
    always_comb begin

        granted_master  = (ready_for_handover && Htrans == NONSEQ) ? next_master : current_master;
        if (Hresetn) begin
            Hgrant = 'b0;
            valid_transfer = 0;
        end else begin
            Hgrant = 0;
            Hgrant[granted_master] = 1;
            valid_transfer = Hready && (Htrans == NONSEQ || Htrans == SEQ);
        end
    end

    // FSM and burst tracking
    always_ff @(posedge Hclk or posedge Hresetn) begin
        if (Hresetn) begin
            current_master <= 'd0;
            burst_counter  <= 0;
            in_burst       <= 0;
            is_incr        <= 0;
        end else begin
                
            current_master <= granted_master;

            // Start of burst
            if (!in_burst && valid_transfer && Hreq[current_master]) begin
                in_burst      <= 1;
                is_incr       <= (Hburst == 3'b001); // INCR
                burst_counter <= (Hburst == 3'b001) ? 0 : burst_len - 1;
            end
            // During burst
            else if (in_burst) begin
                // For INCR, clear in_burst if master drops request
                if (is_incr && !Hreq[current_master])
                    in_burst <= 0;
                // For non-INCR, decrement burst_counter on valid transfer
                else if (!is_incr && valid_transfer) begin
                    if (burst_counter != 0)
                        burst_counter <= burst_counter - 1;
                    if (burst_counter == 0)
                        in_burst <= 0;
                end
            end
        end
    end

    // Output active master
    assign Hmaster = current_master;

endmodule