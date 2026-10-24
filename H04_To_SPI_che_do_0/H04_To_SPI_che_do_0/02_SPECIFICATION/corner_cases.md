# H04 · Ca biên và lý do chọn (Corner Cases)

Tài liệu này **không** chỉ liệt kê ca kiểm thử. Mỗi ca kèm **lý do kỹ thuật**: nó đánh vào
cơ chế nào của mạch, và nếu bỏ qua thì lỗi gì sẽ lọt.

Testbench thật đang có: `05_VERIFICATION/testbench/h04_spi_slave_tb.sv` (51 dòng).
Mô hình chuẩn: `05_VERIFICATION/golden_model/reference_model.py`.

---

## 1. Ca bắt buộc theo Charter mục 8

| Mã | Ca | Vì sao ca này tồn tại (cơ chế bị đánh) | Có trong TB? | Bằng chứng |
|---|---|---|---|---|
| CC-1 | Giao dịch trọn vẹn 8 bit | Kiểm đồng thời: thứ tự MSB-trước, đúng 8 sườn, và chính sách chốt `rx_byte` tại `↑cs_n`. Là ca cơ sở — mọi ca khác chỉ có nghĩa khi ca này đúng. | ✅ TB dòng 29–34 (`8'h3C`) | **Đang FAIL** — `simulation.log` |
| CC-2 | CS nhả giữa chừng | Charter mục 10 gọi đây là "chỗ hay tắc". Đánh vào **hai** cơ chế: (a) reset bất đồng bộ có xoá sạch `rx_shift`/`rx_count` không, (b) chốt `rx_byte` có từ chối byte dở dang không. | ⚠️ TB dòng 37–39 nhưng **chỉ 3 bit** | Xem §3, ca TC-3 |
| CC-3 | Hai giao dịch liên tiếp | Đánh vào **rò rỉ trạng thái** giữa hai lần `cs_n` thấp: `rx_shift` của lần trước có lẫn vào lần sau không, `tx_shift` có nạp lại `tx_byte` không. | ✅ TB dòng 42–46 (`8'hA5`) | Ca này **PASS** trong mô phỏng thật — xem §5 |
| CC-4 | SCLK chậm và nhanh | Khối không có xung nhịp hệ thống, nên **về mặt hàm logic, tốc độ `sclk` không ảnh hưởng gì** — chỉ ảnh hưởng tới setup/hold của phần cứng thật. Giá trị của ca này nằm ở **gate-level**, không phải RTL. | ❌ TB dùng cố định `#5`/`#5` | Xem §6 |

> 🔎 **Điểm cần mentor lưu ý:** CC-1 và CC-3 dùng **cùng một cơ chế** nhưng CC-1 fail còn
> CC-3 pass. Sự bất đối xứng này chính là chìa khoá phán xử lỗi — xem `known_issues.md` §3.

---

## 2. Phân loại ca theo tiêu chí riêng của H04

H04 không có chuỗi carry hay nhánh FSM để phân loại theo. Tiêu chí tự nhiên của một khối
SPI tớ là **số sườn nhận được trước khi `cs_n` nhả**, vì đó là biến điều khiển duy nhất
của chính sách chốt dữ liệu.

```
  số sườn lên n trong một lần cs_n thấp
  │
  ├─ n = 0        → lớp "không giao dịch"      (CS nhấp nháy)
  ├─ 1 ≤ n ≤ 6    → lớp "huỷ giữa chừng - an toàn"
  ├─ n = 7        → lớp "huỷ giữa chừng - NGUY HIỂM"   ← lỗ hổng INV-4
  ├─ n = 8        → lớp "giao dịch hợp lệ"     (ca danh nghĩa)
  └─ n > 8        → lớp "thừa sườn"            (chủ đếm sai)
```

Mỗi lớp phải có ít nhất một ca. Hiện TB chỉ phủ `n = 3` và `n = 8`.

| Lớp | Phủ bởi | Trạng thái |
|---|---|---|
| n = 0 | — | ❌ thiếu |
| 1 ≤ n ≤ 6 | TB dòng 38 (`n = 3`) | ✅ có |
| **n = 7** | — | ❌ **thiếu — đây là ca quan trọng nhất còn trống** |
| n = 8 | TB dòng 31, 43 | ✅ có |
| n > 8 | — | ❌ thiếu |

---

