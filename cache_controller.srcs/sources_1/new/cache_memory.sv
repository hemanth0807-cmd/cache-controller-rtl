`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 25.07.2026 17:10:23
// Design Name: 
// Module Name: cache_memory
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////



module cache_memory #(
    parameter ADDR_WIDTH   = 32,
    parameter LINE_SIZE    = 128,
    parameter NUM_LINES    = 64,
    
    parameter INDEX_WIDTH  = $clog2(NUM_LINES),
    parameter OFFSET_WIDTH = $clog2(LINE_SIZE/8),
    parameter TAG_WIDTH    = ADDR_WIDTH - INDEX_WIDTH - OFFSET_WIDTH
)(
    input  logic clk,
    input  logic rst_n,

    // Read Address
    input logic [INDEX_WIDTH-1:0] index,

    // Write Interface
    input  logic write_en,
    input logic [LINE_SIZE-1:0] new_data,
    input logic [TAG_WIDTH-1:0]  new_tag,
    input  logic  new_valid,
    input  logic  new_dirty,

    // Read Outputs
    output logic [LINE_SIZE-1:0] stored_data,
    output logic [TAG_WIDTH-1:0] stored_tag,
    output logic  stored_valid,
    output logic  stored_dirty
);

    

    //------------------------------------------------------------
    // Cache Arrays
    //------------------------------------------------------------
    logic [LINE_SIZE-1:0] data_array  [0:NUM_LINES-1];
    logic [TAG_WIDTH-1:0] tag_array   [0:NUM_LINES-1];
    logic                 valid_array [0:NUM_LINES-1];
    logic                 dirty_array [0:NUM_LINES-1];

    //------------------------------------------------------------
    // Combinational Read
    //------------------------------------------------------------
    always_comb begin
        stored_data  = data_array[index];
        stored_tag   = tag_array[index];
        stored_valid = valid_array[index];
        stored_dirty = dirty_array[index];
    end

    //------------------------------------------------------------
    // Synchronous Write + Reset
    //------------------------------------------------------------
    integer i;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            for (i = 0; i < NUM_LINES; i = i + 1) begin
                valid_array[i] <= 1'b0;
                dirty_array[i] <= 1'b0;
            end
        end
        else if (write_en) begin
            data_array[index]  <= new_data;
            tag_array[index]   <= new_tag;
            valid_array[index] <= new_valid;
            dirty_array[index] <= new_dirty;
        end
    end

endmodule
