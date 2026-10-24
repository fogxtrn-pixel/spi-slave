# H04 · Sơ đồ khối bên trong (Block Diagram)

Sơ đồ dưới đây vẽ theo **đúng** `04_IMPLEMENTATION/rtl/h04_spi_slave.sv` (66 dòng) và
được đối chiếu với `06_GDSII/synthesis/netlist.v` (375 dòng).

---

## 1. Ba miền sườn — điểm đặc trưng nhất của H04

Khối này **không có một clock**, nó có **ba nguồn sườn**:

```
 ╔══════════════════════════════════════════════════════════════════════════════════╗
 ║  h04_spi_slave                                                                   ║
 ║                                                                                  ║
 ║  ┌─ MIỀN A : ↑sclk  (dòng 21) ────────────────────────────────────────────────┐  ║
 ║  │                                                                            │  ║
 ║  │  mosi ──▶ ┌──────────────────────────────────────┐                         │  ║
 ║  │           │ rx_shift[7:0]   dịch trái, MSB trước │──┬──▶ (tới MIỀN C)       │  ║
 ║  │           └──────────────────────────────────────┘  │                      │  ║
 ║  │           ┌──────────────────────────────────────┐  │                      │  ║
 ║  │           │ rx_count[2:0]   đếm bão hoà tại 7    │──┼──▶ (tới MIỀN C)       │  ║
 ║  │           └──────────────────────────────────────┘  │                      │  ║
 ║  │                  ▲ reset bất đồng bộ: cs_n = 1      │                      │  ║
 ║  └─────────────────────────────────────────────────────┼──────────────────────┘  ║
 ║                                                        │                         ║
 ║  ┌─ MIỀN B : ↓sclk  (dòng 37) ─────────────────────────┼──────────────────────┐  ║
 ║  │                                                     │                      │  ║
 ║  │ tx_byte[7:0] ──▶┌────────────────────────────────┐  │                      │  ║
 ║  │   (nạp tại ↑cs_n)│ tx_shift[7:0]  dịch trái, chèn 0│──▶ bit[6] ──▶┌──────┐  │  ║
 ║  │                 └────────────────────────────────┘              │ miso │──╬══▶ miso
 ║  │                 ┌────────────────────────────────┐              │ FF   │  │  ║
 ║  │                 │ tx_count[2:0]  đếm bão hoà tại 7│──▶ enable ──▶└──────┘  │  ║
 ║  │                 └────────────────────────────────┘                        │  ║
 ║  │                  ▲ "reset" bất đồng bộ: cs_n = 1 ⇒ NẠP tx_byte (không về 0)│  ║
 ║  └────────────────────────────────────────────────────────────────────────────┘  ║
 ║                                                        │                         ║
 ║  ┌─ MIỀN C : ↑cs_n  (dòng 61) ─────────────────────────▼──────────────────────┐  ║
 ║  │                                                                            │  ║
 ║  │   rx_count == 3'd7 ──▶ enable ──▶ ┌────────────────────┐                   │  ║
 ║  │   rx_shift[7:0]    ──▶ data   ──▶ │ rx_byte[7:0]  8 FF │══════════════════════▶ rx_byte[7:0]
 ║  │                                   └────────────────────┘                   │  ║
 ║  └────────────────────────────────────────────────────────────────────────────┘  ║
 ╚══════════════════════════════════════════════════════════════════════════════════╝

   cs_n ──┬──▶ reset bất đồng bộ của MIỀN A
          ├──▶ "reset-nạp" bất đồng bộ của MIỀN B
          └──▶ CLOCK của MIỀN C          ← cùng một dây làm ba việc khác nhau
```

> 🔎 `cs_n` vừa là **tín hiệu điều khiển**, vừa là **reset**, vừa là **clock**. Đây là đặc
> điểm quan trọng nhất phải nói khi bảo vệ, và cũng là nguồn của cả hai lỗi trong hồ sơ này.

---

## 2. Ánh xạ cấu trúc RTL → phần cứng sinh ra

Đối chiếu từng cấu trúc RTL với cell thật trong `netlist.v`.

