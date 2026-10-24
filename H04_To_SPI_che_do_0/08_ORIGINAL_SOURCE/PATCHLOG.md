# H04 · Nhật ký vá (PATCHLOG)

**Ngày vá:** 2026-09-24 · **Người duyệt:** giảng viên đã duyệt áp dụng toàn bộ bản vá

## 1. Tóm tắt

| # | File | Loại lỗi | Mô tả một dòng | Ảnh hưởng số liệu |
|---|---|---|---|---|
| P-1 | `05_VERIFICATION/testbench/h04_spi_slave_tb.sv` | Lỗi testbench | Thêm chuỗi khởi tạo tạo **sườn lên thật** của `cs_n` (ISS-1, nguyên nhân kích hoạt) | Không |
| P-2 | `04_IMPLEMENTATION/rtl/h04_spi_slave.sv` | Lỗi thiết kế | Khử **vòng khoá X** ở `rx_count` (ISS-1, nguyên nhân gốc) | Có — chạy lại synth/STA |
| P-3 | `04_IMPLEMENTATION/rtl/h04_spi_slave.sv` | Lỗi thiết kế | Bỏ **nạp bất đồng bộ giá trị không phải hằng** ở `posedge cs_n` (ISS-2) | Có — chạy lại synth/STA |
| P-4 | `04_IMPLEMENTATION/rtl/h04_spi_slave.sv` | Lỗi thiết kế | Bộ đếm nhận 3 bit → 4 bit, đóng **lỗ hổng 7 bit** (ISS-3) | Có — chạy lại synth/STA |

Không đổi giao diện module: tên cổng và độ rộng cổng giữ nguyên hoàn toàn.

## 2. Chi tiết từng bản vá

### P-1 — Testbench thiếu sườn khởi tạo `cs_n`

**File:** `05_VERIFICATION/testbench/h04_spi_slave_tb.sv` · **Dòng:** 27 (đầu khối `initial`)
· **Phán xử:** lỗi ở testbench

**Trước:**
```systemverilog
    initial begin
        // Complete transaction.
        #2 cs_n=0;
```

**Sau:**
```systemverilog
    initial begin
        // Power-on sequence: create a REAL rising edge on cs_n.
        // A declaration initialiser (logic cs_n=1) does NOT generate an edge
        // event per IEEE 1800, so the always_ff reset branches never run and
        // rx_count stays X forever (X-lock).
        cs_n = 1'b0;
        #1 cs_n = 1'b1;
        #1;
        // Complete transaction.
        #2 cs_n=0;
```

**Vì sao:** theo IEEE 1800, giá trị khởi tạo trong khai báo biến static được gán tại thời
điểm 0 **trước** khi mọi `initial`/`always` chạy, nên `logic cs_n=1` không sinh ra sườn nào
mà `always_ff @(posedge cs_n)` quan sát được. Hai nhánh reset của DUT do đó không bao giờ
chạy trong giao dịch đầu.

**Hệ quả:** mô phỏng đi qua được giao dịch thứ nhất. Đây **chỉ** là nguyên nhân kích hoạt;
nguyên nhân gốc nằm ở RTL và được vá riêng ở P-2.

### P-2 — Vòng khoá X (X-lock) ở `rx_count`

**File:** `04_IMPLEMENTATION/rtl/h04_spi_slave.sv` · **Dòng:** 31–32 (bản gốc)
· **Phán xử:** lỗi ở DUT

**Trước:**
```systemverilog
            if (rx_count != 3'd7)
                rx_count <= rx_count + 1'b1;
```

**Sau:**
```systemverilog
            // Every branch ASSIGNS, so no X value can block its own update
            // (the old "if (rx_count != 3'd7)" was an X-lock: the condition
            // that lets the counter leave X depends on the X itself).
            rx_count <= (rx_count == 4'd8) ? 4'd8 : (rx_count + 1'b1);
```

**Vì sao:** `3'bxxx != 3'd7` cho `1'bx`, nên lệnh `if` không thực hiện và `rx_count` giữ
nguyên X mãi mãi. Điều kiện để thoát X lại phụ thuộc chính giá trị đang X. Dạng mới luôn
gán ở mọi nhánh nên không còn vòng khoá.

