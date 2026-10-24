# H04 · Phán xử lỗi đã biết (Known Issues)

> ## ✅ Trạng thái: **ĐÃ ÁP DỤNG** — 2026-09-24
>
> Giảng viên đã duyệt. Toàn bộ bản vá đề xuất trong tài liệu này **đã được đưa vào hồ sơ**.
> Nhật ký đầy đủ: [`08_ORIGINAL_SOURCE/PATCHLOG.md`](../08_ORIGINAL_SOURCE/PATCHLOG.md).
>
> | Bản vá | Lỗi | File | Trạng thái |
> |---|---|---|---|
> | P-1 | ISS-1 (kích hoạt) | `05_VERIFICATION/testbench/h04_spi_slave_tb.sv` | ✅ đã áp dụng (§3.1) |
> | P-2 | ISS-1 (gốc) | `04_IMPLEMENTATION/rtl/h04_spi_slave.sv` | ✅ đã áp dụng (§3.2, phương án 1) |
> | P-3 | ISS-2 | `04_IMPLEMENTATION/rtl/h04_spi_slave.sv` | ✅ đã áp dụng — **khác** §5 phương án A, xem ghi chú dưới |
> | P-4 | ISS-3 | `04_IMPLEMENTATION/rtl/h04_spi_slave.sv` | ✅ đã áp dụng (§6.3, phương án 2) |
>
> **Kết quả xác minh bằng công cụ thật (iverilog 12.0 · Yosys 0.33 · sky130hd):**
>
> | Bước | Trước khi vá | Sau khi vá |
> |---|---|---|
> | Mô hình chuẩn Python | PASS | PASS (không sửa) |
> | Biên dịch | sạch | sạch |
> | Mô phỏng | ❌ `FATAL: RX mismatch` tại `Time: 85` | ✅ `H04 TB completed` tại 210 |
> | Tổng hợp | 62 cell · 22 FF ánh xạ **+ 8 `$_ALDFFE_NPP_` không ánh xạ được** · 710,6816 µm² (số **không đầy đủ**) | ✅ **61 cell · 23 FF · 813,2800 µm²** |
> | Netlist cho OpenSTA | ❌ còn `reg`/`always` → `line 39, syntax error` | ✅ **0 dòng `reg`/`always`** — thuần cấu trúc |
>
> **Hai chênh lệch so với bản vá đã soạn — phải đọc:**
>
> 1. **§3.3 (thêm chân `rst_n`) KHÔNG được áp dụng.** Nó đổi giao diện module, trái
>    nguyên tắc "không đổi giao diện" của quy trình vá. Đã dùng §3.2 (khử vòng khoá X).
>    Hệ quả trung thực vẫn giữ nguyên như §3.2 đã ghi: bản vá **không tự khử X**.
> 2. **§5 phương án A đã được thử và BỊ BÁC BỎ.** Với phương án A, `tx_shift` chỉ nạp tại
>    sườn xuống `sclk` đầu tiên, nên `miso` xuất nội dung cũ trong khoảng từ lúc `cs_n`
>    xuống tới sườn đó — **sai đúng bit 7** tại sườn lấy mẫu số 1 của chế độ 0. Bản vá
>    thật dùng **bit-select theo `tx_count`** thay thanh ghi dịch. Đã kiểm bằng cách chạy
>    song song bản gốc và bản vá trong cùng một mô phỏng: `miso` **trùng khít** tại cả 8
>    sườn lấy mẫu (`1,0,0,1,0,1,1,0` = `0x96`), **0 điểm khác biệt**.
>
> Phần chẩn đoán bên dưới **giữ nguyên** làm tài liệu dạy học. Riêng §8 đã được cập nhật.

---


Hồ sơ H04 có **hai** lỗi độc lập. Chúng **không** cùng nguyên nhân và **không** sửa được
bằng cùng một bản vá.