## 3. Ca tự xây dựng bổ sung (bắt buộc ≥ 2, phải có ca biên)

### TC-3 — CS nhả sau đúng **7** sườn ⭐ ca biên quan trọng nhất

**Vì sao:** tách bạch "đếm đủ 8" với "bộ đếm bão hoà". Bộ đếm 3 bit đạt giá trị 7 sau sườn
thứ 7 và **giữ nguyên 7** ở sườn thứ 8, nên điều kiện `rx_count == 3'd7` không phân biệt
được hai trường hợp. Không có ca này thì lỗi hoàn toàn vô hình.

```
 cs_n ‾‾‾\_______________________________________/‾‾‾
 sclk  ___|‾|_|‾|_|‾|_|‾|_|‾|_|‾|_|‾|_______________     ← đúng 7 sườn lên
 mosi  ---< 1 >< 0 >< 1 >< 1 >< 0 >< 1 >< 0 >---------
                                            ↑ cs_n lên tại đây
 Kỳ vọng : rx_byte GIỮ NGUYÊN giá trị cũ
 Thực tế : rx_byte bị nạp = {rác_cũ, 1,0,1,1,0,1,0}     ← SAI
```

**Cách phát hiện:** so `rx_byte` trước và sau `↑cs_n`; phải bằng nhau.

### TC-4 — Kiểm đường phát `miso` (song công)

**Vì sao:** TB hiện tại **không hề đọc `miso`**. Toàn bộ nửa phát của khối — 8 ô nhớ
`tx_shift`, 3 ô `tx_count`, 1 ô `miso`, tức **12/30 ô nhớ** — đang không được kiểm chứng
bởi bất kỳ assertion nào. Đây là lỗ hổng phủ lớn nhất của hồ sơ.

```
 Nạp tx_byte = 8'h96 = 1001_0110
 Kỳ vọng miso tại 8 sườn LÊN liên tiếp: 1,0,0,1,0,1,1,0
 (miso đổi tại sườn xuống, nên chủ đọc nó tại sườn lên kế tiếp)
```

### TC-5 — Nhấp nháy `cs_n` không kèm sườn `sclk` nào

**Vì sao:** kiểm INV-1 và INV-3 ở trạng thái rỗng. Một `↑cs_n` với `rx_count == 0` **không**
được phép đổi `rx_byte`. Đây cũng là ca duy nhất kiểm được "reset bất đồng bộ có đặt
`rx_count` về 0 thật không" — và là ca **lẽ ra đã cứu được lỗi mô phỏng hiện tại** nếu nó
được đặt ở **đầu** testbench.

### TC-6 — Thừa sườn (`n = 12`)

**Vì sao:** khi chủ đếm sai, khối phải nhận **8 bit cuối**, không được treo. Kiểm rằng
`rx_shift` vẫn dịch bình thường còn `tx_shift`/`miso` đã dừng ở `tx_count == 7`.

### TC-7 — `tx_byte` đổi giữa giao dịch

**Vì sao:** kiểm rằng `tx_shift` đã **chốt** tại `↑cs_n`, không phải đọc `tx_byte` liên tục.
Nếu ai đó sửa dòng 41 thành gán tổ hợp, ca này sẽ bắt được ngay.

---

## 4. Ca **KHÔNG** áp dụng cho đề này — và vì sao

| Ca thường gặp | Vì sao không áp dụng cho H04 |
|---|---|
| Kiểm chuỗi reset đồng bộ | Khối **không có** cổng `rst_n`. Vai trò reset do mức `cs_n = 1` đảm nhiệm. Xem `interface.md` §2. |
| Kiểm các chế độ SPI 1/2/3 | Charter mục 3 liệt "nhiều mode" vào **ngoài phạm vi**. `MSB_FIRST` là tham số duy nhất, và cũng không phải mode SPI. |
| Kiểm tràn/underflow bộ đệm | Khối chỉ có **1 byte** đệm mỗi chiều. Charter mục 3: "bộ đệm sâu" ngoài phạm vi. |
| Kiểm vượt miền xung nhịp (CDC) giữa `sclk` và `clk` hệ thống | Khối **không có** xung nhịp hệ thống — `sclk` chính là clock. CDC sẽ xuất hiện ở **tầng bọc**, không ở khối này. Charter mục 3 cũng liệt "vượt miền xung nhịp đầy đủ" là ngoài phạm vi. |
| Kiểm nhiều tớ / tranh chấp MISO | Không có cổng ba trạng thái trong RTL; `miso` là đầu ra thường. Tầng ngoài phải tự làm tri-state. |
| Kiểm `MSB_FIRST = 0` | Nhánh LSB-trước **có trong RTL** (dòng 29, 49–50) nhưng Charter mục 4 chốt MSB-trước. Nhánh này là mã chết trong cấu hình hiện tại — nên **hoặc** kiểm nó, **hoặc** xoá nó. Hiện tại nó không được kiểm và cũng không bị xoá. |

