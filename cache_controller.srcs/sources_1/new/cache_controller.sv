`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 26.07.2026 02:27:37
// Design Name: 
// Module Name: cache_controller
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




module cache_controller #(
    parameter ADDR_WIDTH     = 32,
    parameter CPU_DATA_WIDTH = 32,
    parameter LINE_SIZE      = 128,
    parameter NUM_LINES      = 64,

    parameter INDEX_WIDTH  = $clog2(NUM_LINES),
    parameter OFFSET_WIDTH = $clog2(LINE_SIZE/8),
    parameter TAG_WIDTH    = ADDR_WIDTH - INDEX_WIDTH - OFFSET_WIDTH,

    parameter WORDS_PER_LINE = LINE_SIZE / CPU_DATA_WIDTH,
    parameter WORD_SEL_WIDTH = $clog2(WORDS_PER_LINE)
)(
    input  logic clk,
    input  logic rst_n,

    //============================================================
    // CPU Interface
    //============================================================
    input  logic                      cpu_read,
    input  logic                      cpu_write,
    input  logic [ADDR_WIDTH-1:0]     cpu_addr,
    input  logic [CPU_DATA_WIDTH-1:0] cpu_wdata,

    output logic [CPU_DATA_WIDTH-1:0] cpu_rdata,
    output logic                      cpu_ready,

    //============================================================
    // Main Memory Interface
    // Memory transfers one complete cache line at a time.
    //============================================================
    output logic                  mem_read,
    output logic                  mem_write,
    output logic [ADDR_WIDTH-1:0] mem_addr,
    output logic [LINE_SIZE-1:0]  mem_wdata,

    input  logic [LINE_SIZE-1:0]  mem_rdata,
    input  logic                  mem_ready
);

    //============================================================
    // FSM
    //============================================================

    typedef enum logic [2:0] {
        IDLE,
        LOOKUP,
        WRITEBACK,
        REFILL,
        RESPOND
    } state_t;

    state_t current_state;
    state_t next_state;


    //============================================================
    // Latched CPU Request
    //============================================================

    logic [ADDR_WIDTH-1:0]     req_addr;
    logic [CPU_DATA_WIDTH-1:0] req_wdata;
    logic                      req_read;
    logic                      req_write;


    //============================================================
    // Address Fields
    //============================================================

    logic [TAG_WIDTH-1:0]      req_tag;
    logic [INDEX_WIDTH-1:0]    req_index;
    logic [OFFSET_WIDTH-1:0]   req_offset;
    logic [WORD_SEL_WIDTH-1:0] word_index;

    assign req_tag =
        req_addr[ADDR_WIDTH-1 -: TAG_WIDTH];

    assign req_index =
        req_addr[OFFSET_WIDTH +: INDEX_WIDTH];

    assign req_offset =
        req_addr[OFFSET_WIDTH-1:0];

    assign word_index =
        req_offset[OFFSET_WIDTH-1 -: WORD_SEL_WIDTH];


    //============================================================
    // Cache Memory Interface
    //============================================================

    logic [INDEX_WIDTH-1:0] cache_index;

    logic                   cache_write_en;
    logic [LINE_SIZE-1:0]   cache_new_data;
    logic [TAG_WIDTH-1:0]   cache_new_tag;
    logic                   cache_new_valid;
    logic                   cache_new_dirty;

    logic [LINE_SIZE-1:0]   cache_stored_data;
    logic [TAG_WIDTH-1:0]   cache_stored_tag;
    logic                   cache_stored_valid;
    logic                   cache_stored_dirty;


    //============================================================
    // Cache Memory Instance
    //============================================================

    cache_memory #(
        .ADDR_WIDTH   (ADDR_WIDTH),
        .LINE_SIZE    (LINE_SIZE),
        .NUM_LINES    (NUM_LINES),
        .INDEX_WIDTH  (INDEX_WIDTH),
        .OFFSET_WIDTH (OFFSET_WIDTH),
        .TAG_WIDTH    (TAG_WIDTH)
    ) u_cache_memory (
        .clk          (clk),
        .rst_n        (rst_n),

        .index        (cache_index),

        .write_en     (cache_write_en),
        .new_data     (cache_new_data),
        .new_tag      (cache_new_tag),
        .new_valid    (cache_new_valid),
        .new_dirty    (cache_new_dirty),

        .stored_data  (cache_stored_data),
        .stored_tag   (cache_stored_tag),
        .stored_valid (cache_stored_valid),
        .stored_dirty (cache_stored_dirty)
    );


    //============================================================
    // Hit Detection
    //============================================================

    logic hit;

    assign hit =
        cache_stored_valid &&
        (req_tag == cache_stored_tag);


    //============================================================
    // Temporary Modified Cache Line
    //============================================================

    logic [LINE_SIZE-1:0] modified_line;

    always_comb begin

        modified_line = cache_stored_data;

        modified_line[
            word_index * CPU_DATA_WIDTH +: CPU_DATA_WIDTH
        ] = req_wdata;

    end


    //============================================================
    // CPU Response Register
    //============================================================

    logic [CPU_DATA_WIDTH-1:0] resp_data;

    always_ff @(posedge clk) begin

        if (!rst_n) begin

            resp_data <= '0;

        end
        else begin

            //----------------------------------------------------
            // Read Hit
            //----------------------------------------------------

            if ((current_state == LOOKUP) &&
                hit &&
                req_read) begin

                resp_data <= cache_stored_data[
                    word_index * CPU_DATA_WIDTH +: CPU_DATA_WIDTH
                ];

            end

            //----------------------------------------------------
            // Read Miss - Data arrives from memory
            //----------------------------------------------------

            else if ((current_state == REFILL) &&
                     mem_ready &&
                     req_read) begin

                resp_data <= mem_rdata[
                    word_index * CPU_DATA_WIDTH +: CPU_DATA_WIDTH
                ];

            end

        end

    end


    //============================================================
    // State Register
    //============================================================

    always_ff @(posedge clk) begin

        if (!rst_n)
            current_state <= IDLE;
        else
            current_state <= next_state;

    end


    //============================================================
    // CPU Request Registers
    //============================================================

    always_ff @(posedge clk) begin

        if (!rst_n) begin

            req_addr  <= '0;
            req_wdata <= '0;
            req_read  <= 1'b0;
            req_write <= 1'b0;

        end
        else if ((current_state == IDLE) &&
                 (cpu_read || cpu_write)) begin

            req_addr  <= cpu_addr;
            req_wdata <= cpu_wdata;
            req_read  <= cpu_read;
            req_write <= cpu_write;

        end

    end


    //============================================================
    // Next-State Logic
    //============================================================

    always_comb begin

        // Default: remain in current state
        next_state = current_state;

        case (current_state)

            //----------------------------------------------------
            // Wait for CPU request
            //----------------------------------------------------

            IDLE: begin

                if (cpu_read || cpu_write)
                    next_state = LOOKUP;

            end


            //----------------------------------------------------
            // Check cache
            //----------------------------------------------------

            LOOKUP: begin

                if (hit) begin

                    // Both read hit and write hit complete
                    next_state = RESPOND;

                end
                else if (cache_stored_valid &&
                         cache_stored_dirty) begin

                    // Dirty victim must be written back first
                    next_state = WRITEBACK;

                end
                else begin

                    // Empty or clean victim
                    next_state = REFILL;

                end

            end


            //----------------------------------------------------
            // Evict dirty line
            //----------------------------------------------------

            WRITEBACK: begin

                if (mem_ready)
                    next_state = REFILL;

            end


            //----------------------------------------------------
            // Fetch requested line
            //----------------------------------------------------

            REFILL: begin

                if (mem_ready)
                    next_state = RESPOND;

            end


            //----------------------------------------------------
            // Tell CPU transaction completed
            //----------------------------------------------------

            RESPOND: begin

                next_state = IDLE;

            end


            //----------------------------------------------------
            // Safety recovery
            //----------------------------------------------------

            default: begin

                next_state = IDLE;

            end

        endcase

    end


    //============================================================
    // Output / Control Logic
    //============================================================

    always_comb begin

        //--------------------------------------------------------
        // Default values
        //--------------------------------------------------------

        cpu_rdata = resp_data;
        cpu_ready = 1'b0;

        mem_read  = 1'b0;
        mem_write = 1'b0;
        mem_addr  = '0;
        mem_wdata = '0;

        cache_index     = req_index;

        cache_write_en  = 1'b0;
        cache_new_data  = '0;
        cache_new_tag   = '0;
        cache_new_valid = 1'b0;
        cache_new_dirty = 1'b0;


        case (current_state)

            //----------------------------------------------------
            // IDLE
            //----------------------------------------------------

            IDLE: begin

                // Waiting for request.
                // Request is captured by request registers.

            end


            //----------------------------------------------------
            // LOOKUP
            //----------------------------------------------------

            LOOKUP: begin

                if (hit && req_write) begin

                    /*
                     * WRITE HIT
                     *
                     * Modify requested word.
                     * Tag remains unchanged.
                     * Line remains valid.
                     * Line becomes dirty.
                     */

                    cache_write_en  = 1'b1;
                    cache_new_data  = modified_line;
                    cache_new_tag   = cache_stored_tag;
                    cache_new_valid = 1'b1;
                    cache_new_dirty = 1'b1;

                end

                /*
                 * Read hit requires no cache write.
                 *
                 * resp_data captures the selected word
                 * in the sequential response block.
                 */

            end


            //----------------------------------------------------
            // WRITEBACK
            //----------------------------------------------------

            WRITEBACK: begin

                mem_write = 1'b1;

                mem_addr = {
                    cache_stored_tag,
                    req_index,
                    {OFFSET_WIDTH{1'b0}}
                };

                mem_wdata = cache_stored_data;

            end



            REFILL: begin

                mem_read = 1'b1;

                mem_addr = {
                    req_tag,
                    req_index,
                    {OFFSET_WIDTH{1'b0}}
                };

                if (mem_ready) begin

                    cache_write_en  = 1'b1;
                    cache_new_tag   = req_tag;
                    cache_new_valid = 1'b1;


                    //------------------------------------------------
                    // READ MISS
                    //------------------------------------------------

                    if (req_read) begin

                        cache_new_data  = mem_rdata;
                        cache_new_dirty = 1'b0;

                    end


                    //------------------------------------------------
                    // WRITE MISS
                    //------------------------------------------------

                    else if (req_write) begin

                        cache_new_data = mem_rdata;

                

                        cache_new_data[
                            word_index * CPU_DATA_WIDTH
                            +: CPU_DATA_WIDTH
                        ] = req_wdata;

                        cache_new_dirty = 1'b1;

                    end

                end

            end


            //----------------------------------------------------
            // RESPOND
            //----------------------------------------------------

            RESPOND: begin

                cpu_ready = 1'b1;
                cpu_rdata = resp_data;

            end


            default: begin
            end

        endcase

    end
endmodule
