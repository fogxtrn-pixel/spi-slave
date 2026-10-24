# H04 · Phân tích đánh đổi (Trade-off)

Mọi số liệu trong tài liệu này lấy từ `06_GDSII/synthesis/synth_stat.txt`. Nơi nào chưa có
số, ghi rõ ⬜ và nêu điều kiện để có.

---

## 1. Kiến trúc đã chọn

**"Hai thanh ghi dịch độc lập + hai bộ đếm bão hoà + một thanh ghi chốt, `cs_n` làm cả
reset lẫn clock."**

| Chỉ số thật đo được | Giá trị | Nguồn |
|---|---:|---|
| Số cell | **62** | `synth_stat.txt` |
| Ô nhớ đã ánh xạ | **22** | `dfrtp_1`×11 + `dfxtp_1`×8 + `dfrtn_1`×3 |
| Ô nhớ **chưa** ánh xạ | **8** (`$_ALDFFE_NPP_`) | `synth_stat.txt` |
| Diện tích báo cáo | **710,6816 µm²** | `synth_stat.txt` — ⚠️ **thiếu** phần của 8 ô ALDFFE |
| Độ sâu tổ hợp lớn nhất | 3 cổng (chuỗi `nand3 → xnor2 → nand2` của bộ đếm) | đọc `netlist.v` |
| Slack / WNS / TNS | ⬜ **chưa có** — STA FAIL | `sta.log` |
| Công suất | ⬜ **chưa có** — STA dừng trước `report_power` | — |

---

## 2. So sánh với các kiến trúc thay thế

### 2.1 Bảng tổng hợp

| # | Kiến trúc | Ô nhớ | Cell ước tính | Độ trễ (số sườn/byte) | Độ phức tạp | Khi nào nên dùng |
|---|---|---:|---:|---:|---|---|
| **A** | **Đang dùng:** 2 shift + 2 counter + latch `rx_byte`, `cs_n` làm clock | **30** | **62** (đo) | 8 | Thấp | Khi `cs_n` sạch, tầng ngoài chịu trách nhiệm CDC |
| B | 2 shift + **1** counter dùng chung | 27 | ⬜ ước tính giảm ~5 cell (3 FF + 5 cổng, bớt 5 cổng đếm) | 8 | Trung bình — thêm đường liên miền ↑/↓`sclk` | Khi diện tích cực kỳ chật |
| C | **Không** có `rx_byte`, đưa thẳng `rx_shift` ra ngoài | 22 | ⬜ ước tính giảm ~16 cell (8 FF + 8 mux) | 8 | Rất thấp | Khi tầng ngoài tự biết đếm bit và chịu nhận byte dở |
| D | Đồng bộ `sclk`/`cs_n` vào **clock hệ thống**, lấy mẫu bằng bộ phát hiện sườn | ~40+ | ⬜ ước tính tăng đáng kể (thêm 4–6 FF đồng bộ + logic phát hiện sườn) | 8 sườn `sclk`, nhưng cần `f_clk ≥ 4·f_sclk` | Cao | Khi cần STA một clock sạch và cần ghép với phần còn lại của chip |
| E | FSM tường minh `enum {IDLE, RECV, FULL}` + 1 shift + 1 counter | ~31 | ⬜ ước tính tương đương A, +2–4 cell cho thanh ghi trạng thái | 8 | Trung bình | Khi cần chứng minh tính đúng đắn / khi mở rộng sang nhiều mode |

> Các ô ⬜ là **ước tính từ việc đếm cấu trúc trong netlist hiện tại**, không phải số đo.
> Muốn có số thật phải viết RTL biến thể và chạy lại Yosys — nằm **ngoài phạm vi** hồ sơ này.

### 2.2 Phương án D — đáng phân tích kỹ nhất

Đây là nội dung Charter mục 9 yêu cầu trả lời.

```
  PHƯƠNG ÁN A (đang dùng)                PHƯƠNG ÁN D (đồng bộ hoá)
  ═══════════════════════                ═══════════════════════════

  sclk ──▶ CLK của 11+3 FF               sclk ──▶ [FF][FF][FF] ──▶ phát hiện sườn ──┐
  cs_n ──▶ RESET của 14 FF                          ▲ clk                          │
       └─▶ CLK của 8 FF                  cs_n ──▶ [FF][FF] ──▶ phát hiện sườn ──────┤
                                                   ▲ clk                           ▼
  → 3 miền nhịp, không đồng bộ           clk ──▶ TẤT CẢ FF  ◀── enable ────────────┘

  STA: phải khai báo 2 clock             STA: MỘT clock duy nhất, phân tích sạch
       + false_path liên miền            Ràng buộc: f_clk ≥ 4 × f_sclk (Nyquist ×2)
  Rủi ro: metastable ở rx_byte           Rủi ro: metastable chỉ ở 2 FF đồng bộ đầu
  Chi phí: 0 FF thêm                     Chi phí: +5 FF, + logic phát hiện sườn
```