---

## 5. Đọc testbench thật: cái gì đã có, cái gì còn thiếu

| Dòng TB | Nội dung | Nhận xét |
|---|---|---|
| 2 | `logic sclk=0, mosi=0, cs_n=1;` | ⚠️ Khởi tạo khai báo **không sinh sự kiện sườn** ⇒ khối không bao giờ được reset trước giao dịch đầu. **Nguyên nhân gốc của lỗi.** |
| 11–18 | `task spi_bit` — đặt `mosi`, rồi `#5 sclk=1; #5 sclk=0;` | ✅ Đúng chế độ 0: dữ liệu ổn định **trước** sườn lên |
| 29–34 | Giao dịch trọn vẹn `8'h3C`, assert `rx_byte` | ❌ FAIL tại `t = 85` |
| 37–39 | Huỷ giữa chừng, **3 bit** | ⚠️ Không có assertion nào sau ca này. Chỉ 3 bit ⇒ không chạm lỗ hổng `n = 7` |
| 42–46 | Giao dịch thứ hai `8'hA5`, assert | ✅ PASS (đã kiểm bằng chạy lại có `$monitor`) |
| — | Kiểm `miso` | ❌ **hoàn toàn không có** |
| — | Kiểm ở `n = 0` và `n = 7` | ❌ không có |

Về mô hình chuẩn Python (`reference_model.py`): nó **PASS** (`python_reference_run.log`)
nhưng cần đọc kỹ giới hạn của nó — 7 hàm test đều thao tác trên **danh sách bit thuần**,
không mô hình hoá sườn, không mô hình hoá `cs_n`, không mô hình hoá bộ đếm.
`test_abort()` (dòng 29–34) chỉ khẳng định `len(received) != 8`; nó **không thể** phát hiện
lỗi bão hoà bộ đếm vì trong mô hình Python không tồn tại bộ đếm nào cả.
👉 **Bài học:** mô hình chuẩn PASS **không** chứng minh DUT đúng, nếu mô hình chuẩn không
mô hình hoá đúng cơ chế cần kiểm.

---

## 6. Ca cần bổ sung khi chuyển sang gate-level / post-layout

| Ca | Vì sao chỉ có nghĩa sau tổng hợp |
|---|---|
| Kiểm setup/hold của `mosi` quanh `↑sclk` | Mô phỏng RTL là **zero-delay**: mọi giá trị đến kịp. Chỉ netlist + SDF mới lộ vi phạm. |
| `↑cs_n` trùng `↑sclk` | Ở RTL, reset bất đồng bộ thắng một cách tất định. Trên `dfrtp_1` thật, đây là **vi phạm recovery/removal** ⇒ có thể metastable. Cần kiểm bằng STA (`-check_recovery`), mà STA đang FAIL. |
| `sclk` chậm (CC-4 phía chậm) | Với `sclk` rất chậm, rò rỉ và nhiễu mới thành vấn đề — chỉ đo được sau P&R. |
| `sclk` nhanh (CC-4 phía nhanh) | Cần WNS thật để biết chu kỳ tối thiểu. **Chưa có** vì STA FAIL. |
| Kiểm 3 miền nhịp (`↑sclk`, `↓sclk`, `↑cs_n`) không tranh chấp | Netlist dùng `dfrtp_1` (11), `dfrtn_1` (3), `dfxtp_1` clock bằng **`cs_n`** (8). `cs_n` vừa là clock vừa là reset — phải kiểm bằng STA đa clock, hiện chưa làm được. |
| Kiểm 8 ô `$_ALDFFE_NPP_` sau khi được ánh xạ lại | Tám ô này **chưa phải cell thật**. Mọi kết luận gate-level về nửa phát đều chưa có cơ sở cho tới khi vá theo `known_issues.md` §6. |

---

*Phiên bản: v1.0 · Ngày: 2026-09-24*
