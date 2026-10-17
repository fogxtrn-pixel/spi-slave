
module spi_slave (
    input  wire       clk,
    input  wire       rst,
    input  wire       sclk,
    input  wire       mosi,
    input  wire       cs_n,
    input  wire [7:0] data_in,
    output reg        miso,
    output reg  [7:0] data_out,
    output reg        done
);

    reg [7:0] tx_data;
    reg [7:0] rx_data;
    reg [2:0] bit_count;
    reg [7:0] tx_shift;
    reg [7:0] rx_shift;
    reg sclk_prev;
    reg cs_prev;

    wire sclk_rise = sclk & ~sclk_prev;
    wire sclk_fall = ~sclk & sclk_prev;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            sclk_prev <= 1'b0;
            cs_prev   <= 1'b1;
            bit_count <= 3'd0;
            tx_shift  <= 8'd0;
            rx_shift  <= 8'd0;
            tx_data   <= 8'd0;
            rx_data   <= 8'd0;
            data_out  <= 8'd0;
            miso      <= 1'b0;
            done      <= 1'b0;
        end else begin
            sclk_prev <= sclk;
            cs_prev   <= cs_n;
            done      <= 1'b0;

            if (cs_n) begin
                bit_count <= 3'd0;
                tx_shift  <= data_in;
                rx_shift  <= 8'd0;
                miso      <= 1'b0;
            end else begin
                if (cs_prev) begin
                    tx_shift  <= data_in;
                    rx_shift  <= 8'd0;
                    bit_count <= 3'd0;
                    miso      <= data_in[7];
                end

                if (sclk_rise) begin
                    rx_shift <= {rx_shift[6:0], mosi};
                    if (bit_count == 3'd7) begin
                        data_out <= {rx_shift[6:0], mosi};
                        done <= 1'b1;
                        bit_count <= 3'd0;
                    end else begin
                        bit_count <= bit_count + 1'b1;
                    end
                end

                if (sclk_fall) begin
                    tx_shift <= {tx_shift[6:0], 1'b0};
                    miso <= tx_shift[6];
                end
            end
        end
    end

endmodule
