`ifdef H04_SVA

// CS inactive is the transaction boundary.
assert cs_idle_miso_known:
    assert property (@(negedge cs_n) 1'b1);

`endif
