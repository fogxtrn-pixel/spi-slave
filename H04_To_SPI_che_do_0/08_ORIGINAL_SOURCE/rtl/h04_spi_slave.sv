module h04_spi_slave #(
    parameter bit MSB_FIRST = 1'b1
) (
    input  logic       sclk,
    input  logic       mosi,
    input  logic       cs_n,
    input  logic [7:0] tx_byte,
    output logic       miso,
    output logic [7:0] rx_byte
);

    // Receive path: SCLK is the externally supplied SPI clock.
    logic [7:0] rx_shift;
    logic [2:0] rx_count;

    // Transmit path: separate falling-edge storage makes the mode-0 update edge explicit.
    logic [7:0] tx_shift;
    logic [2:0] tx_count;

    // Rising edge = mode-0 sample edge.
    always_ff @(posedge sclk or posedge cs_n) begin
        if (cs_n) begin
            rx_shift <= '0;
            rx_count <= '0;
        end else begin
            if (MSB_FIRST)
                rx_shift <= {rx_shift[6:0], mosi};
            else
                rx_shift <= {mosi, rx_shift[7:1]};

            if (rx_count != 3'd7)
                rx_count <= rx_count + 1'b1;
        end
    end

    // Falling edge = mode-0 data-update edge.
    always_ff @(negedge sclk or posedge cs_n) begin
        if (cs_n) begin
            tx_shift <= tx_byte;
            tx_count <= 3'd0;
            miso <= MSB_FIRST ? tx_byte[7] : tx_byte[0];
        end else begin
            if (tx_count != 3'd7) begin
                tx_count <= tx_count + 1'b1;
                if (MSB_FIRST) begin
                    tx_shift <= {tx_shift[6:0],1'b0};
                    miso <= tx_shift[6];
                end else begin
                    tx_shift <= {1'b0,tx_shift[7:1]};
                    miso <= tx_shift[1];
                end
            end else begin
                tx_shift <= tx_shift;
                miso <= miso;
            end
        end
    end

    // Commit only a complete 8-bit transaction at CS deassertion.
    // In a real wrapper this policy must match the official H04 interface semantics.
    always_ff @(posedge cs_n) begin
        if (rx_count == 3'd7)
            rx_byte <= rx_shift;
    end

endmodule
