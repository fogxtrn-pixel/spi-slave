module h04_spi_slave_tb;
    logic sclk=0, mosi=0, cs_n=1;
    logic [7:0] tx_byte=8'h96;
    logic miso;
    logic [7:0] rx_byte;

    h04_spi_slave #(.MSB_FIRST(1'b1)) dut(
        .sclk(sclk), .mosi(mosi), .cs_n(cs_n),
        .tx_byte(tx_byte), .miso(miso), .rx_byte(rx_byte));

    task automatic spi_bit(input logic master_bit);
        begin
            // Mode 0: data is stable before rising sample edge.
            mosi = master_bit;
            #5 sclk=1;
            #5 sclk=0;
        end
    endtask

    task automatic spi_byte(input logic [7:0] b);
        begin
            spi_bit(b[7]); spi_bit(b[6]); spi_bit(b[5]); spi_bit(b[4]);
            spi_bit(b[3]); spi_bit(b[2]); spi_bit(b[1]); spi_bit(b[0]);
        end
    endtask

    initial begin
        // Complete transaction.
        #2 cs_n=0;
        #1;
        spi_byte(8'h3C);
        #1 cs_n=1;
        #1;
        assert(rx_byte==8'h3C) else $fatal(1,"RX mismatch");

        // Mid-transaction abort.
        #5 cs_n=0;
        spi_bit(1'b1); spi_bit(1'b0); spi_bit(1'b1);
        #1 cs_n=1;

        // Consecutive complete transaction.
        #5 cs_n=0;
        spi_byte(8'hA5);
        #1 cs_n=1;
        #1;
        assert(rx_byte==8'hA5) else $fatal(1,"Second RX mismatch");

        $display("H04 TB completed");
        $finish;
    end
endmodule
