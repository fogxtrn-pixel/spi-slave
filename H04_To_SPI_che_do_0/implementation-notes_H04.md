# H04 — Tớ SPI chế độ 0 · Ghi chú thực hiện

## 1. Bài toán này thực chất là gì

Bề ngoài, H04 là "một thanh ghi dịch 8 bit". Thực chất nó là bài toán **làm việc với một
xung nhịp mà mình không kiểm soát**. Phía chủ (vi điều khiển) sinh `sclk` và `cs_n`; phía
tớ chỉ phản ứng. Mọi khó khăn của đề đều sinh ra từ đó: không có reset hệ thống, không có
khái niệm "chu kỳ thứ n", không biết khi nào giao dịch kết thúc cho tới lúc `cs_n` lên.

Trong bối cảnh Charter mục 1 — "vi mạch phụ trợ nhận lệnh và trả số liệu" — H04 là **cửa
duy nhất** vào con chip. Nếu nó giao ra một byte rác, toàn bộ bộ giải lệnh phía sau sẽ thực
thi một lệnh không ai gửi. Vì vậy yêu cầu trọng tâm của đề **không phải** "dịch cho đúng",
mà là **"từ chối giao byte chưa hoàn chỉnh"**. Charter mục 10 nói thẳng điều này.

## 2. Bản chất kỹ thuật — cơ chế hoạt động

Chế độ 0 của SPI (`CPOL=0, CPHA=0`) quy định: **lấy mẫu ở sườn lên, đổi dữ liệu ở sườn
xuống**. Lý do vật lý rất đơn giản và đáng giải thích kỹ: nếu cả hai phía đều đổi và đều
lấy mẫu tại cùng một sườn, dữ liệu sẽ không có thời gian ổn định trên đường dây. Tách ra
hai sườn khác nhau tạo ra **nửa chu kỳ `sclk` làm biên an toàn** cho setup và hold. Đây là
lý do RTL phải có **hai** khối `always_ff` riêng, không phải một.

Nhưng cơ chế thú vị nhất của H04 nằm ở `cs_n`. Một dây duy nhất làm **ba việc khác nhau**:

- Mức `cs_n = 1` là **reset bất đồng bộ** cho `rx_shift`, `rx_count` (dòng 22–24).
- Mức `cs_n = 1` cũng là lệnh **nạp** `tx_shift ← tx_byte` (dòng 38–41).
- Sườn `↑cs_n` là **clock** của 8 flip-flop `rx_byte` (dòng 61).

Chính việc thứ hai là nguồn gốc của hỏng STA. Một flip-flop CMOS chuẩn có chân `SET` (về
hằng 1) hoặc `RESET` (về hằng 0). Nó **không có** chân "nạp giá trị tuỳ ý bất đồng bộ".
Yêu cầu `tx_shift <= tx_byte` tại một sườn bất đồng bộ là yêu cầu một linh kiện không tồn
tại trong `sky130_fd_sc_hd`. Yosys đã nói rõ ngay lần đầu:
`Warning: Async reset value '\tx_byte' is not constant!` (`yosys.log` dòng 64).

Còn nút thắt hiệu năng thì sao? Ở A01 (ripple-carry), nút thắt là chuỗi carry 8 tầng tổ hợp.
Ở H04 **hoàn toàn không có chuỗi tổ hợp dài**: `netlist.v` cho thấy
`.D(\rx_shift[6] )` nối **thẳng** vào FF kế tiếp, độ sâu 0 cổng. Chuỗi dài nhất chỉ 3 cổng,
nằm trong vòng hồi tiếp bộ đếm (`nand3 _34_ → xnor2 _35_ → nand2 _36_`). Nút thắt thật của
H04 là **băng thông giao thức** (8 sườn cho 8 bit, không rút ngắn được) và **chất lượng
sườn `sclk` đến từ bên ngoài** — không phải logic bên trong.

## 3. Đọc mã nguồn: RTL làm gì, từng dòng quan trọng

Ba đoạn quyết định toàn bộ số phận của thiết kế này.

**Đoạn 1 — đường nhận (dòng 21–33):**

```systemverilog
always_ff @(posedge sclk or posedge cs_n) begin
    if (cs_n) begin
        rx_shift <= '0;
        rx_count <= '0;
    end else begin
        if (MSB_FIRST)
            rx_shift <= {rx_shift[6:0], mosi};
        if (rx_count != 3'd7)
            rx_count <= rx_count + 1'b1;
    end
end
```