| Mã | Tầng | Triệu chứng | Phán xử |
|---|---|---|---|
| **ISS-1** | Mô phỏng RTL | `RX mismatch` tại `t = 85` | **Lỗi TESTBENCH** (kích hoạt) + **lỗi DUT** (gốc: thiếu khởi tạo) |
| **ISS-2** | STA | `netlist.v line 39, syntax error` | **Lỗi DUT** (RTL sinh cấu trúc không ánh xạ được) — **không** phải lỗi công cụ |

Ngoài ra còn một lỗi **chưa lộ ra** vì chưa có ca kiểm thử:

| Mã | Tầng | Triệu chứng | Phán xử |
|---|---|---|---|
| **ISS-3** | Chức năng | Giao dịch 7 bit bị nhận nhầm thành byte hoàn chỉnh | **Lỗi DUT** — vi phạm yêu cầu trọng tâm Charter mục 8/10 |

---

## 1. Trích nguyên văn thông báo lỗi

### 1.1 Mô phỏng — `05_VERIFICATION/simulation.log`

```
FATAL: …/runs/H04/work/h04_spi_slave_tb.sv:34: RX mismatch
       Time: 85  Scope: h04_spi_slave_tb
```

### 1.2 Biên dịch — `05_VERIFICATION/iverilog_compile.log`

```
(file rỗng — KHÔNG có lỗi biên dịch)
```

👉 Đây là dữ kiện quan trọng: mã **biên dịch sạch**. Không phải lỗi cú pháp, không phải
Icarus Verilog không hiểu SystemVerilog.

### 1.3 STA — `06_GDSII/sta/sta.log`

```
Error: 171 …/runs/H04/netlist.v line 39, syntax error
```

### 1.4 Mô hình chuẩn — `05_VERIFICATION/python_reference_run.log`

```
H04 golden reference PASS
```

👉 Mô hình chuẩn PASS. Nên **không** thể đổ lỗi cho mô hình chuẩn ở tầng "chạy được hay
không" — nhưng vẫn phải xét xem nó có mô hình hoá **đúng** thứ cần kiểm không (xem §3.4).

---

## 2. ISS-1 — Phán xử lỗi mô phỏng

### 2.1 Bằng chứng phân biệt

Chạy lại testbench nguyên bản có thêm `$monitor` cho `dut.rx_count` và `dut.rx_shift`
(chỉ thêm quan sát, **không sửa DUT**). Kết quả:

```
t=0   cs_n=1 sclk=0  rx_count=xxx  rx_shift=xx  rx_byte=xx
t=2   cs_n=0 sclk=0  rx_count=xxx  rx_shift=xx  rx_byte=xx
t=8   cs_n=0 sclk=1  rx_count=xxx  rx_shift=xX  rx_byte=xx    ← sườn lên #1
t=38  cs_n=0 sclk=1  rx_count=xxx  rx_shift=x3  rx_byte=xx    ← #4
t=68  cs_n=0 sclk=1  rx_count=xxx  rx_shift=Xe  rx_byte=xx    ← #7
t=78  cs_n=0 sclk=1  rx_count=xxx  rx_shift=3c  rx_byte=xx    ← #8: rx_shift ĐÃ ĐÚNG
t=84  cs_n=1 sclk=0  rx_count=000  rx_shift=00  rx_byte=xx    ← ↑cs_n: KHÔNG chốt
RX mismatch rx_byte=xx
…
t=207 cs_n=1 sclk=0  rx_count=000  rx_shift=00  rx_byte=a5    ← giao dịch thứ 3: ĐÚNG
```

**Ba dữ kiện quyết định:**

1. Tại `t = 78`, `rx_shift = 3c` — **đường nhận hoàn toàn đúng**. Dữ liệu đã vào đủ.
2. Trong suốt giao dịch đầu, `rx_count` **kẹt ở `3'bxxx`**, không hề đếm.
3. Giao dịch thứ ba (`0xA5`) **PASS** — `rx_byte = a5` tại `t = 207`.

Nếu lỗi nằm ở thuật toán dịch bit hay ở thứ tự MSB/LSB thì giao dịch thứ ba cũng phải sai.
Nó đúng ⇒ **thuật toán đúng, chỉ trạng thái ban đầu sai**.

