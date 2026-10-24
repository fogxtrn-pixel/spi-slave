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
    // 4 bits: 0..8 are NINE distinct states. A 3-bit saturating counter cannot
    // tell "7 edges seen" from "8 edges seen", so a 7-bit transaction would be
    // committed as if it were a complete byte.
    logic [3:0] rx_count;

    // Transmit path: separate falling-edge storage makes the mode-0 update edge explicit.
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

            // Every branch ASSIGNS, so no X value can block its own update
            // (the old "if (rx_count != 3'd7)" was an X-lock: the condition
            // that lets the counter leave X depends on the X itself).
            rx_count <= (rx_count == 4'd8) ? 4'd8 : (rx_count + 1'b1);
        end
    end

    // Falling edge = mode-0 data-update edge.
    // No asynchronous load of a NON-CONSTANT value: a standard cell library only
    // offers SET/RESET to a constant, so "tx_shift <= tx_byte" at posedge cs_n
    // left unmapped $_ALDFFE_NPP_ cells and a behavioural netlist OpenSTA cannot read.
    always_ff @(negedge sclk or posedge cs_n) begin
        if (cs_n)
            tx_count <= 3'd0;
        else
            tx_count <= (tx_count == 3'd7) ? 3'd7 : (tx_count + 1'b1);
    end

    assign miso = MSB_FIRST ? tx_byte[3'd7 - tx_count] : tx_byte[tx_count];

    // Commit only a complete 8-bit transaction at CS deassertion.
    // In a real wrapper this policy must match the official H04 interface semantics.
    always_ff @(posedge cs_n) begin
        if (rx_count == 4'd8)
            rx_byte <= rx_shift;
    end

endmodule
