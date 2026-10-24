# H04 · Đường dữ liệu (Datapath)

---

## 1. Hai đường dữ liệu độc lập, chạy ngược chiều

H04 là khối **song công**: hai đường dữ liệu hoàn toàn tách biệt, không chia sẻ ô nhớ nào,
và **chạy trên hai sườn khác nhau của cùng một dây `sclk`**.

```
   ĐƯỜNG NHẬN  (↑sclk)                          ĐƯỜNG PHÁT  (↓sclk)
   ═══════════════════                          ═══════════════════

   mosi ──▶ rx_shift[7:0] ──┐                   tx_byte[7:0]
             (dịch trái)    │                        │ nạp tại ↑cs_n
                            │                        ▼
   rx_count[2:0] ──▶ ==7? ──┤                   tx_shift[7:0] (dịch trái, chèn 0)
                            │                        │ bit [6]
                            ▼ chốt tại ↑cs_n         ▼
                      rx_byte[7:0] ══▶ ra        miso ──▶ ra
                                                      ▲ enable
                                                 tx_count[2:0] ──▶ !=7?
```

Điểm chung duy nhất: cả hai bị `cs_n` điều khiển — nhưng **theo hai cách khác nhau**
(một bên xoá về 0, một bên nạp `tx_byte`). Chính sự khác nhau đó sinh ra `$_ALDFFE_NPP_`.

---

## 2. Bảng các đường dữ liệu

| Đường | Độ rộng | Từ | Đến | Sườn hoạt động | Bản chất |
|---|---:|---|---|---|---|
| `mosi` | 1 | cổng vào | `rx_shift[0]` | ↑`sclk` | Dữ liệu nối tiếp vào |
| `rx_shift[7:0]` | 8 | chuỗi 8 FF | `rx_byte` (qua mux) | ↑`sclk` | **Thanh ghi dịch** — chuyển nối tiếp→song song |
| `rx_count[2:0]` | 3 | bộ đếm bão hoà | so sánh `==7` | ↑`sclk` | Trạng thái điều khiển, không phải dữ liệu |
| `rx_byte[7:0]` | 8 | 8 FF chốt | cổng ra | ↑`cs_n` | Thanh ghi chốt (holding register) |
| `tx_byte[7:0]` | 8 | cổng vào | `tx_shift` | ↑`cs_n` (nạp) | Dữ liệu song song vào |
| `tx_shift[7:0]` | 8 | chuỗi FF | `miso` (từ bit 6) | ↓`sclk` | **Thanh ghi dịch** — song song→nối tiếp |
| `tx_count[2:0]` | 3 | bộ đếm bão hoà | enable của `tx_shift`/`miso` | ↓`sclk` | Trạng thái điều khiển |
| `miso` | 1 | FF riêng | cổng ra | ↓`sclk` | Dữ liệu nối tiếp ra — **có FF riêng**, không phải dây từ `tx_shift[7]` |

> 🔎 Chi tiết dễ bỏ sót: `miso` **không** là `tx_shift[7]`. RTL cho `miso` một FF riêng
> (dòng 41, 47) và lấy dữ liệu từ `tx_shift[6]`. Đó là lý do `tx_shift[7]` bị tối ưu mất
> hoàn toàn trong netlist, và là lý do có **7** ô `tx_shift` chứ không phải 8.

---

## 3. Đồ thị phụ thuộc và độ sâu logic

Khác hẳn A01 (bộ cộng ripple-carry, phụ thuộc nối tiếp 8 tầng trong **một** chu kỳ),
H04 **không có chuỗi tổ hợp dài nào**. Dữ liệu đi qua 8 tầng, nhưng mỗi tầng cách nhau
**một sườn clock**, không phải một cổng logic.