| Tiêu chí | A | D |
|---|---|---|
| Số FF | 30 | ~35 |
| Số miền clock cần khai báo trong SDC | 2 (`sclk`, `cs_n`) | 1 (`clk`) |
| STA có chạy được không? | ❌ hiện FAIL, và kể cả sửa netlist vẫn cần SDC đa clock | ✅ SDC một dòng là đủ |
| Tần số `sclk` tối đa bị giới hạn bởi | Độ trễ cổng bên trong (rất nhỏ) — nên gần như tuỳ ý | `f_clk / 4` — **giới hạn cứng** |
| Metastability | Ở **8 FF** `rx_byte` + 14 FF (removal) | Ở **2 FF** đồng bộ, có thể tính MTBF |
| Phù hợp với đề H04 | ✅ — Charter mục 3 liệt "vượt miền xung nhịp đầy đủ" là **ngoài phạm vi** | ⚠️ vượt phạm vi |

**Kết luận cho Charter mục 9:** RTL hiện tại chọn **dùng `sclk` trực tiếp làm xung nhịp**
(phương án A). Hệ quả tới STA là **trực tiếp và đo được**: `design.sdc` chỉ khai báo
`create_clock -name sclk -period 10.0`, nên ngay cả khi lỗi cú pháp netlist được sửa,
8 FF `rx_byte` (clock bằng `cs_n`) vẫn **không** được phân tích. Đó là một khoảng trống
kiểm chứng phải nói rõ trong báo cáo, không được che.

---

## 3. Đánh đổi cụ thể trong từng lựa chọn của RTL

| Lựa chọn của RTL | Được gì | Mất gì | Bằng chứng |
|---|---|---|---|
| `miso` có FF riêng thay vì nối `tx_shift[7]` | Đầu ra sạch, không glitch; đổi đúng tại sườn xuống | +1 FF, và `tx_shift[7]` thành thừa (bị tối ưu mất) | `netlist.v` không có `tx_shift[7]`; chỉ 7 `$_ALDFFE_NPP_` cho `tx_shift` + 1 cho `miso` |
| Hai bộ đếm riêng (`rx_count`, `tx_count`) | Hai miền sườn độc lập hoàn toàn; không có đường liên miền nội bộ | +3 FF, +5 cổng | `netlist.v`: `_38_`…`_42_` là bản sao của `_33_`…`_37_` |
| Bộ đếm **bão hoà** thay vì quay vòng | Tự giữ trạng thái "đã xong", không cần cờ `done` | ❌ Giá trị 7 trở nên **mập mờ** ⇒ lỗ hổng 7-bit | `functional_spec.md` §5.2 |
| Thanh ghi chốt `rx_byte` riêng | Thực hiện đúng chính sách "chỉ giao byte trọn vẹn" của Charter mục 10 | +8 FF +8 mux ≈ **26% số cell** | `netlist.v` `_43_`…`_50_`, `_64_`…`_71_` |
| Nạp `tx_shift ← tx_byte` tại `↑cs_n` | Không cần tín hiệu `load` riêng; dùng lại `cs_n` | ❌ **Sinh `$_ALDFFE_NPP_` ⇒ netlist không ánh xạ hết ⇒ STA FAIL** | `yosys.log` dòng 61, 64; `sta.log` |
| Không có cổng `rst_n` | Tiết kiệm 1 chân trong ngân sách 24 chân | ❌ Không có POR ⇒ lỗi X-lock | `simulation.log` |

---

## 4. Đánh đổi về diện tích — phân tích bằng số thật

Phân rã 62 cell theo chức năng (đếm trực tiếp từ `netlist.v`):

| Nhóm chức năng | Cell | % của 62 |
|---|---:|---:|
| Thanh ghi dịch nhận `rx_shift` | 8 (`dfrtp_1`) | 12,9 % |
| Thanh ghi chốt `rx_byte` + mux giữ | 8 + 8 = 16 | **25,8 %** |
| Bộ đếm `rx_count` + logic | 3 + 5 = 8 | 12,9 % |
| Bộ đếm `tx_count` + logic | 3 + 5 = 8 | 12,9 % |
| Đường phát (`tx_shift`, `miso`) | 8 (`$_ALDFFE_NPP_`) | 12,9 % — **chưa là cell thật** |
| **Cổng đảo `cs_n` lặp 14 lần** | 14 (`clkinv_1`) | **22,6 %** |
| **Tổng** | 62 | 100 % |

