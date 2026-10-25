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
        $dumpfile("h04_spi_slave.vcd");
        $dumpvars(0, h04_spi_slave_tb);

        // Khoi tao reset bang canh len that cua cs_n
        cs_n = 1'b0;
        #1 cs_n = 1'b1;
        #1;

        // TC01: Giao dich day du 8 bit
        #2 cs_n = 1'b0;
        #1;
        spi_byte(8'h3C);
        #1 cs_n = 1'b1;
        #1;
        assert(rx_byte == 8'h3C)
            else $fatal(1, "TC01 failed: RX mismatch");

        // TC02: Huy giao dich giua chung
        #5 cs_n = 1'b0;
        spi_bit(1'b1);
        spi_bit(1'b0);
        spi_bit(1'b1);
        #1 cs_n = 1'b1;

        // TC03: Giao dich tiep theo sau khi huy
        #5 cs_n = 1'b0;
        spi_byte(8'hA5);
        #1 cs_n = 1'b1;
        #1;
        assert(rx_byte == 8'hA5)
            else $fatal(1, "TC03 failed: Second RX mismatch");

        // TC06: Nhả CS ngay sau bit thu 8
        #5 cs_n = 1'b0;
        spi_byte(8'h69);
        cs_n = 1'b1;
        #1;
        assert(rx_byte == 8'h69)
            else $fatal(1, "TC06 failed: Boundary byte mismatch");

        // Kiem tra giao dich moi khong bi anh huong boi giao dich truoc
        #5 cs_n = 1'b0;
        spi_byte(8'h96);
        #1 cs_n = 1'b1;
        #1;
        assert(rx_byte == 8'h96)
            else $fatal(1, "TC06 failed: Next transaction mismatch");

        // TC07a: Du lieu toan 0
        #5 cs_n = 1'b0;
        spi_byte(8'h00);
        #1 cs_n = 1'b1;
        #1;
        assert(rx_byte == 8'h00)
            else $fatal(1, "TC07a failed: All-zero mismatch");

        // TC07b: Du lieu toan 1
        #5 cs_n = 1'b0;
        spi_byte(8'hFF);
        #1 cs_n = 1'b1;
        #1;
        assert(rx_byte == 8'hFF)
            else $fatal(1, "TC07b failed: All-one mismatch");

        $display("All SPI test cases passed");
        $finish;
    end
endmodule