```
 ↑sclk #1 : mosi ──▶ rx_shift[0]                    độ sâu tổ hợp = 0 (dây thẳng)
 ↑sclk #2 : rx_shift[0] ──▶ rx_shift[1]             độ sâu tổ hợp = 0
    …
 ↑sclk #8 : rx_shift[6] ──▶ rx_shift[7]             độ sâu tổ hợp = 0
                     └── netlist: .D(\rx_shift[6]) nối THẲNG vào FF kế tiếp

 song song, mỗi ↑sclk:
   rx_count[2:0] ──▶ nand3(_34_) ──▶ nand2(_36_/_37_) ──▶ D của rx_count   độ sâu = 2–3
                            └──────▶ S của 8 mux2 ──▶ D của rx_byte        độ sâu = 2
```

| Đầu ra | Chuỗi tổ hợp giữa hai FF | Độ sâu (số cổng) |
|---|---|---:|
| `rx_shift[i]` | không có — nối thẳng | **0** |
| `rx_count[0]` | `nand3 _34_` → `nand2 _37_` | 2 |
| `rx_count[1]` | `nand3 _34_` → `xnor2 _35_` → `nand2 _36_` | 3 |
| `rx_count[2]` | `a21o_1 _33_` | 1 |
| `rx_byte[i]` | `nand3 _34_` → `mux2 _43_…_50_` | 2 |
| `tx_count[i]` | tương tự `rx_count` (`_38_`…`_42_`) | 1–3 |
| `miso`, `tx_shift[i]` | **không đo được** — còn là `$_ALDFFE_NPP_` hành vi | ❓ |

### Nhận xét quan trọng

**Độ sâu tổ hợp lớn nhất đo được là 3 cổng.** So với A01 (8 tầng carry nối tiếp),
H04 là một mạch **rất nông**. Nút thắt hiệu năng của H04 **không phải** logic, mà là:

1. **Băng thông:** cần đúng 8 chu kỳ `sclk` cho mỗi byte — không rút ngắn được, đó là
   bản chất của giao tiếp nối tiếp.
2. **Chất lượng sườn `sclk`:** vì `sclk` đến từ bên ngoài, jitter và thời gian lên/xuống
   của nó quyết định tần số tối đa, **không phải** độ trễ cổng bên trong.

---

## 4. Dự đoán đường tới hạn — và vì sao chưa đối chiếu được

### 4.1 Dự đoán từ RTL

| Hạng | Đường ứng viên | Lý do |
|---|---|---|
| 1 | `rx_count[*]` → `nand3 _34_` → `xnor2 _35_` → `nand2 _36_` → `rx_count[1]` | Chuỗi dài nhất (3 cổng) trong miền ↑`sclk`, lại là **vòng hồi tiếp** của bộ đếm ⇒ cả arrival lẫn required đều trong cùng một chu kỳ `sclk` |
| 2 | `tx_count[*]` → `_38_` → `_40_` → `_41_` → `tx_count[1]` | Cùng cấu trúc, nhưng ở miền ↓`sclk` |
| 3 | `rx_shift[7]` → `mux2 _50_` → `rx_byte[7]` | Đường **liên miền** ↑`sclk` → ↑`cs_n` — về hình thức ngắn (1 mux), nhưng đây là đường **nguy hiểm nhất về mặt vật lý**, xem §4.3 |
| — | `rx_shift[i]` → `rx_shift[i+1]` | **Không** tới hạn: nối thẳng, độ sâu 0 |

### 4.2 Đối chiếu với STA thật

⬜ **Chưa thực hiện được.**

```
06_GDSII/sta/sta.log:
  Error: 171 …/netlist.v line 39, syntax error
```

Thư mục `06_GDSII/sta/` **không** có `timing_report_max.txt`, `wns.txt`, `tns.txt`, và
`06_GDSII/power/` **không** có `power_report.txt`. Mọi ô "Startpoint → Endpoint",
"Data arrival time", "Slack", "WNS/TNS", "Công suất" trong `physical_report.md` đều là `—`.