**Hệ quả:** trung thực mà nói, bản vá này **không tự khử X** (X + 1 vẫn là X). Nó chỉ bỏ
vòng khoá, để một sườn `↑cs_n` bất kỳ sau đó khôi phục được trạng thái. Phương án thêm
chân `rst_n` (known_issues §3.3) **không** được chọn vì nó **đổi giao diện module**, trái
với nguyên tắc "không đổi giao diện" của SPEC §4.2; nếu giảng viên muốn reset nguồn thật
thì đó là một thay đổi tầng 02 phải sinh lại toàn bộ tài liệu giao diện.

### P-3 — Nạp bất đồng bộ giá trị không phải hằng (nguồn gốc lỗi STA)

**File:** `04_IMPLEMENTATION/rtl/h04_spi_slave.sv` · **Dòng:** 36–57 (bản gốc)
· **Phán xử:** lỗi ở DUT

**Trước:**
```systemverilog
    always_ff @(negedge sclk or posedge cs_n) begin
        if (cs_n) begin
            tx_shift <= tx_byte;                        // nap BIEN THIEN
            tx_count <= 3'd0;
            miso <= MSB_FIRST ? tx_byte[7] : tx_byte[0]; // tai suon BAT DONG BO
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
```

**Sau:**
```systemverilog
    always_ff @(negedge sclk or posedge cs_n) begin
        if (cs_n)
            tx_count <= 3'd0;
        else
            tx_count <= (tx_count == 3'd7) ? 3'd7 : (tx_count + 1'b1);
    end

    assign miso = MSB_FIRST ? tx_byte[3'd7 - tx_count] : tx_byte[tx_count];
```

(thanh ghi `tx_shift` bị xoá khỏi phần khai báo, vì không còn ai dùng)

**Vì sao:** `tx_shift <= tx_byte` và `miso <= tx_byte[7]` tại `posedge cs_n` yêu cầu một
**flip-flop có nạp bất đồng bộ giá trị biến thiên**. Thư viện chuẩn chỉ có `SET`/`RESET`
về **hằng** 1 hoặc 0. Yosys đã cảnh báo đúng hai lần (`Async reset value ... is not
constant!`), để lại 8 cell `$_ALDFFE_NPP_` không ánh xạ được, `write_verilog` phải xuất
chúng dưới dạng hành vi (`reg miso;` + `always`), và OpenSTA — vốn chỉ đọc netlist cấu
trúc — dừng ở `netlist.v line 39, syntax error`.

**Chênh lệch so với bản vá đã soạn:** known_issues §5 đề xuất **phương án A** (giữ
`tx_shift`, thêm cờ `tx_loaded`, `miso` tổ hợp). **Phương án A đã được kiểm lại và bị bác
bỏ**: với nó, `tx_shift` chỉ được nạp tại sườn xuống `sclk` **đầu tiên**, nên trong khoảng
từ lúc `cs_n` xuống tới sườn xuống đó, `miso` xuất ra nội dung cũ của `tx_shift` — nghĩa là
**bit 7 bị sai** đúng tại sườn lên lấy mẫu số 1 của chế độ 0. Bản vá đã áp dụng dùng
**bit-select theo `tx_count`** thay cho thanh ghi dịch:

| Thời điểm | Bản gốc (`miso` là thanh ghi) | Bản vá (`miso` tổ hợp theo `tx_count`) |
|---|---|---|
| `cs_n` cao (nghỉ) | `tx_byte[7]` | `tx_count = 0` → `tx_byte[7]` ✅ |
| `cs_n` xuống, trước sườn xuống #1 | `tx_byte[7]` | `tx_count` vẫn 0 → `tx_byte[7]` ✅ |
| sau sườn xuống #k (k = 1…7) | `tx_byte[7-k]` | `tx_count = k` → `tx_byte[7-k]` ✅ |
| sau sườn xuống #8 trở đi | giữ `tx_byte[0]` | `tx_count` bão hoà 7 → `tx_byte[0]` ✅ |

⟹ **dạng sóng `miso` trùng khít bản gốc**, vì `tx_count` chỉ đổi đúng tại sườn xuống `sclk`
— chính là thời điểm `miso` được nạp lại trong bản gốc.

**Hệ quả:** khác biệt duy nhất về ngữ nghĩa là `miso` đọc `tx_byte` **trực tiếp** thay vì
đọc một bản sao chụp tại `↑cs_n`; tầng ngoài phải giữ `tx_byte` ổn định trong suốt giao
dịch (điều kiện vốn đã có trong `02_SPECIFICATION/interface.md`). Bù lại: **hết 8 FF**
`tx_shift`, hết `$_ALDFFE_NPP_`, netlist thuần cấu trúc. Đã kiểm bằng `write_verilog`:
netlist mới **không còn dòng `reg` hay `always` nào** ⇒ OpenSTA đọc được.