### 2.2 Lập luận từ mã — vì sao `rx_count` kẹt ở X

Testbench dòng 2:

```systemverilog
logic sclk=0, mosi=0, cs_n=1;
```

Theo IEEE 1800, giá trị khởi tạo trong khai báo biến static được gán **tại thời điểm 0,
trước khi mọi `initial`/`always` bắt đầu chạy**. Vì vậy `cs_n` **không có chuyển mức**
từ `x` sang `1` mà bất kỳ `always_ff` nào quan sát được ⇒ **không có sườn `posedge cs_n`**.
Icarus Verilog thực hiện đúng quy tắc này (xác nhận bằng trace ở §2.1: `rx_count` vẫn `xxx`
tại `t = 0`).

RTL `h04_spi_slave.sv` dòng 21–33:

```systemverilog
always_ff @(posedge sclk or posedge cs_n) begin
    if (cs_n) begin
        rx_shift <= '0;
        rx_count <= '0;          // ← nhánh này KHÔNG BAO GIỜ chạy trong giao dịch đầu
    end else begin
        ...
        if (rx_count != 3'd7)    // ← 3'bxxx != 3'd7  ⇒  kết quả 1'bx
            rx_count <= rx_count + 1'b1;   // ⇒ if KHÔNG thực hiện ⇒ rx_count giữ nguyên x
    end
end
```

Đây là **vòng khoá X (X-lock)**: điều kiện để thoát X lại phụ thuộc chính giá trị đang X.

Rồi dòng 61–64:

```systemverilog
always_ff @(posedge cs_n) begin
    if (rx_count == 3'd7)        // 3'bxxx == 3'd7  ⇒  1'bx  ⇒  if không thực hiện
        rx_byte <= rx_shift;     // ⇒ rx_byte giữ nguyên 8'bxxxxxxxx
end
```

⇒ `rx_byte` không bao giờ được gán ⇒ `assert(rx_byte == 8'h3C)` thất bại tại `t = 85`. ∎

### 2.3 Vì sao `rx_shift` **tự sạch** còn `rx_count` thì không

| | `rx_shift` | `rx_count` |
|---|---|---|
| Cấu trúc | `{rx_shift[6:0], mosi}` — X bị **đẩy ra ngoài** | `rx_count + 1` — X **hồi tiếp vào chính nó** |
| Có điều kiện chặn không? | Không — luôn gán | **Có** — `if (rx_count != 3'd7)`, mà điều kiện này = X |
| Sau 8 lần dịch | ✅ sạch (`t = 78`: `3c`) | ❌ vẫn `xxx` |

> 🔎 **Quy tắc rút ra:** thanh ghi dịch có thể tự khử X sau N lần dịch; **bộ đếm thì không
> bao giờ** — vì nó hồi tiếp. Mọi bộ đếm **bắt buộc** phải có đường khởi tạo xác định.

### 2.4 Lỗi nằm ở đâu? — phán xử

| Ứng viên | Có lỗi không? | Lập luận |
|---|---|---|
| **DUT** (`h04_spi_slave.sv`) | ✅ **CÓ — lỗi gốc** | Khối không có cổng reset, và **không có bất kỳ con đường nào** để đưa `rx_count` về giá trị xác định nếu tầng ngoài không tạo sườn `↑cs_n`. Một khối phần cứng không được phép phụ thuộc vào "hy vọng có ai đó tạo sườn". Ngoài ra, ngay cả khi có sườn, `if (rx_count != 3'd7)` vẫn là một **vòng khoá X** — đây là lỗi mã hoá thực sự. |
| **Testbench** (`h04_spi_slave_tb.sv`) | ✅ **CÓ — lỗi kích hoạt** | Khởi tạo `cs_n=1` bằng khai báo, không tạo sườn. Một testbench cho mạch tuần tự **phải** có chuỗi khởi tạo tường minh. |
| **Mô hình chuẩn** (`reference_model.py`) | ⚠️ **Không sai, nhưng vô dụng cho lỗi này** | Nó chỉ thao tác trên danh sách bit Python; **không** mô hình hoá sườn, `cs_n`, hay bộ đếm. `test_abort()` chỉ khẳng định `len(received) != 8`. Không có gì trong mô hình có thể phát hiện X-lock. |
| **Công cụ** (Icarus Verilog) | ❌ **KHÔNG** | Icarus thực hiện đúng IEEE 1800 về thời điểm khởi tạo biến và đúng ngữ nghĩa 4 trạng thái của `if`. `iverilog_compile.log` rỗng. **Không có lý do nào để đổ lỗi cho công cụ.** |

