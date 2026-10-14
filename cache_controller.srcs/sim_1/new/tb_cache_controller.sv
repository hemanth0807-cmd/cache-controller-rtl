`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 26.07.2026 17:53:34
// Design Name: 
// Module Name: tb_cache_controller
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

module tb_cache_controller;

    //============================================================
    // Parameters
    //============================================================

    localparam ADDR_WIDTH     = 32;
    localparam CPU_DATA_WIDTH = 32;
    localparam LINE_SIZE      = 128;
    localparam NUM_LINES      = 64;

    localparam LINE_BYTES     = LINE_SIZE / 8;


    localparam MEM_LINES = 2048;


    //============================================================
    // Signals
    //============================================================

    logic clk;
    logic rst_n;

    // CPU interface
    logic                      cpu_read;
    logic                      cpu_write;
    logic [ADDR_WIDTH-1:0]     cpu_addr;
    logic [CPU_DATA_WIDTH-1:0] cpu_wdata;

    logic [CPU_DATA_WIDTH-1:0] cpu_rdata;
    logic                      cpu_ready;


    // Main memory interface
    logic                  mem_read;
    logic                  mem_write;
    logic [ADDR_WIDTH-1:0] mem_addr;
    logic [LINE_SIZE-1:0]  mem_wdata;

    logic [LINE_SIZE-1:0] mem_rdata;
    logic                 mem_ready;


    //============================================================
    // Testbench Main Memory
    //============================================================

    logic [LINE_SIZE-1:0] main_memory [0:MEM_LINES-1];

    integer mem_read_count;
    integer mem_write_count;


    //============================================================
    // DUT
    //============================================================

    cache_controller #(
        .ADDR_WIDTH     (ADDR_WIDTH),
        .CPU_DATA_WIDTH (CPU_DATA_WIDTH),
        .LINE_SIZE      (LINE_SIZE),
        .NUM_LINES      (NUM_LINES)
    ) dut (
        .clk       (clk),
        .rst_n     (rst_n),

        .cpu_read  (cpu_read),
        .cpu_write (cpu_write),
        .cpu_addr  (cpu_addr),
        .cpu_wdata (cpu_wdata),

        .cpu_rdata (cpu_rdata),
        .cpu_ready (cpu_ready),

        .mem_read  (mem_read),
        .mem_write (mem_write),
        .mem_addr  (mem_addr),
        .mem_wdata (mem_wdata),

        .mem_rdata (mem_rdata),
        .mem_ready (mem_ready)
    );


    //============================================================
    // Clock
    //============================================================

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end


    //============================================================
    // Main Memory Model
    //
    //============================================================

    initial begin

        mem_ready = 1'b0;
        mem_rdata = '0;

        mem_read_count  = 0;
        mem_write_count = 0;

        forever begin

            @(posedge clk);

            //----------------------------------------------------
            // Memory READ
            //----------------------------------------------------

            if (mem_read) begin

                mem_read_count = mem_read_count + 1;

                $display(
                    "[%0t] MEMORY READ  addr=%h",
                    $time,
                    mem_addr
                );

                // Simulated memory latency
                repeat (3)
                    @(posedge clk);

                mem_rdata = main_memory[mem_addr / LINE_BYTES];
                mem_ready = 1'b1;

                @(posedge clk);

                mem_ready = 1'b0;
                mem_rdata = '0;

                wait (!mem_read);

            end


            //----------------------------------------------------
            // Memory WRITE
            //----------------------------------------------------

            else if (mem_write) begin

                mem_write_count = mem_write_count + 1;

                $display(
                    "[%0t] MEMORY WRITE addr=%h data=%h",
                    $time,
                    mem_addr,
                    mem_wdata
                );

                // Simulated memory latency
                repeat (3)
                    @(posedge clk);

                main_memory[mem_addr / LINE_BYTES] = mem_wdata;

                mem_ready = 1'b1;

                @(posedge clk);

                mem_ready = 1'b0;

                wait (!mem_write);

            end

        end

    end


    //============================================================
    // CPU READ TASK
    //============================================================

    task automatic cpu_read_task(
        input logic [ADDR_WIDTH-1:0] address,
        input logic [CPU_DATA_WIDTH-1:0] expected_data
    );

        begin

            //----------------------------------------------------
            // Send request
            //----------------------------------------------------

            @(negedge clk);

            cpu_addr  = address;
            cpu_read  = 1'b1;
            cpu_write = 1'b0;

            //----------------------------------------------------
            // Controller captures request at next posedge
            //----------------------------------------------------

            @(negedge clk);

            cpu_read = 1'b0;

            //----------------------------------------------------
            // Wait for completion
            //----------------------------------------------------

            wait (cpu_ready == 1'b1);

            //----------------------------------------------------
            // Check result
            //----------------------------------------------------

            if (cpu_rdata === expected_data) begin

                $display(
                    "[%0t] READ PASS  addr=%h data=%h",
                    $time,
                    address,
                    cpu_rdata
                );

            end
            else begin

                $error(
                    "[%0t] READ FAIL addr=%h expected=%h got=%h",
                    $time,
                    address,
                    expected_data,
                    cpu_rdata
                );

            end

            //----------------------------------------------------
            // Wait for controller to return to IDLE
            //----------------------------------------------------

            @(negedge clk);

        end

    endtask


    //============================================================
    // CPU WRITE TASK
    //============================================================

    task automatic cpu_write_task(
        input logic [ADDR_WIDTH-1:0]     address,
        input logic [CPU_DATA_WIDTH-1:0] data
    );

        begin

            //----------------------------------------------------
            // Send write request
            //----------------------------------------------------

            @(negedge clk);

            cpu_addr  = address;
            cpu_wdata = data;

            cpu_read  = 1'b0;
            cpu_write = 1'b1;

            //----------------------------------------------------
            // Request captured
            //----------------------------------------------------

            @(negedge clk);

            cpu_write = 1'b0;

            //----------------------------------------------------
            // Wait for completion
            //----------------------------------------------------

            wait (cpu_ready == 1'b1);

            $display(
                "[%0t] WRITE COMPLETE addr=%h data=%h",
                $time,
                address,
                data
            );

            @(negedge clk);

        end

    endtask


    //============================================================
    // Test Sequence
    //============================================================

    integer i;
    integer reads_before;

    initial begin

        //--------------------------------------------------------
        // Initial values
        //--------------------------------------------------------

        rst_n = 1'b0;

        cpu_read  = 1'b0;
        cpu_write = 1'b0;
        cpu_addr  = '0;
        cpu_wdata = '0;


        //--------------------------------------------------------
        // Clear TB main memory
        //--------------------------------------------------------

        for (i = 0; i < MEM_LINES; i = i + 1)
            main_memory[i] = '0;


        //========================================================
        // Initialize line at address 0x1000
        //========================================================

        main_memory[32'h1000 / LINE_BYTES] = {

            32'h44444444,    // 0x100C : Word 3
            32'h33333333,    // 0x1008 : Word 2
            32'h22222222,    // 0x1004 : Word 1
            32'h11111111     // 0x1000 : Word 0

        };


        main_memory[32'h1400 / LINE_BYTES] = {

            32'hDDDDDDDD,
            32'hCCCCCCCC,
            32'hBBBBBBBB,
            32'hAAAAAAAA

        };
        main_memory[32'h1800 / LINE_BYTES] = {
            32'h88888888,
            32'h77777777,
            32'h66666666,
            32'h55555555
        };


        //--------------------------------------------------------
        // Reset
        //--------------------------------------------------------

        repeat (3)
            @(posedge clk);

        @(negedge clk);
        rst_n = 1'b1;

        repeat (2)
            @(posedge clk);


        //========================================================
        // TEST 1
        // Read Miss -> Refill
        //========================================================

        $display("\n========== TEST 1: READ MISS ==========");

        cpu_read_task(
            32'h00001008,
            32'h33333333
        );


        //========================================================
        // TEST 2
        // Read Hit
        //========================================================

        $display("\n========== TEST 2: READ HIT ==========");

        reads_before = mem_read_count;

        cpu_read_task(
            32'h00001004,
            32'h22222222
        );

        if (mem_read_count == reads_before)
            $display("READ HIT correctly avoided main memory");
        else
            $error("READ HIT unexpectedly accessed main memory");


        //========================================================
        // TEST 3
        // Write Hit
        //
        // Change Word 2:
        //========================================================

        $display("\n========== TEST 3: WRITE HIT ==========");

        cpu_write_task(
            32'h00001008,
            32'hDEADBEEF
        );


        //========================================================
        // TEST 4
        // Read after Write
        //========================================================

        $display("\n========== TEST 4: READ AFTER WRITE ==========");

        cpu_read_task(
            32'h00001008,
            32'hDEADBEEF
        );


        //--------------------------------------------------------
        // Main memory must STILL contain old value.
        //--------------------------------------------------------

        if (
            main_memory[32'h1000 / LINE_BYTES][95:64]
            ===
            32'h33333333
        ) begin

            $display(
                "WRITE-BACK behavior correct: main memory still contains 33333333"
            );

        end
        else begin

            $error(
                "Main memory changed before dirty eviction"
            );

        end


        //========================================================
        // TEST 5
        // Dirty Conflict Miss
        //========================================================

        $display("\n========== TEST 5: DIRTY CONFLICT MISS ==========");

        cpu_read_task(
            32'h00001400,
            32'hAAAAAAAA
        );


        //========================================================
        // TEST 6
        // Verify dirty write-back
        //
        //========================================================

        $display("\n========== TEST 6: VERIFY WRITEBACK ==========");

        if (
            main_memory[32'h1000 / LINE_BYTES][95:64]
            ===
            32'hDEADBEEF
        ) begin

            $display(
                "WRITEBACK PASS: main memory updated to DEADBEEF"
            );

        end
        else begin

            $error(
                "WRITEBACK FAIL: expected DEADBEEF, got %h",
                main_memory[32'h1000 / LINE_BYTES][95:64]
            );

        end
        
        //========================================================
        // TEST 7
        // Clean Conflict Miss
        //========================================================
        
        $display("\n========== TEST 7: CLEAN CONFLICT MISS ==========");
        
        begin
            integer writes_before;
        
            writes_before = mem_write_count;
        
            cpu_read_task(
                32'h00001804,
                32'h66666666
            );
        
            if (mem_write_count == writes_before) begin
                $display(
                    "CLEAN MISS PASS: refill occurred without writeback"
                );
            end
            else begin
                $error(
                    "CLEAN MISS FAIL: unexpected memory write"
                );
            end
        end
        
        //========================================================
        // TEST 8
        // Verify all four word offsets
        // All accesses should HIT.
        //========================================================
        
        $display("\n========== TEST 8: ALL WORD OFFSETS ==========");
        
        reads_before = mem_read_count;
        
        cpu_read_task(
            32'h00001800,
            32'h55555555
        );
        
        cpu_read_task(
            32'h00001804,
            32'h66666666
        );
        
        cpu_read_task(
            32'h00001808,
            32'h77777777
        );
        
        cpu_read_task(
            32'h0000180C,
            32'h88888888
        );
        
        if (mem_read_count == reads_before)
            $display("WORD OFFSET PASS: all four accesses were cache hits");
        else
            $error("WORD OFFSET FAIL: unexpected memory access");

        //========================================================
        // Summary
        //========================================================

        $display("\n========================================");
        $display("CACHE TESTBENCH COMPLETED");
        $display("Memory Reads  = %0d", mem_read_count);
        $display("Memory Writes = %0d", mem_write_count);
        $display("========================================\n");

        repeat (3)
            @(posedge clk);

        $finish;

    end


    //============================================================
    // Timeout
    // Prevent simulation from hanging forever
    //============================================================

    initial begin

        #10000;

        $fatal(
            1,
            "TESTBENCH TIMEOUT"
        );

    end


endmodule