### P-4 — Lỗ hổng 7 bit: bộ đếm nhận 3 bit không đủ 9 trạng thái

**File:** `04_IMPLEMENTATION/rtl/h04_spi_slave.sv` · **Dòng:** 14 và 62 (bản gốc)
· **Phán xử:** lỗi ở DUT (ISS-3)

**Trước:**
```systemverilog
    logic [2:0] rx_count;
    ...
        if (rx_count == 3'd7)
            rx_byte <= rx_shift;
```

**Sau:**
```systemverilog
    // 4 bits: 0..8 are NINE distinct states. A 3-bit saturating counter cannot
    // tell "7 edges seen" from "8 edges seen", so a 7-bit transaction would be
    // committed as if it were a complete byte.
    logic [3:0] rx_count;
    ...
        if (rx_count == 4'd8)
            rx_byte <= rx_shift;
```

**Vì sao:** với bộ đếm 3 bit bão hoà, `rx_count == 3'd7` đúng **ngay từ sau sườn thứ 7**.
Nếu chủ nhả `cs_n` lúc đó, một giao dịch chỉ có 7 bit thật vẫn được chốt thành byte hoàn
chỉnh (bit MSB là dữ liệu cũ) — vi phạm yêu cầu Charter mục 8/10. Đây là **phương án 2**
của known_issues §6.3, được chọn vì nó loại bỏ hẳn sự mập mờ của giá trị bão hoà.

**Hệ quả:** +1 FF. Ca "nhả CS giữa chừng" của testbench (3 bit) vẫn PASS như trước, và giờ
một giao dịch 7 bit cũng bị từ chối đúng cách.

## 3. Kết quả xác minh sau khi vá

| Bước | Trước khi vá | Sau khi vá |
|---|---|---|
| Mô hình chuẩn Python | `H04 golden reference PASS` (mã thoát 0) | `H04 golden reference PASS` (mã thoát 0) — **không sửa** |
| Biên dịch | `iverilog` sạch (mã thoát 0) | `iverilog` sạch (mã thoát 0) |
| Mô phỏng | ❌ `FATAL: ... RX mismatch  Time: 85` | ✅ `H04 TB completed`, `$finish` tại 210, không có `ERROR`/`FATAL`/`mismatch` |
| Tổng hợp | 62 cell · 22 FF ánh xạ **+ 8 `$_ALDFFE_NPP_` KHÔNG ánh xạ được** · `Area for cell type $_ALDFFE_NPP_ is unknown!` · 710,6816 µm² (**số không đầy đủ**) | ✅ **61 cell · 23 FF · 813,2800 µm²** · 0 ERROR · không còn cell `$_` |
| Netlist đọc được bởi OpenSTA | ❌ có `reg miso;` + 8 khối `always` → `line 39, syntax error` | ✅ **0 dòng `reg`/`always`** — netlist thuần cấu trúc |

Chi tiết cell sau khi vá:

```
   Number of cells:                 61
     sky130_fd_sc_hd__a21o_1         1
     sky130_fd_sc_hd__a21oi_1        1
     sky130_fd_sc_hd__clkinv_1      15
     sky130_fd_sc_hd__dfrtn_1        3
     sky130_fd_sc_hd__dfrtp_1       12
     sky130_fd_sc_hd__dfxtp_1        8
     sky130_fd_sc_hd__lpflow_isobufsrc_1      1
     sky130_fd_sc_hd__mux2_1         9
     sky130_fd_sc_hd__mux4_2         2
     sky130_fd_sc_hd__nand2_1        2
     sky130_fd_sc_hd__nand3_1        2
     sky130_fd_sc_hd__nor2_1         1
     sky130_fd_sc_hd__nor4b_1        1
     sky130_fd_sc_hd__xnor2_1        2
     sky130_fd_sc_hd__xor2_1         1

   Chip area for module '\h04_spi_slave': 813.280000
```

FF = `dfrtn_1` (3) + `dfrtp_1` (12) + `dfxtp_1` (8) = **23 FF**.

