
`timescale 1ns/1ps

module tb_spi_slave;

    reg clk = 0;
    reg rst = 1;
    reg sclk = 0;
    reg mosi = 0;
    reg cs_n = 1;
    reg [7:0] data_in = 8'hA5;

    wire miso;
    wire [7:0] data_out;
    wire done;

    integer done_count = 0;
    integer errors = 0;
    integer i;
    integer saved_count;

    spi_slave dut (
        .clk(clk),
        .rst(rst),
        .sclk(sclk),
        .mosi(mosi),
        .cs_n(cs_n),
        .data_in(data_in),
        .miso(miso),
        .data_out(data_out),
        .done(done)
    );

    always #5 clk = ~clk;

    always @(posedge clk) begin
        if (!rst && done)
            done_count = done_count + 1;
    end

    task send_byte;
        input [7:0] value;
        integer j;
        begin
            for (j = 7; j >= 0; j = j - 1) begin
                mosi = value[j];
                #40 sclk = 1;
                #40 sclk = 0;
            end
        end
    endtask

    initial begin
        $dumpfile("spi_slave.vcd");
        $dumpvars(0, tb_spi_slave);

        // Reset
        #20 rst = 0;
        #20;

        // Test 1: Receive complete byte
        cs_n = 0;
        #20;
        send_byte(8'h3C);
        #30;

        if (data_out == 8'h3C && done_count == 1)
            $display("PASS: Complete 8-bit transfer");
        else begin
            $display("FAIL: Complete transfer, data=%h done_count=%0d",
                     data_out, done_count);
            errors = errors + 1;
        end

        // Test 2: Abort after three bits
        cs_n = 1;
        #40;
        saved_count = done_count;

        cs_n = 0;
        #20;

        repeat (3) begin
            mosi = 1;
            #40 sclk = 1;
            #40 sclk = 0;
        end

        cs_n = 1;
        #40;

        if (done_count == saved_count)
            $display("PASS: CS aborts incomplete byte");
        else begin
            $display("FAIL: Unexpected done pulse during abort");
            errors = errors + 1;
        end

        // Test 3: New transaction after abort
        cs_n = 0;
        #20;
        send_byte(8'h96);
        #30;

        if (data_out == 8'h96 &&
            done_count == saved_count + 1)
            $display("PASS: New transaction after abort");
        else begin
            $display("FAIL: Recovery after abort, data=%h done_count=%0d",
                     data_out, done_count);
            errors = errors + 1;
        end

        // Final result
        cs_n = 1;
        #40;

        if (errors == 0)
            $display("ALL TESTS PASSED");
        else
            $display("TESTS FAILED: %0d error(s)", errors);

        $finish;
    end

endmodule
