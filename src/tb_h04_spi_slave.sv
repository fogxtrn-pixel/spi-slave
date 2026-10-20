
`timescale 1ns/1ps

module tb_h04_spi_slave;

    logic sclk = 0;
    logic mosi = 0;
    logic cs_n = 1;
    logic [7:0] tx_byte = 8'hA5;

    logic miso;
    logic [7:0] rx_byte;

    h04_spi_slave dut (
        .sclk(sclk),
        .mosi(mosi),
        .cs_n(cs_n),
        .tx_byte(tx_byte),
        .miso(miso),
        .rx_byte(rx_byte)
    );

    task send_byte(input logic [7:0] value);
        integer i;
        begin
            for (i = 7; i >= 0; i = i - 1) begin
                mosi = value[i];
                #10;
                sclk = 1;
                #10;
                sclk = 0;
            end
        end
    endtask

    initial begin
        $dumpfile("h04_spi_slave.vcd");
        $dumpvars(0, tb_h04_spi_slave);

        // Test 1: Receive a complete byte
        #20;
        cs_n = 0;
        #10;
        send_byte(8'h3C);
        #10;
        cs_n = 1;
        #10;

        if (rx_byte === 8'h3C)
            $display("PASS: Receive complete byte 3C");
        else
            $display("FAIL: Expected 3C, got %h", rx_byte);

        // Test 2: Abort after three bits
        #20;
        cs_n = 0;
        #10;

        repeat (3) begin
            mosi = 1;
            #10 sclk = 1;
            #10 sclk = 0;
        end

        cs_n = 1;
        #10;

        if (rx_byte === 8'h3C)
            $display("PASS: Incomplete transaction not committed");
        else
            $display("FAIL: rx_byte changed to %h", rx_byte);

        $display("Simulation finished");
        $finish;
    end

endmodule