**Điều kiện để đối chiếu được** (không được bỏ qua bước nào):

| # | Việc phải làm | Vì sao |
|---|---|---|
| 1 | Áp bản vá `known_issues.md` §6 để `tx_shift`/`miso` không còn cần nạp bất đồng bộ | Để 8 ô `$_ALDFFE_NPP_` ánh xạ được thành `dfrtn_1`/`dfstp_1` thật |
| 2 | Chạy lại Yosys, xác nhận `synth_stat.txt` **không còn dòng `$_`** | Netlist mới sẽ thuần cấu trúc, không có `reg`/`always` |
| 3 | Sửa `design.sdc`: hiện chỉ có `create_clock -name sclk -period 10.0`. Phải thêm `create_clock` cho **`cs_n`** | 8 FF `rx_byte` được clock bằng `cs_n`; nếu không khai báo, STA bỏ qua toàn bộ miền C |
| 4 | Thêm `set_false_path` hoặc `set_max_delay` cho đường ↑`sclk` → ↑`cs_n` | Hai clock bất đồng bộ với nhau — nếu để STA tự phân tích, nó sẽ báo vi phạm giả |
| 5 | Chạy lại `04_IMPLEMENTATION/scripts/03_run_sta.tcl` | — |

### 4.3 Vì sao đường `rx_shift` → `rx_byte` là đường nguy hiểm nhất, dù ngắn nhất

`rx_shift` được clock bằng `sclk`; `rx_byte` được clock bằng `cs_n`. Hai tín hiệu này
**không có quan hệ pha nào** — chủ có thể nhả `cs_n` ở bất cứ đâu sau sườn `sclk` cuối.
Nghĩa là mọi FF `rx_byte` đều có nguy cơ **vi phạm setup/hold và metastable**, và
đây là loại vi phạm **STA một-clock không bao giờ báo**.

Đồng thời, cùng dây `cs_n` cấp `RESET_B` cho 11 + 3 = 14 FF của miền A và B, nên sườn
`↑cs_n` còn là sự kiện **removal** đối với chúng. Cả hai loại kiểm tra (recovery/removal
và setup liên miền) đều **chưa** được thực hiện trong hồ sơ này.

```
      sclk  ─┐_┌─┐_┌─┐_┌─          ← miền A/B
                        ╲
                         ╲  đường liên miền, KHÔNG đồng bộ
                          ╲
      cs_n  ______________╱‾‾‾‾‾   ← miền C (clock) + removal của A/B
                          ↑
              Ở đây rx_shift đang ổn định hay đang đổi?  ⇒ KHÔNG AI BẢO ĐẢM
```

---

## 5. Vì sao không có pipeline, không có tối ưu độ trễ

| Câu hỏi | Trả lời |
|---|---|
| Có thể rút ngắn 8 chu kỳ xuống ít hơn không? | **Không.** Giao thức SPI quy định 8 sườn cho 8 bit. Đây là ràng buộc giao thức, không phải ràng buộc thiết kế. |
| Có thể pipeline đường nhận không? | Vô nghĩa — độ sâu tổ hợp đã bằng 0. |
| Có thể gộp `rx_count` và `tx_count` làm một không? | **Có** về lý thuyết (cùng đếm 0→7), nhưng chúng chạy trên **hai sườn khác nhau** ⇒ gộp sẽ tạo đường liên miền mới. Tiết kiệm 3 FF, đổi lấy một rủi ro CDC. Xem `tradeoff.md` §3. |
| Có thể bỏ `rx_byte` và đưa thẳng `rx_shift` ra ngoài không? | **Có** — tiết kiệm 8 FF + 8 mux (≈ 1/4 diện tích). Nhưng mất chính sách "chỉ giao byte trọn vẹn" mà Charter mục 10 coi là trọng tâm đề. Xem `tradeoff.md` §3. |

---

*Phiên bản: v1.0 · Ngày: 2026-09-24*