Dòng `if (rx_count != 3'd7)` là dòng nguy hiểm nhất trong file. Nó làm **hai** việc sai
cùng lúc. Thứ nhất, nó biến bộ đếm thành **vòng khoá X**: nếu `rx_count` đang là `3'bxxx`,
điều kiện cho kết quả `x`, `if` không thực hiện, `rx_count` giữ nguyên `x` — vĩnh viễn.
Thứ hai, nó làm `rx_count` đạt giá trị 7 sau **sườn thứ 7**, rồi bão hoà ở đó — nên
`rx_count == 3'd7` **không** có nghĩa "đã đủ 8 bit".

**Đoạn 2 — nạp bất đồng bộ (dòng 38–41):**

```systemverilog
if (cs_n) begin
    tx_shift <= tx_byte;
    tx_count <= 3'd0;
    miso     <= MSB_FIRST ? tx_byte[7] : tx_byte[0];
end
```

`tx_count <= 3'd0` là hằng — ánh xạ được thành `dfrtn_1`. `tx_shift <= tx_byte` **không phải
hằng** — sinh `$_ALDFFE_NPP_`. Cùng một khối, cùng một sườn, mà một dòng thì tổng hợp được
còn dòng kia thì không. Đây là điểm dạy học rất trực quan.

**Đoạn 3 — chính sách chốt (dòng 61–64):**

```systemverilog
always_ff @(posedge cs_n) begin
    if (rx_count == 3'd7)
        rx_byte <= rx_shift;
end
```

Đây là toàn bộ "trí tuệ" của đề nằm trong 3 dòng — và cũng là 3 dòng chứa lỗ hổng 7 bit.

## 4. Vì sao chọn kiến trúc này

Kiến trúc "hai thanh ghi dịch độc lập + hai bộ đếm + một thanh ghi chốt" được chọn vì nó
**tách sạch hai miền sườn**. Không có tín hiệu nào đi từ miền `↑sclk` sang miền `↓sclk`.
Cái giá là +3 FF cho bộ đếm thứ hai và +5 cổng cho bộ tăng thứ hai (`netlist.v` `_38_`…`_42_`
là bản sao chính xác của `_33_`…`_37_`). Đổi lại, không có đường liên miền nội bộ nào —
một đổi chác hợp lý cho một khối nhỏ.

Thanh ghi chốt `rx_byte` tốn **16 cell** (8 `dfxtp_1` + 8 `mux2_1`) = **25,8 % của 62 cell**.
Đó là cái giá trực tiếp của yêu cầu "chỉ giao byte trọn vẹn". Người đọc báo cáo phải thấy
con số này, vì nó chứng minh yêu cầu trọng tâm của đề được đầu tư thật, không phải nói suông.

Chi tiết dễ bỏ sót: `miso` có FF riêng, lấy dữ liệu từ `tx_shift[6]` chứ không phải
`tx_shift[7]`. Hệ quả: `tx_shift[7]` **không ai đọc** và bị tối ưu mất hoàn toàn — netlist
chỉ có 7 `$_ALDFFE_NPP_` cho `tx_shift` cộng 1 cho `miso`.

## 5. Cách thực hiện — lộ trình 8 bước từ đặc tả tới GDSII

| Bước | Việc | Trạng thái H04 | Bằng chứng |
|---|---|---|---|
| 1 | Chốt quy ước chế độ 0, thứ tự bit, chính sách chốt | ✅ | `02_SPECIFICATION/functional_spec.md` |
| 2 | Viết invariants INV-1…INV-8 trước khi viết RTL | ✅ (viết sau, nhưng đã có) | `functional_spec.md` §3 |
| 3 | Viết RTL, mỗi miền sườn một `always_ff` | ✅ | `h04_spi_slave.sv` 66 dòng |
| 4 | Testbench + mô hình chuẩn, phủ đủ 5 lớp `n` sườn | ❌ chỉ phủ `n=3`, `n=8` | `corner_cases.md` §2 |
| 5 | Mô phỏng RTL | ❌ **FAIL** `t=85` | `simulation.log` |
| 6 | Tổng hợp, **kiểm netlist đã ánh xạ hết** | ⚠️ PASS nhưng còn 8 `$_ALDFFE_NPP_` | `synth_stat.txt` |
| 7 | STA với SDC đủ mọi clock | ❌ **FAIL** cú pháp | `sta.log` |
| 8 | LibreLane → GDS | ⬜ chưa chạy | `06_GDSII/*/README.md` |