Hai con số đáng nói với sinh viên:

1. **22,6 % số cell là 14 cổng đảo giống hệt nhau** — tất cả đều nhận `cs_n`. Đây là
   **artifact của flow**, không phải nhu cầu thiết kế. `dfflibmap` tạo một cổng đảo cho
   mỗi FF và `opt_clean -purge` không gộp lại. Trong LibreLane/OpenROAD, bước resizer sẽ
   gộp thành 1 cổng + cây buffer. 👉 **Không được** báo cáo "thiết kế tốn 14 cổng đảo".
2. **25,8 % số cell dành cho chính sách "chỉ giao byte trọn vẹn"** (`rx_byte` + mux).
   Đó là cái giá của yêu cầu quan trọng nhất trong Charter mục 10 — và là lập luận tốt
   để trả lời "vì sao không bỏ `rx_byte` đi cho gọn".

Còn **710,6816 µm²** thì sao? Con số này **không đầy đủ**: `synth_stat.txt` ghi rõ
`Area for cell type $_ALDFFE_NPP_ is unknown!`. Tám ô nhớ chưa ánh xạ **không được tính
diện tích**. Diện tích thật sau khi vá sẽ **lớn hơn** 710,68 µm², lớn hơn bao nhiêu thì
⬜ chưa biết — phải chạy lại Yosys sau khi áp bản vá.

---

## 5. Những đánh đổi **KHÔNG được phép** trong đề này

| Đánh đổi | Vì sao bị cấm | Nguồn ràng buộc |
|---|---|---|
| Thêm chế độ SPI 1/2/3 để "linh hoạt hơn" | Ngoài phạm vi | Charter mục 3: "Nhiều mode" |
| Thêm FIFO 2–4 byte để tăng thông lượng | Ngoài phạm vi | Charter mục 3: "bộ đệm sâu" |
| Thêm đầy đủ cơ chế vượt miền xung nhịp (phương án D) | Ngoài phạm vi | Charter mục 3: "vượt miền xung nhịp đầy đủ" |
| **Tự sửa netlist bằng tay** để STA chạy được | Đó là gian lận kỹ thuật: netlist phải là sản phẩm của tổng hợp. Phải sửa **RTL** rồi chạy lại | Nguyên tắc chung của flow |
| Bỏ `rx_byte` (phương án C) để giảm 26 % cell | Làm mất yêu cầu trọng tâm "CS nhả giữa chừng không sinh byte giả" | Charter mục 8 + mục 10 |
| Tự tối ưu bằng tay 14 cổng đảo | Physical design là ngoài phạm vi; và tool sẽ tự làm | Charter mục 3 |
| Thiết kế mức transistor cho bộ đệm chân | Ngoài phạm vi với **mọi** đề | Charter mục 3 |

---

## 6. Đánh đổi **được phép và nên làm** — theo thứ tự ưu tiên

| Ưu tiên | Việc | Chi phí | Lợi ích | Tham chiếu |
|---|---|---|---|---|
| 1 | Sửa cách nạp `tx_shift` để bỏ `$_ALDFFE_NPP_` | +1–3 cell | **Mở khoá toàn bộ STA, công suất, và các bước sau** | `known_issues.md` §6 |
| 2 | Mở rộng `rx_count` lên 4 bit **hoặc** thêm cờ `rx_full` | +1 FF | Đóng lỗ hổng 7-bit — yêu cầu trọng tâm của đề | `known_issues.md` §5 |
| 3 | Thêm `↑cs_n` khởi tạo vào testbench | 0 cell | Lỗi mô phỏng biến mất | `known_issues.md` §4 |
| 4 | Bổ sung SDC cho clock `cs_n` + `set_false_path` liên miền | 0 cell | STA phân tích được cả 3 miền | `datapath.md` §4.2 |
| 5 | Viết tầng bọc Tiny Tapeout để giải quyết xung đột `uio[0,1,2]` | vài cell | Thoả Charter mục 4 | `functional_spec.md` W-1 |

Ba việc đầu **không** đổi kiến trúc, nên **không** vi phạm phạm vi Charter mục 3.
Cả năm đều **chưa được áp dụng** — RTL trong hồ sơ giữ nguyên bản gốc.

---

*Phiên bản: v1.0 · Ngày: 2026-09-24*