**Kết luận ISS-1:** lỗi **kép**. Testbench là nguyên nhân **kích hoạt**; RTL là nguyên nhân
**gốc**. Sửa testbench sẽ làm mô phỏng PASS nhưng **không** làm mạch an toàn — trên silicon
thật, không ai bảo đảm có sườn `cs_n` trước giao dịch đầu.

---

## 3. ISS-1 — Bản vá tối thiểu

### 3.1 Vá testbench (làm mô phỏng chạy được ngay — **không** sửa được lỗi gốc)

```diff
--- a/05_VERIFICATION/testbench/h04_spi_slave_tb.sv
+++ b/05_VERIFICATION/testbench/h04_spi_slave_tb.sv
@@
     initial begin
+        // Chuỗi khởi tạo nguồn: tạo SƯỜN LÊN THẬT của cs_n.
+        // Khởi tạo trong khai báo (logic cs_n=1) KHÔNG sinh sườn theo IEEE 1800,
+        // nên hai khối always_ff không bao giờ chạy nhánh reset.
+        cs_n = 1'b0;
+        #1 cs_n = 1'b1;
+        #1;
         // Complete transaction.
         #2 cs_n=0;
```

Đã kiểm: với bản vá này (và **giữ nguyên DUT**), `rx_byte = 8'h3c` tại `t = 85`,
`miso` phát ra đúng dãy `1,0,0,1,0,1,1,0` = `0x96`, và cả ba giao dịch đều PASS.

### 3.2 Vá RTL — phương án 1: khử vòng khoá X (ít xâm lấn nhất)

```diff
--- a/04_IMPLEMENTATION/rtl/h04_spi_slave.sv
+++ b/04_IMPLEMENTATION/rtl/h04_spi_slave.sv
@@
-            if (rx_count != 3'd7)
-                rx_count <= rx_count + 1'b1;
+            // Dùng dạng "bão hoà không khoá": mọi nhánh đều GÁN, kể cả khi
+            // rx_count đang là X thì phép cộng vẫn cho X — nhưng không còn
+            // điều kiện X nào chặn việc gán, nên trạng thái không tự khoá.
+            rx_count <= (rx_count == 3'd7) ? 3'd7 : (rx_count + 1'b1);
```

Lưu ý trung thực: bản vá này **không** tự khử X (X + 1 vẫn là X). Nó chỉ bỏ vòng khoá, để
một sườn `↑cs_n` bất kỳ sau đó khôi phục được trạng thái. **Nó không thay thế được reset.**

### 3.3 Vá RTL — phương án 2: thêm cổng reset thật (đúng bản chất)

```diff
 module h04_spi_slave #(
     parameter bit MSB_FIRST = 1'b1
 ) (
+    input  logic       rst_n,     // reset nguồn, tích cực thấp
     input  logic       sclk,
@@
-    always_ff @(posedge sclk or posedge cs_n) begin
-        if (cs_n) begin
+    always_ff @(posedge sclk or posedge cs_n or negedge rst_n) begin
+        if (!rst_n || cs_n) begin
             rx_shift <= '0;
             rx_count <= '0;
```

Chi phí: **+1 chân**. Ngân sách chân hiện tại là 20/24 (`02_SPECIFICATION/interface.md` §3),
còn dư 4 chân ⇒ **khả thi**. Đây là phương án đúng nhất về kỹ thuật.