Diện tích **tăng** 710,68 → 813,28 µm² là hợp lý và phải giải thích được: số cũ **không
tính** 8 `$_ALDFFE_NPP_` (Yosys in thẳng `Area ... is unknown!`), nên nó không phải diện
tích của một mạch hoàn chỉnh. Số mới là số đầu tiên đo được trên một netlist đã ánh xạ hết.

Lệnh đã chạy để xác minh:

```bash
D=<thu muc de H04>
LIB=<.../sky130hd.lib>
T=$(mktemp -d)

# (a) mo hinh chuan Python
python3 $D/05_VERIFICATION/golden_model/reference_model.py

# (b) bien dich + mo phong
iverilog -g2012 -o $T/sim.vvp \
   $D/04_IMPLEMENTATION/rtl/*.sv \
   $D/05_VERIFICATION/testbench/*.sv
cd $T && vvp sim.vvp | tail -20

# (c) tong hop
yosys -Q -p "read_verilog -sv $D/04_IMPLEMENTATION/rtl/*.sv; \
   hierarchy -check -top h04_spi_slave; proc; opt; fsm; opt; memory; opt; techmap; opt; \
   dfflibmap -liberty $LIB; abc -liberty $LIB; setundef -zero; splitnets; opt_clean -purge; \
   stat -liberty $LIB"

# (d) kiem netlist thuan cau truc (dieu kien de OpenSTA doc duoc)
yosys -Q -p "...; write_verilog -noattr $T/netlist.v"
grep -cE '^\s*(reg |always)' $T/netlist.v     # => 0
```

Lưu ý: `05_VERIFICATION/golden_model/` của đề này **không có file `.sv`**, nên lệnh (b)
chỉ nhận `rtl/*.sv` và `testbench/*.sv`.

## 4. Cách quay lui

```bash
cp 08_ORIGINAL_SOURCE/rtl/*            04_IMPLEMENTATION/rtl/
cp 08_ORIGINAL_SOURCE/golden_model/*   05_VERIFICATION/golden_model/
cp 08_ORIGINAL_SOURCE/testbench/*      05_VERIFICATION/testbench/
```

## 5. Việc còn lại

1. **`design.sdc` thiếu clock `cs_n`** (known_issues §4.3). Sau P-3, `cs_n` vẫn là clock
   của 8 FF `dfxtp_1` (khối chốt `rx_byte`). File `04_IMPLEMENTATION/constraints` nằm
   **ngoài ranh giới được sửa** của đợt vá này (SPEC §0) nên chưa động tới. Phải bổ sung
   trước khi đọc kết quả STA.
2. **Mô hình chuẩn Python chưa mô hình hoá trạng thái chưa khởi tạo** (known_issues §3.4).
   Đã **cố ý không sửa**: nó đang PASS, không chặn luồng nào, và việc viết lại nó thành mô
   hình có trạng thái là thay đổi lớn hơn phạm vi "sửa tối thiểu" của đợt vá này. Hệ quả
   phải nêu rõ khi bảo vệ: mô hình chuẩn hiện tại **không có khả năng** bắt lỗi loại X-lock.
3. **Chưa có ca kiểm thử 7 bit** để chứng minh P-4 trên chính testbench của hồ sơ. P-4 đã
   được kiểm bằng lập luận và bằng việc ca 3 bit hiện có vẫn PASS, nhưng một ca 7 bit
   tường minh sẽ mạnh hơn.