| Cấu trúc RTL (dòng) | Phần cứng sinh ra | Cell thật trong netlist | Số lượng |
|---|---|---|---:|
| `rx_shift <= {rx_shift[6:0], mosi}` (27) | 8 FF nối chuỗi, D của FF[0] nối thẳng `mosi` | `dfrtp_1` `_86_`…`_93_` | 8 |
| `rx_count <= rx_count + 1'b1` có chốt `!=7` (31–32) | 3 FF + bộ tăng 3 bit có enable | `dfrtp_1` `_83_`…`_85_` + `a21o_1 _33_`, `nand3_1 _34_`, `xnor2_1 _35_`, `nand2_1 _36_/_37_` | 3 FF + 5 cổng |
| `if (rx_count == 3'd7)` (62) | Bộ so sánh bằng hằng | **`nand3_1 _34_`** — `_29_ = ~(rx_count[2]&[1]&[0])` | 1 (dùng chung) |
| `rx_byte <= rx_shift` có điều kiện (62–63) | 8 FF **không** enable + 8 mux hồi tiếp | `dfxtp_1 _64_`…`_71_` + `mux2_1 _43_`…`_50_` | 8 + 8 |
| `tx_shift <= {tx_shift[6:0],1'b0}` với nạp `tx_byte` tại `↑cs_n` (39, 46) | FF có **nạp bất đồng bộ giá trị không phải hằng** | ❌ **`$_ALDFFE_NPP_` — KHÔNG ánh xạ được** | 7 |
| `miso <= …` (41, 47) | cùng loại trên | ❌ **`$_ALDFFE_NPP_`** | 1 |
| `tx_count` (40, 44) | 3 FF sườn **xuống** + bộ tăng | `dfrtn_1 _80_`…`_82_` + `a21o_1 _39_`, `nand3_1 _38_`, `xnor2_1 _40_`, `nand2_1 _41_/_42_` | 3 FF + 5 cổng |
| `if (cs_n)` — reset bất đồng bộ | Đảo `cs_n` cấp cho chân `RESET_B` | `clkinv_1 _32_`, `_51_`…`_63_` | **14** |
| `tx_shift[7]` | — | **bị tối ưu mất**: nó chỉ được nạp rồi dịch ra, không ai đọc | 0 |

Tổng: 8 + 3 + 8 + 7 + 1 + 3 = **30 bit nhớ**, nhưng chỉ **22** thành cell thật.

### 2.1 Chi tiết: vì sao có 14 cổng đảo giống hệt nhau

`netlist.v` dòng 69–71 và 173–225 có **14** `clkinv_1` **cùng nhận `cs_n`** và sinh 14 dây
`_00_`…`_13_` khác nhau, mỗi dây cấp cho `RESET_B` của đúng **một** FF (11 `dfrtp_1` +
3 `dfrtn_1`).

Về logic, một cổng đảo là đủ. Đây là hệ quả của lệnh `dfflibmap` trong `synth.ys`: nó ánh
xạ **từng FF một**, mỗi lần tự tạo cổng đảo riêng, rồi `opt_clean -purge` **không** gộp lại
vì hai cổng đảo giống nhau vẫn là hai instance hợp lệ.
👉 Trong một flow thật, bước `share`/`opt_merge` hoặc bước sizing của OpenROAD sẽ gộp
14 cổng này thành 1 cổng + buffer tree. **Không** được kết luận "thiết kế cần 14 cổng đảo".

### 2.2 Chi tiết: vì sao có 8 `mux2_1` mà RTL không viết mux nào

RTL viết `if (rx_count == 3'd7) rx_byte <= rx_shift;` — tức "có điều kiện thì nạp, không
thì **giữ**". Thư viện `sky130_fd_sc_hd` có FF **không** chân enable (`dfxtp_1`), nên Yosys
hiện thực "giữ" bằng **hồi tiếp qua mux**:

```
        rx_shift[i] ──▶ A0 ┐
                           ├─ mux2_1 ──▶ D ┌────────────┐
   ┌──▶ rx_byte[i]  ──▶ A1 ┘               │  dfxtp_1   │──┬──▶ rx_byte[i]
   │                     S = _29_          │  CLK = cs_n│  │
   │                     = ~(rx_count==7)  └────────────┘  │
   └───────────────────────────────────────────────────────┘
```

Đây là **mẫu chuẩn** cho "register có enable" trên thư viện không có FF-enable. Sinh viên
hay tưởng mux là do mình viết sai — không phải, đó là cách tool hiện thực `if` trong khối
tuần tự.