Bước 6 là bước mà flow hiện tại **thiếu một cổng kiểm**: `synth.ys` không có lệnh nào từ
chối netlist còn cell `$_`. Thêm một dòng kiểm sau `stat` sẽ chặn được ISS-2 ngay tại chỗ,
thay vì để nó nổ ở bước 7.

## 6. Số liệu thật đã đo được và cách đọc chúng

| Đại lượng | Giá trị | Nguồn |
|---|---:|---|
| Số cell | **62** | `synth_stat.txt` |
| Ô nhớ đã ánh xạ | **22** (`dfrtp_1`×11, `dfxtp_1`×8, `dfrtn_1`×3) | `synth_stat.txt` |
| Ô nhớ **chưa** ánh xạ | **8** (`$_ALDFFE_NPP_`) | `synth_stat.txt` |
| Tổng bit nhớ thật | **30** | 22 + 8 |
| Diện tích báo cáo | **710,6816 µm²** | `synth_stat.txt` |
| Slack / WNS / TNS | ⬜ **chưa có** | STA FAIL |
| Công suất | ⬜ **chưa có** | STA dừng trước `report_power` |

**62 cell chứng minh gì?** Rằng thiết kế nhỏ hơn ước lượng Charter (~230–330 cell) khoảng
4–5 lần — hợp lý, vì RTL là lõi trần, chưa có tầng bọc Tiny Tapeout.
**62 cell KHÔNG chứng minh gì?** Không chứng minh thiết kế đúng, và **không** phản ánh
diện tích thật: 22,6 % trong số đó (14 `clkinv_1`) là **14 bản sao của cùng một cổng đảo
`cs_n`** — artifact của `dfflibmap`, sẽ bị gộp ở bước resize.

**710,6816 µm² chứng minh gì?** Gần như không gì cả, vì nó **thiếu** phần diện tích của 8 ô
`$_ALDFFE_NPP_` (`Area for cell type $_ALDFFE_NPP_ is unknown!`). Diện tích thật **lớn hơn**
con số này; lớn hơn bao nhiêu thì chưa biết.

**30 bit nhớ so với Charter (20–24)?** Lệch 6–10 bit, và lệch có lý do: Charter đếm
8 + 8 + 3–4, không tính 8 FF `rx_byte`. Hai bộ đếm riêng cũng tốn thêm 3 FF.

## 7. Trả lời các câu hỏi kỹ thuật của Charter (mục 2)

**Câu 1 — CS nhả giữa chừng nghĩa là gì, mạch phải làm gì?**
Nghĩa là chủ huỷ giao dịch trước khi đủ 8 bit. Mạch phải: (a) xoá sạch `rx_shift` và
`rx_count` — RTL làm đúng qua reset bất đồng bộ; (b) **không** giao byte dở dang ra
`rx_byte` — RTL làm **đúng với n ≤ 6 nhưng SAI với n = 7**, vì bộ đếm bão hoà đạt 7 sau
đúng 7 sườn. Đã chứng minh bằng trace: `t=191, ↑sclk #7, rx_count=111`.

**Câu 2 — Nhận SCLK từ ngoài gây khó khăn gì?**
Ba khó khăn cụ thể. (i) **Không có reset hệ thống** — phải mượn `cs_n`, và nếu tầng ngoài
không tạo sườn thì mạch kẹt ở X (đây chính là ISS-1). (ii) **Đầu ra bất đồng bộ với phần
còn lại của chip** — `rx_byte` clock bằng `cs_n`, ai đọc nó phải tự đồng bộ 2 tầng.
(iii) **STA phức tạp hơn** — netlist có ba nhóm clock (`.CLK(sclk)`, `.CLK_N(sclk)`,
`.CLK(cs_n)`) nhưng `design.sdc` chỉ khai báo một.

**Câu 3 — Số ô nhớ dự đoán, phần nào dịch, phần nào đếm?**
Thực đo 30 bit: **dịch** = `rx_shift` 8 + `tx_shift` 7 + `miso` 1 = 16;
**chốt** = `rx_byte` 8; **đếm** = `rx_count` 3 + `tx_count` 3 = 6.

## 8. Trả lời câu phân tích riêng (Charter mục 9)

Câu hỏi: dùng `sclk` trực tiếp làm clock, hay đồng bộ nó vào miền hệ thống? Hệ quả tới STA?