4. `05_VERIFICATION/testbench/properties.sv` vẫn nằm sau `` `ifdef H04_SVA `` và không
   được biên dịch trong luồng hiện tại — giữ nguyên.

## 6. Áp dụng lại (2026-09-24)

**Lý do:** một bước sinh tài liệu tự động (`generate2.py`) đã chép mã nguồn cũ từ
`runs/<mã>/work/` **đè lên** `04_IMPLEMENTATION/rtl/`, `05_VERIFICATION/golden_model/` và
`05_VERIFICATION/testbench/`, làm mất toàn bộ bản vá trong ba thư mục đó. Với H04 điều này
xoá **ba bản vá RTL** (P-2, P-3, P-4) — nghĩa là vòng khoá X, phép nạp bất đồng bộ giá trị
không phải hằng và lỗ hổng 7 bit đều **quay trở lại**. Lỗi của bộ sinh đã được sửa. Bản vá
được **áp dụng lại nguyên văn** theo §2 của chính tài liệu này.

**Đã áp dụng lại:** 4 / 4 bản vá, không có chênh lệch nào so với §2.

| # | File | Nội dung áp dụng lại |
|---|---|---|
| **P-1** | `05_VERIFICATION/testbench/h04_spi_slave_tb.sv` | Chuỗi khởi tạo `cs_n = 0; #1 cs_n = 1; #1;` ở đầu khối `initial` — tạo **sườn lên thật** |
| **P-2** | `04_IMPLEMENTATION/rtl/h04_spi_slave.sv` | `if (rx_count != 3'd7) rx_count <= rx_count + 1'b1;` → `rx_count <= (rx_count == 4'd8) ? 4'd8 : (rx_count + 1'b1);` — mọi nhánh đều **gán**, hết vòng khoá X |
| **P-3** | `04_IMPLEMENTATION/rtl/h04_spi_slave.sv` | Khối `always_ff @(negedge sclk or posedge cs_n)` rút gọn còn **mỗi `tx_count`**; `miso` thành `assign miso = MSB_FIRST ? tx_byte[3'd7 - tx_count] : tx_byte[tx_count];`; **xoá hẳn khai báo `tx_shift`** |
| **P-4** | `04_IMPLEMENTATION/rtl/h04_spi_slave.sv` | `logic [2:0] rx_count` → `logic [3:0] rx_count`; `if (rx_count == 3'd7)` → `if (rx_count == 4'd8)` |

**Kết quả xác minh lần này** (công cụ thật: Python 3, iverilog 12.0, Yosys 0.33 + sky130hd):

| Bước | Đo được lần này | Khớp §3? |
|---|---|:-:|
| Mô hình chuẩn Python | `H04 golden reference PASS`, mã thoát 0 | ✅ |
| Biên dịch | `iverilog` sạch, mã thoát 0 | ✅ |
| Mô phỏng | `H04 TB completed`, `$finish` tại **`t = 210`** — không `ERROR`/`FATAL`/`mismatch` | ✅ |
| Tổng hợp | **61 cell · 23 FF · 813,2800 µm² · 58 wire** · **0 ERROR** | ✅ |
| Cell `$_…` chưa ánh xạ | **0** — không còn `$_ALDFFE_NPP_` | ✅ |
| Cảnh báo `Async reset value … is not constant!` | **0 lần** | ✅ |
| `Area for cell type … is unknown!` | **0 lần** ⟹ diện tích 813,28 µm² là số **đầy đủ** | ✅ |
| **Netlist thuần cấu trúc** (`write_verilog -noattr` + `grep -cE '^\s*(reg \|always)'`) | **0 dòng `reg`/`always`** ⟹ **OpenSTA đọc được** | ✅ |

Bảng cell đo lại **trùng khít từng dòng** với §3:

```
   Number of cells:                 61
     sky130_fd_sc_hd__a21o_1         1
     sky130_fd_sc_hd__a21oi_1        1
     sky130_fd_sc_hd__clkinv_1      15
     sky130_fd_sc_hd__dfrtn_1        3
     sky130_fd_sc_hd__dfrtp_1       12
     sky130_fd_sc_hd__dfxtp_1        8
     sky130_fd_sc_hd__lpflow_isobufsrc_1      1
     sky130_fd_sc_hd__mux2_1         9
     sky130_fd_sc_hd__mux4_2         2
     sky130_fd_sc_hd__nand2_1        2
     sky130_fd_sc_hd__nand3_1        2
     sky130_fd_sc_hd__nor2_1         1
     sky130_fd_sc_hd__nor4b_1        1
     sky130_fd_sc_hd__xnor2_1        2
     sky130_fd_sc_hd__xor2_1         1

   Chip area for module '\h04_spi_slave': 813.280000
```

FF = `dfrtn_1` (3) + `dfrtp_1` (12) + `dfxtp_1` (8) = **23 FF** — khớp §3.

⟹ **Toàn bộ số liệu trùng khớp §3**, và điều kiện quan trọng nhất của P-3 được **đo lại và
xác nhận**: netlist **không còn một dòng `reg` hay `always` nào**, nên OpenSTA đọc được —
đúng thứ mà bản gốc làm hỏng ở `netlist.v line 39, syntax error`.

Các mục ở §5 (việc còn lại) **không đổi** — đặc biệt điểm 1: `design.sdc` vẫn **thiếu clock
`cs_n`**, mà sau P-3 `cs_n` vẫn là clock của 8 FF `dfxtp_1`. Phải bổ sung trước khi đọc kết
quả STA.