### 3.4 Vá mô hình chuẩn (để nó có khả năng bắt lỗi loại này)

Mô hình Python hiện tại không có khái niệm trạng thái. Đề xuất thêm một lớp mô phỏng sườn:

```python
class SpiSlaveModel:
    def __init__(self):
        self.rx_count = None      # None = chưa khởi tạo, tương đương X
        self.rx_shift = None
        self.rx_byte  = None
    def cs_rise(self):
        if self.rx_count == 7:    # None == 7 -> False, giống if(X) không thực hiện
            self.rx_byte = self.rx_shift
        self.rx_count, self.rx_shift = 0, 0
    def sclk_rise(self, mosi, cs_n):
        if cs_n: return
        if self.rx_shift is None or self.rx_count is None:
            raise RuntimeError("Trang thai chua khoi tao — can suon ↑cs_n truoc")
        ...
```

Điểm mấu chốt: mô hình chuẩn phải mô hình hoá **trạng thái chưa khởi tạo**, nếu không nó
sẽ luôn PASS với mọi lỗi thuộc loại này.

---

## 4. ISS-2 — Phán xử lỗi STA

### 4.1 Dòng 39 của netlist là gì?

```
netlist.v:36    input cs_n;
netlist.v:37    wire cs_n;
netlist.v:38    output miso;
netlist.v:39    reg miso;          ← ĐÂY
netlist.v:40    input mosi;
…
netlist.v:62    reg \tx_shift[0] ;
…
netlist.v:68    reg \tx_shift[6] ;
…
netlist.v:267   always @(negedge sclk, posedge cs_n)
netlist.v:268     if (cs_n) miso <= tx_byte[7];
netlist.v:269     else if (_28_) miso <= \tx_shift[6] ;
```

Bộ đọc Verilog của OpenSTA chỉ chấp nhận **netlist cấu trúc**: `module`, `input`, `output`,
`inout`, `wire`, `supply0/1`, và các instance cell. Nó **không** hiểu `reg`, và **không**
hiểu `always`. Gặp `reg miso;` ở dòng 39 nó dừng ngay với `syntax error`.

### 4.2 Vì sao netlist lại có `reg` và `always`?

Chuỗi nhân quả, đọc ngược từ hậu quả về nguyên nhân:

```
 sta.log: "line 39, syntax error"
   ▲
   │ vì netlist.v có `reg miso;` và 8 khối `always`
   ▲
   │ vì write_verilog phải xuất $_ALDFFE_NPP_ dưới dạng hành vi
   ▲
   │ vì dfflibmap KHÔNG tìm được cell sky130 nào tương đương
   ▲
   │ vì $_ALDFFE_NPP_ = FF có NẠP BẤT ĐỒNG BỘ một giá trị KHÔNG PHẢI HẰNG
   ▲
   │ vì yosys.log dòng 61, 64:
   │     Warning: Async reset value `\tx_byte [7]' is not constant!
   │     Warning: Async reset value `\tx_byte' is not constant!
   ▲
   │ vì RTL dòng 38–41:
   │     if (cs_n) begin
   │         tx_shift <= tx_byte;                       ← NẠP giá trị biến thiên
   │         miso     <= MSB_FIRST ? tx_byte[7] : …;    ← tại sườn BẤT ĐỒNG BỘ
   │     end
   ▼
 NGUỒN GỐC: RTL yêu cầu một hành vi mà THƯ VIỆN CHUẨN KHÔNG CÓ.
```

Bằng chứng số: `synth_stat.txt` ghi

```
     $_ALDFFE_NPP_                   8
   Area for cell type $_ALDFFE_NPP_ is unknown!
```

### 4.3 Phán xử

