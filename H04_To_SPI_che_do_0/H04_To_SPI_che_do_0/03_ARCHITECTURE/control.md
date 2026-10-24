# H04 · Phần điều khiển (Control)

H04 là **mạch tuần tự**, nên mục này mô tả khối điều khiển **thật** của nó.

---

## 1. Điều khiển ở H04 nằm ở đâu

Điều khiển của H04 **không** tập trung vào một FSM. Nó được phân tán vào **ba cơ chế**:

```
 ┌──────────────────────────────────────────────────────────────────────────┐
 │ CƠ CHẾ 1 — MỨC cs_n : reset bất đồng bộ                                  │
 │   cs_n = 1  ⇒  rx_shift ← 0, rx_count ← 0        (dòng 22–24)            │
 │              ⇒  tx_shift ← tx_byte, tx_count ← 0, miso ← tx_byte[7]      │
 │                                                    (dòng 38–41)          │
 │   Không cần sườn — chỉ cần MỨC. Đây là "điều khiển không tốn ô nhớ".     │
 ├──────────────────────────────────────────────────────────────────────────┤
 │ CƠ CHẾ 2 — BỘ ĐẾM BÃO HOÀ : sinh enable                                  │
 │   rx_count : 0→1→…→7→7→7…   chốt bởi `if (rx_count != 3'd7)`  (dòng 31)  │
 │   tx_count : 0→1→…→7→7→7…   chốt bởi `if (tx_count != 3'd7)`  (dòng 43)  │
 │   Bão hoà (không quay vòng) ⇒ trạng thái "đã xong" tự giữ.               │
 ├──────────────────────────────────────────────────────────────────────────┤
 │ CƠ CHẾ 3 — SƯỜN ↑cs_n : sự kiện "kết thúc giao dịch"                     │
 │   Dùng làm CLOCK cho rx_byte, kèm điều kiện `rx_count == 3'd7` (dòng 62) │
 └──────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Bảng tín hiệu điều khiển và tác dụng

| Tín hiệu | Nguồn | Loại | Tác dụng chính xác | Dòng RTL |
|---|---|---|---|---|
| `cs_n` (mức 1) | cổng vào | mức, bất đồng bộ | Xoá `rx_shift`, `rx_count`; nạp `tx_shift ← tx_byte`, `tx_count ← 0`, `miso ← tx_byte[7]` | 22–24, 38–41 |
| `cs_n` (sườn ↑) | cổng vào | sườn | Clock của 8 FF `rx_byte` | 61 |
| `rx_count != 3'd7` | nội bộ | enable | Cho phép `rx_count` tăng. Khi sai ⇒ bộ đếm bão hoà | 31 |
| `rx_count == 3'd7` | nội bộ | enable | Cho phép `rx_byte` nhận `rx_shift`. Netlist: dây `_29_` (từ `nand3_1 _34_`), đảo, cấp cho `S` của 8 `mux2_1` | 62 |
| `tx_count != 3'd7` | nội bộ | enable | Cho phép `tx_shift` dịch và `miso` cập nhật. Khi sai ⇒ giữ nguyên (dòng 53–54) | 43 |
| `MSB_FIRST` | parameter | hằng thời gian biên dịch | Chọn hướng dịch. Với giá trị mặc định `1'b1`, nhánh LSB-trước bị tối ưu mất hoàn toàn | 2, 26, 45 |

---

## 3. Quan hệ điều khiển ↔ datapath

```
                        ┌────────────────────────────────────────┐
  cs_n ────────┬───────▶│ RESET bất đồng bộ: rx_shift, rx_count  │
               │        └────────────────────────────────────────┘
               │        ┌────────────────────────────────────────┐
               ├───────▶│ LOAD bất đồng bộ: tx_shift ← tx_byte   │  ← nguồn của $_ALDFFE_NPP_
               │        └────────────────────────────────────────┘
               │        ┌────────────────────────────────────────┐
               └───────▶│ CLOCK của rx_byte                      │
                        └──────────────▲─────────────────────────┘
                                       │ enable
  sclk ↑ ──▶ rx_count ──▶ [== 7?] ─────┘
                    │
                    └──▶ [!= 7?] ──▶ enable của chính rx_count  (hồi tiếp)

  sclk ↓ ──▶ tx_count ──▶ [!= 7?] ──▶ enable của tx_shift và miso
```

Đặc điểm: **mọi tín hiệu điều khiển đều xuất phát từ `cs_n` hoặc từ bộ đếm.**
Không có tín hiệu `start`, `done`, `busy`, `valid` nào — vì phía tớ **không được phép**
quyết định thời điểm; nó chỉ phản ứng.

---

## 4. Vì sao H04 không có xung nhịp hệ thống — và hệ quả

Đây là nội dung trọng tâm của Charter mục 2 câu 2 và mục 9.

| Phía chủ (master) | Phía tớ H04 |
|---|---|
| Tự sinh `sclk` từ clock nội bộ | **Nhận** `sclk` từ chân ngoài |
| `sclk` có quan hệ pha xác định với mọi FF trong chip | `sclk` **không** có quan hệ với bất cứ clock nào khác |
| Có thể dừng `sclk` bất cứ lúc nào một cách an toàn | `sclk` có thể dừng giữa chừng ⇒ trạng thái đóng băng |
| Bộ đếm bit chạy trên clock hệ thống, luôn tiến | Bộ đếm bit chỉ tiến khi **chủ** cấp sườn |

**Ba hệ quả thực tế, có bằng chứng trong hồ sơ:**

1. **Không có reset nguồn.** Vì không có clock hệ thống, cũng không có chuỗi reset hệ thống.
   RTL phải mượn `cs_n` làm reset. Nhưng `cs_n` chỉ reset khi có **sườn hoặc mức** thật ⇒
   nếu tầng ngoài giữ `cs_n = 1` từ lúc cấp nguồn mà không tạo sườn, khối **không bao giờ**
   được khởi tạo. Đây chính xác là lỗi trong `simulation.log`.

2. **Netlist có ba nhóm clock.** `netlist.v` cho thấy `dfrtp_1` dùng `.CLK(sclk)`,
   `dfrtn_1` dùng `.CLK_N(sclk)`, và `dfxtp_1` dùng `.CLK(cs_n)`. Nhưng
   `04_IMPLEMENTATION/constraints/design.sdc` chỉ khai báo **một** clock:
   ```tcl
   create_clock -name sclk -period 10.0 [get_ports sclk]
   ```
   ⇒ Ngay cả khi STA chạy được, miền `cs_n` vẫn **không** được phân tích.

3. **Đầu ra `rx_byte` là tín hiệu bất đồng bộ đối với phần còn lại của chip.**
   Nghĩa vụ đồng bộ hoá thuộc về tầng ngoài — xem `system_diagram.md` §3.

---

## 5. Trạng thái "đã xong" được giữ như thế nào

H04 không có bit `done`. Thay vào đó, **bộ đếm bão hoà đóng vai trò cờ trạng thái**:

| `rx_count` | Ý nghĩa dự định | Ý nghĩa thực tế trên RTL |
|---:|---|---|
| 0 | chưa nhận bit nào | ✅ đúng |
| 1–6 | đang nhận | ✅ đúng |
| **7** | **đã nhận đủ 8 bit** | ❌ **cũng đúng sau đúng 7 bit** — xem `functional_spec.md` §5.2 |

Đây là một thiết kế **tiết kiệm nhưng mập mờ**: dùng 3 bit để đếm 9 trạng thái (0…8).
3 bit chỉ biểu diễn được 8 giá trị. Cách sửa tối thiểu (4 bit, hoặc thêm một cờ `rx_full`)
nằm ở `05_VERIFICATION/known_issues.md` §5.

**Bài học điều khiển tổng quát:** khi một bộ đếm `n` bit vừa dùng để **đếm** vừa dùng để
**báo hoàn tất**, phải kiểm lại xem giá trị "hoàn tất" có trùng với một giá trị trung gian
hợp lệ không. Với bộ đếm bão hoà, giá trị lớn nhất **luôn** bị dùng lại — nên nó gần như
luôn mập mờ.

---

## 6. Nghĩa vụ hợp đồng của tầng ngoài (chốt lại)

| # | Nghĩa vụ | Vì sao |
|---|---|---|
| 1 | Tạo ít nhất một sườn `↑cs_n` sau khi cấp nguồn, trước giao dịch đầu tiên | Không có reset khác — xem §4 hệ quả 1 |
| 2 | Cấp đúng 8 sườn `sclk` mỗi lần `cs_n` thấp | Khối không tự phát hiện thiếu/thừa |
| 3 | Giữ `mosi` ổn định trước sườn lên (setup) | Chế độ 0, không có bộ lọc |
| 4 | Đồng bộ hoá `rx_byte` sang miền clock của mình (2 tầng FF) | `rx_byte` clock bằng `cs_n` |
| 5 | Đặt `tx_byte` ổn định **trước** khi kéo `cs_n` xuống | `tx_shift` chốt tại `↑cs_n` |
| 6 | Không tạo glitch trên `sclk` và `cs_n` | Glitch trên `sclk` bị đếm như bit; glitch trên `cs_n` sẽ **clock nhầm** `rx_byte` |

---

*Phiên bản: v1.0 · Ngày: 2026-09-24*