**Lựa chọn của RTL này: dùng `sclk` trực tiếp.** Bằng chứng trong netlist:
11 `dfrtp_1` dùng `.CLK(sclk)`, 3 `dfrtn_1` dùng `.CLK_N(sclk)`, 8 `dfxtp_1` dùng
`.CLK(cs_n)`. Không có FF nào clock bằng một `clk` hệ thống — vì module **không có** cổng
`clk`.

**Hệ quả tới STA, nói bằng số:**

1. `design.sdc` chỉ có `create_clock -name sclk -period 10.0`. ⇒ 8 FF `rx_byte` nằm ngoài
   mọi phân tích. Đây là **8/30 = 27 % số ô nhớ không được kiểm timing**.
2. Đường `rx_shift[i] → mux2_1 → rx_byte[i]` là đường **liên miền bất đồng bộ**
   (`sclk` → `cs_n`). STA một-clock không báo nó; STA hai-clock sẽ báo **vi phạm giả** trừ
   khi khai `set_false_path` hoặc `set_max_delay`.
3. Sườn `↑cs_n` đồng thời là sự kiện **removal** cho 14 FF (11 `dfrtp_1` + 3 `dfrtn_1` qua
   14 cổng `clkinv_1`). Kiểm recovery/removal **chưa** được thực hiện.
4. Và trên hết: **STA hiện không chạy được gì cả** — `sta.log` chỉ có một dòng lỗi cú pháp.
   Tất cả các điểm 1–3 chỉ trở thành vấn đề *sau khi* ISS-2 được vá.

So với phương án đồng bộ hoá: nó cho một clock duy nhất, SDC một dòng, metastability gom
vào 2 FF đồng bộ có thể tính MTBF. Cái giá: +5 FF và ràng buộc cứng `f_clk ≥ 4·f_sclk`.
Charter mục 3 liệt "vượt miền xung nhịp đầy đủ" vào ngoài phạm vi, nên phương án hiện tại
là lựa chọn đúng phạm vi — miễn là **nói rõ khoảng trống kiểm chứng**, không che.

## 9. Những chỗ sinh viên hay sai và cách phát hiện

| # | Sai lầm | Hậu quả | Phát hiện bằng bằng chứng nào |
|---|---|---|---|
| 1 | Tưởng `logic cs_n=1` trong testbench là đã reset | Mạch chạy với trạng thái X, ca đầu tiên fail còn ca sau pass | `$monitor` trên `dut.rx_count`: nó là `xxx` suốt giao dịch đầu, `000` sau `↑cs_n` đầu tiên. **Dấu hiệu chẩn đoán: ca 1 fail, ca 3 pass** |
| 2 | Dùng `if (cnt != MAX) cnt <= cnt+1;` cho bộ đếm | Vòng khoá X — bộ đếm không bao giờ thoát X | Grep mọi `if` có điều kiện chứa chính biến được gán trong thân. Hoặc: chạy mô phỏng **không** reset và xem biến nào còn X sau N chu kỳ |
| 3 | Dùng giá trị bão hoà làm cờ "xong" | Byte thiếu 1 bit bị nhận như byte đủ | Viết ca `n = MAX` (ở đây `n = 7`) và so `rx_byte` trước/sau. Đây là TC-3 trong `corner_cases.md` |
| 4 | Nạp giá trị **biến** trong nhánh reset bất đồng bộ | Netlist không ánh xạ được ⇒ STA/PnR chết | `grep "not constant" yosys.log` — cảnh báo có sẵn ở dòng 61, 64. Hoặc `grep '\$_' synth_stat.txt` |
| 5 | Tin rằng "tổng hợp PASS" = netlist dùng được | Lỗi nổ ở bước sau, khó truy nguyên | So `Number of cells` với tổng các cell **có tên thư viện**. Ở đây 62 cell nhưng 8 cái tên bắt đầu bằng `$_` |
| 6 | Tin rằng mô hình chuẩn PASS là DUT đúng | Bỏ sót mọi lỗi mà mô hình không mô hình hoá | Đọc `reference_model.py`: nó không có biến trạng thái nào, `test_abort()` chỉ kiểm `len() != 8` |
| 7 | Không kiểm `miso` | 12/30 ô nhớ hoàn toàn không được verify | `grep miso h04_spi_slave_tb.sv` → **không có kết quả nào** ngoài khai báo và nối cổng |
| 8 | Đếm 14 `clkinv_1` rồi kết luận thiết kế tốn cổng đảo | Báo cáo sai về diện tích | Đọc `netlist.v`: cả 14 đều có `.A(cs_n)` — chúng là bản sao |