| Ứng viên | Có lỗi không? | Lập luận |
|---|---|---|
| **DUT** (RTL) | ✅ **CÓ — nguyên nhân gốc** | Yêu cầu "nạp bất đồng bộ một giá trị không phải hằng". Flip-flop CMOS chuẩn có `SET`/`RESET` (về hằng 1 hoặc 0), **không có** "asynchronous load". Đây là một yêu cầu **không tổng hợp được** trên thư viện chuẩn. |
| **Công cụ** (OpenSTA) | ❌ **KHÔNG** | OpenSTA là bộ phân tích **gate-level**; từ chối netlist chứa mã hành vi là đúng chức năng, không phải thiếu sót. |
| **Công cụ** (Yosys) | ⚠️ **Không sai, nhưng đã cảnh báo mà flow bỏ qua** | Yosys đã cảnh báo rõ hai lần và đã in `Area … is unknown!`. Script `synth.ys` **không có** bước kiểm tra "netlist đã ánh xạ hết chưa" (ví dụ `check -assert` hoặc `stat` có kiểm `$_`). Đây là khoảng trống trong **flow**, không phải lỗi công cụ. |
| **Testbench / mô hình chuẩn** | ❌ không liên quan | Lỗi xảy ra sau tổng hợp. |
| **SDC** (`design.sdc`) | ⚠️ **Có thiếu sót riêng** — nhưng **không** gây ra lỗi này | SDC chỉ khai báo clock `sclk`, thiếu clock `cs_n` (8 FF `dfxtp_1` dùng `.CLK(cs_n)`). Lỗi này chỉ lộ ra **sau khi** ISS-2 được sửa. |

**Kết luận ISS-2:** **lỗi trong DUT**, không phải giới hạn công cụ. Bằng chứng mạnh nhất:
Yosys đã nói thẳng `Async reset value is not constant!` trước khi bất kỳ lỗi nào xảy ra.

---

## 5. ISS-2 — Bản vá tối thiểu

Nguyên tắc: **giữ nguyên chức năng** (`tx_shift` phải chứa `tx_byte` khi `cs_n` lên), nhưng
diễn đạt bằng cấu trúc mà thư viện có.

### Phương án A — nạp **đồng bộ** với sườn xuống đầu tiên (ít cell nhất)

```diff
--- a/04_IMPLEMENTATION/rtl/h04_spi_slave.sv
+++ b/04_IMPLEMENTATION/rtl/h04_spi_slave.sv
@@
     always_ff @(negedge sclk or posedge cs_n) begin
         if (cs_n) begin
-            tx_shift <= tx_byte;
             tx_count <= 3'd0;
-            miso     <= MSB_FIRST ? tx_byte[7] : tx_byte[0];
+            tx_loaded <= 1'b0;          // cờ 1 bit, reset về HẰNG SỐ  ⇒ ánh xạ được
         end else begin
-            if (tx_count != 3'd7) begin
+            if (!tx_loaded) begin
+                tx_shift  <= MSB_FIRST ? {tx_byte[6:0],1'b0} : {1'b0,tx_byte[7:1]};
+                tx_loaded <= 1'b1;
+                tx_count  <= 3'd0;
+            end else if (tx_count != 3'd7) begin
                 tx_count <= tx_count + 1'b1;
```

và `miso` trở thành **tổ hợp có chọn**:

```systemverilog
assign miso = cs_n ? (MSB_FIRST ? tx_byte[7] : tx_byte[0])
                   : (MSB_FIRST ? tx_shift[7] : tx_shift[0]);
```

| Được | Mất |
|---|---|
| Không còn `$_ALDFFE_NPP_` ⇒ netlist thuần cấu trúc ⇒ **STA chạy được** | `miso` thành tổ hợp ⇒ có thể có glitch; phải kiểm lại bằng mô phỏng gate-level |
| `tx_shift` dùng `dfrtp_1`/`dfrtn_1` thật, có diện tích xác định | +1 FF (`tx_loaded`) |
| Yosys hết cảnh báo | Hành vi ở **nửa chu kỳ đầu tiên** thay đổi — **phải kiểm lại bằng TC-4** |

### Phương án B — giữ `miso` là thanh ghi, chuyển việc nạp sang sườn xuống