---

## 3. Tám ô nhớ **chưa** thành cell — vấn đề nghiêm trọng nhất

`synth_stat.txt` ghi rõ:

```
     $_ALDFFE_NPP_                   8
   Area for cell type $_ALDFFE_NPP_ is unknown!
```

`$_ALDFFE_NPP_` = **A**synchronous-**L**oad **DFF** with **E**nable. Nó ra đời vì RTL yêu cầu
một việc mà **không flip-flop tiêu chuẩn nào làm được**: nạp một **giá trị biến thiên**
(`tx_byte`) theo một tín hiệu **bất đồng bộ** (`cs_n`). Yosys đã cảnh báo hai lần
(`yosys.log` dòng 61, 64):

```
Warning: Async reset value `\tx_byte [7]' is not constant!
Warning: Async reset value `\tx_byte' is not constant!
```

Hệ quả dây chuyền:

```
  RTL: tx_shift <= tx_byte tại ↑cs_n
        │
        ▼ Yosys suy ra $aldffe (dòng 303 yosys.log: "Using extmapper simplemap")
  dfflibmap KHÔNG tìm được cell tương ứng trong sky130
        │
        ▼
  write_verilog phải xuất chúng dưới dạng HÀNH VI:
      netlist.v:39   reg miso;
      netlist.v:62-68 reg \tx_shift[0..6] ;
      netlist.v:267  always @(negedge sclk, posedge cs_n)  … (×8)
        │
        ▼
  OpenSTA (chỉ đọc netlist CẤU TRÚC) gặp `reg` ở dòng 39 ⇒ syntax error ⇒ STA FAIL
```

👉 **Lỗi STA không phải lỗi timing.** Xem phán xử đầy đủ ở `05_VERIFICATION/known_issues.md` §6.

---

## 4. Khối con nào nằm trên đường tới hạn?

| Câu hỏi | Trả lời |
|---|---|
| `06_GDSII/sta/` có báo cáo đường tới hạn không? | ❌ **Không.** Chỉ có `sta.log` chứa một dòng lỗi. Không có `timing_report_max.txt`, `wns.txt`, `tns.txt`. |
| Vậy khối nào tới hạn? | ⬜ **Chưa xác định được bằng công cụ.** |
| Dự đoán từ RTL? | Có — xem `datapath.md` §4. Nhưng đó **chỉ là dự đoán**, chưa được kiểm chứng. |

**Điều kiện để có câu trả lời:** (1) áp bản vá ở `known_issues.md` §6 để netlist ánh xạ hết,
(2) viết SDC định nghĩa **hai** clock (`sclk` và `cs_n`) thay vì một như `design.sdc` hiện tại,
(3) chạy lại `03_run_sta.tcl`.

---

## 5. Đối chiếu quy mô với Charter

| Nguồn | Con số | Nhận xét |
|---|---:|---|
| Charter mục 1 ước lượng | ~230–330 cell | Thực đo **62** cell — thấp hơn ~4–5 lần |
| Charter mục 10 "dấu hiệu làm đúng" | 8 + 8 + 3–4 ≈ **20–24 ô nhớ** | Thực đo **30 bit nhớ** |

**Giải thích chênh lệch:**

- **62 ≪ 230:** ước lượng Charter tính cho một khối SPI tớ *có tầng bọc Tiny Tapeout,
  có FSM, có thanh ghi trạng thái*. RTL hiện tại là **lõi trần**: không FSM, không bọc,
  không tri-state. Phần còn thiếu chính là W-1 ở `functional_spec.md`.
- **30 > 24:** Charter đếm 8 (dịch ra) + 8 (dịch vào) + 3–4 (đếm). RTL thêm **8 ô `rx_byte`**
  (thanh ghi chốt riêng) và dùng **hai** bộ đếm 3 bit (`rx_count`, `tx_count`) thay vì một.
  8 + 8 + 8 + 3 + 3 = 30, trừ `tx_shift[7]` bị tối ưu đi ⇒ 8 + 7 + 8 + 3 + 3 + 1 (`miso`) = 30.
  Cả hai lựa chọn đều **hợp lý về chức năng**, chỉ là Charter không tính tới.

---

*Phiên bản: v1.0 · Ngày: 2026-09-24*