## 10. Câu hỏi mentor nên đặt khi bảo vệ

| # | Câu hỏi | Đáp án mong đợi |
|---|---|---|
| 1 | Vì sao mô phỏng fail ở giao dịch đầu mà pass ở giao dịch thứ ba? | Vì sườn `↑cs_n` tại `t=84` là sườn **thật** đầu tiên; nó reset mạch. Trước đó `rx_count` kẹt X |
| 2 | `rx_shift` cũng bắt đầu từ X, sao nó lại đúng ở `t=78`? | Thanh ghi dịch đẩy X ra ngoài sau 8 lần dịch; bộ đếm hồi tiếp X vào chính nó nên không thoát |
| 3 | `rx_count == 3'd7` có nghĩa "đã nhận 8 bit" không? | **Không.** Nó đúng từ sau sườn thứ 7. Chứng minh bằng trace `t=191` |
| 4 | Dòng nào trong RTL làm STA chết? | Dòng 39 `tx_shift <= tx_byte` trong nhánh `if (cs_n)` — nạp giá trị không hằng tại sườn bất đồng bộ |
| 5 | Vì sao OpenSTA báo lỗi ở dòng 39 của **netlist**, không phải RTL? | Netlist dòng 39 là `reg miso;` — OpenSTA chỉ đọc netlist cấu trúc, không hiểu `reg`/`always` |
| 6 | Khối này có FSM không? Chứng minh | Không: RTL không có `enum`, `case`, `state`; `yosys.log` chạy FSM_DETECT mà không trích được FSM nào |
| 7 | 8 `mux2_1` trong netlist từ đâu ra, RTL không viết mux nào? | Từ `if` có điều kiện trong khối tuần tự: thư viện không có FF-enable nên tool hiện thực "giữ" bằng mux hồi tiếp |
| 8 | Diện tích 710,68 µm² có tin được không? | **Không đầy đủ** — thiếu phần của 8 ô `$_ALDFFE_NPP_`, `synth_stat.txt` ghi `Area … is unknown!` |
| 9 | Nếu chủ cấp 12 sườn thay vì 8 thì sao? | `rx_shift` vẫn dịch, nhận 8 bit **cuối**; `tx_shift`/`miso` dừng ở `tx_count==7`. Chưa có ca kiểm thử |
| 10 | Ai chịu trách nhiệm đồng bộ `rx_byte` sang miền `clk`? | Tầng ngoài, bằng 2 tầng FF. Khối H04 không làm và không được yêu cầu làm |

## 11. Giới hạn: đã chứng minh được gì, chưa chứng minh được gì

**Đã chứng minh:**
- RTL biên dịch sạch (`iverilog_compile.log` rỗng).
- Đường **phát** hoạt động đúng: `miso` phát dãy `1,0,0,1,0,1,1,0` = `0x96` — kiểm bằng
  chạy lại có `$monitor` trên bản sao ngoài hồ sơ.
- Đường **nhận** dịch đúng: `rx_shift` đạt `3c` sau 8 sườn.
- Chính sách "không chốt khi `n = 3`" hoạt động đúng.
- Tổng hợp cho 62 cell, 22 ô nhớ đã ánh xạ, 8 ô chưa ánh xạ.
- Nguyên nhân gốc của cả hai lỗi, với bằng chứng từ mã và từ log.

**Chưa chứng minh được:**
- Mạch chạy đúng ở ca `n = 0`, `n = 7`, `n > 8` — **không có ca kiểm thử**.
- `miso` đúng — **testbench không đọc `miso`**.
- Bất kỳ số liệu timing nào: slack, WNS, TNS, `f_max` — **STA FAIL**.
- Bất kỳ số liệu công suất nào — **chưa chạy được**.
- Recovery/removal của `↑cs_n` đối với 14 FF — chưa kiểm.
- Hành vi liên miền `sclk → cs_n` — chưa kiểm.
- Mọi kết luận gate-level về nửa phát — **8 ô nhớ còn chưa là cell thật**.
- Diện tích thật — con số 710,68 µm² thiếu phần của 8 ô đó.

**Không được phát biểu** trong báo cáo: "đã sign-off", "chạy được ở X MHz", "diện tích
710,68 µm²" (phải ghi kèm "chưa đầy đủ"), hay "mô phỏng đã kiểm chứng thiết kế".

---

*Phiên bản: v1.0 · Ngày: 2026-09-24*