Giữ nguyên cấu trúc thanh ghi cho `miso`, chỉ đổi thời điểm nạp `tx_shift` từ `↑cs_n`
sang **sườn xuống `sclk` đầu tiên sau khi `cs_n` xuống**. Chi phí giống phương án A
(+1 FF cờ), nhưng `miso` vẫn sạch. Đổi lại: bit đầu tiên xuất hiện trên `miso` **muộn hơn
nửa chu kỳ**, có thể không đúng chế độ 0 nghiêm ngặt nếu chủ lấy mẫu ngay tại sườn lên #1.

👉 **Khuyến nghị:** thử phương án A trước, kiểm bằng TC-4 (`corner_cases.md` §3), rồi so
`synth_stat.txt` mới với `synth_stat.txt` hiện tại để biết chi phí thật.

---

## 6. ISS-3 — Lỗ hổng 7 bit (chưa lộ ra vì thiếu ca kiểm thử)

### 6.1 Bằng chứng từ mô phỏng thật

Trong lần chạy testbench nguyên bản, giao dịch thứ ba (`0xA5`, đủ 8 bit) cho:

```
t=191  ↑sclk #7   rx_count=111  rx_shift=52     ← rx_count ĐÃ BẰNG 7 sau 7 sườn
t=201  ↑sclk #8   rx_count=111  rx_shift=a5     ← sườn thứ 8: bão hoà, không đổi
```

Nghĩa là điều kiện `rx_count == 3'd7` ở dòng 62 **đúng từ sau sườn thứ 7**.
Nếu chủ nhả `cs_n` ngay lúc đó, `rx_byte` sẽ nhận `0x52` — một byte chỉ có 7 bit thật,
bit MSB là dữ liệu cũ. **Đây chính là kịch bản "CS nhả giữa chừng" mà Charter mục 10 gọi
là chỗ hay tắc**, và nó **chưa** được testbench kiểm (ca hiện có chỉ dùng 3 bit).

### 6.2 Phán xử

**Lỗi trong DUT.** Bộ đếm 3 bit không đủ để phân biệt 9 trạng thái (0…8). Lỗi thiết kế,
không phải lỗi công cụ hay testbench — dù testbench có lỗi phụ là **thiếu ca**.

### 6.3 Bản vá tối thiểu — hai phương án

**Phương án 1 — thêm cờ `rx_full` (1 FF):**

```diff
     logic [2:0] rx_count;
+    logic       rx_full;
@@
         if (cs_n) begin
             rx_shift <= '0;
             rx_count <= '0;
+            rx_full  <= 1'b0;
         end else begin
@@
-            if (rx_count != 3'd7)
-                rx_count <= rx_count + 1'b1;
+            if (rx_count != 3'd7)
+                rx_count <= rx_count + 1'b1;
+            else
+                rx_full  <= 1'b1;      // chỉ đặt ở SƯỜN THỨ 8 trở đi
         end
@@
     always_ff @(posedge cs_n) begin
-        if (rx_count == 3'd7)
+        if (rx_full)
             rx_byte <= rx_shift;
     end
```

**Phương án 2 — mở rộng bộ đếm lên 4 bit:**

```diff
-    logic [2:0] rx_count;
+    logic [3:0] rx_count;
@@
-            if (rx_count != 3'd7)
+            if (rx_count != 4'd8)
                 rx_count <= rx_count + 1'b1;
@@
-        if (rx_count == 3'd7)
+        if (rx_count == 4'd8)
             rx_byte <= rx_shift;
```

| | Phương án 1 | Phương án 2 |
|---|---|---|
| FF thêm | +1 | +1 |
| Logic thêm | ~1 cổng | Bộ so sánh 4 bit thay vì 3 bit (~+1 cổng) |
| Đọc mã có rõ ràng không? | ✅ rất rõ: "đủ byte" là một khái niệm riêng | ✅ rõ: đếm tới 8 thật |
| Tương thích ngược | ✅ | ✅ |

Cả hai đều chấp nhận được. **Phương án 2 dễ chứng minh đúng hơn** vì nó loại bỏ hẳn sự
mập mờ của giá trị bão hoà.

---

## 7. Giá trị dạy học của ba lỗi này

| Lỗi | Vì sao đáng dạy |
|---|---|
| **ISS-1** | Bẫy kinh điển nhất của mô phỏng SystemVerilog: **khởi tạo trong khai báo không sinh sự kiện sườn**. Kèm theo là khái niệm **X-lock** — điều kiện để thoát X lại phụ thuộc giá trị đang X. Và bài học phân biệt: thanh ghi dịch tự khử X, bộ đếm thì không. Ba khái niệm trong một lỗi 2 dòng. |
| **ISS-2** | Dạy ranh giới giữa **mô tả được** và **tổng hợp được**. `tx_shift <= tx_byte` tại `posedge cs_n` chạy hoàn hảo trong mô phỏng nhưng **không tồn tại trong silicon**. Dạy luôn thói quen **đọc cảnh báo của Yosys** — cảnh báo đã có ở dòng 61 của log, trước khi bất cứ thứ gì hỏng. |
| **ISS-3** | Dạy rằng **bộ đếm bão hoà luôn làm giá trị lớn nhất trở nên mập mờ**, và rằng "mô phỏng PASS" không đồng nghĩa với "đúng" khi ca kiểm thử không chạm vào lỗ hổng. Ca thứ ba của testbench PASS trong khi lỗi vẫn nguyên vẹn. |

**Bài học chung, đáng nhắc khi bảo vệ:** trong hồ sơ này, cả **mô hình chuẩn Python** lẫn
**tổng hợp Yosys** đều báo PASS, mà mạch vẫn có ba vấn đề. PASS của một công cụ chỉ chứng
minh đúng **phạm vi mà công cụ đó kiểm**, không hơn.

---

## 8. Trạng thái các bản vá

> ✅ **CẬP NHẬT 2026-09-24 — bản vá ĐÃ ĐƯỢC ÁP DỤNG.** Xem khối trạng thái ở **đầu tài
> liệu** và `08_ORIGINAL_SOURCE/PATCHLOG.md`. Đoạn dưới đây giữ lại để thấy hồ sơ đã ở
> trạng thái nào **trước** khi vá.
>
> - `04_IMPLEMENTATION/rtl/h04_spi_slave.sv` — ~~giữ nguyên bản gốc (66 dòng)~~ →
>   **đã vá** (P-2, P-3, P-4). Bản gốc nằm nguyên vẹn ở `08_ORIGINAL_SOURCE/rtl/`.
> - `05_VERIFICATION/testbench/h04_spi_slave_tb.sv` — ~~giữ nguyên bản gốc (51 dòng)~~ →
>   **đã vá** (P-1). Bản gốc ở `08_ORIGINAL_SOURCE/testbench/`.
> - `05_VERIFICATION/golden_model/reference_model.py` — **vẫn giữ nguyên bản gốc** (67
>   dòng). Cố ý không sửa; xem PATCHLOG §5 mục 2.
> - Kết quả trong `06_GDSII/` **vẫn là kết quả của mã gốc** cho tới khi luồng được chạy
>   lại — không được trích dẫn như số liệu của mạch đã vá.
>
> Các đoạn diff ở §3, §5, §6 ~~là **đề xuất**~~ → **đã được duyệt và áp dụng**, với hai
> chênh lệch đã ghi rõ ở khối trạng thái đầu tài liệu (§3.3 không áp dụng; §5 phương án A
> bị bác bỏ). Còn phải chạy lại theo thứ tự:
> `01_run_sim.sh` → `02_run_synth.sh` (đã kiểm: `stat` **không còn dòng `$_`**) →
> `03_run_sta.tcl` (**sau khi** bổ sung clock `cs_n` vào `design.sdc` — việc này vẫn còn
> treo, xem PATCHLOG §5 mục 1).

---

*Phiên bản: v1.0 · Ngày: 2026-09-24*
