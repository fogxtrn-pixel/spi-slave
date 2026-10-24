# H04 · Đặc tả chức năng (Functional Specification)

> ## ⚠️ CẢNH BÁO — MỘT SỐ YÊU CẦU CHARTER **CHƯA THOẢ**
>
> Đọc mục này trước khi dùng hồ sơ để chấm bài.
>
> | # | Yêu cầu Charter | Trạng thái | Bằng chứng |
> |---|---|---|---|
> | W-1 | Charter mục 4: ánh xạ chân Tiny Tapeout (`uio_in[0]=SCLK`, `uio_in[1]=MOSI`, `uio_in[2]=CS`, `ui_in[7:0]`, `uo_out[0]=MISO`, `uio_out[7:0]`) | ❌ **CHƯA THOẢ** | RTL `h04_spi_slave.sv` chỉ có cổng lõi `sclk/mosi/cs_n/tx_byte/miso/rx_byte`; **không có module bọc Tiny Tapeout** nào trong `04_IMPLEMENTATION/rtl/`. Xung đột `uio[0,1,2]` vừa vào vừa ra mà Charter mục 4 yêu cầu sửa **vẫn chưa được sửa** vì chưa có tầng bọc. |
> | W-2 | Charter mục 8 + mục 10: "CS nhả giữa chừng" phải không sinh byte giả | ❌ **CHƯA THOẢ** | Bộ đếm `rx_count` bão hoà tại 7 **sau 7 sườn lên**, không phải 8. Xem INV-4 và `05_VERIFICATION/known_issues.md` §5. Giao dịch 7 bit bị nhận nhầm thành byte hoàn chỉnh. |
> | W-3 | Charter mục 10: "≈20–24 ô nhớ" | ⚠️ **LỆCH** | Thực đo **30 bit nhớ** (`06_GDSII/synthesis/synth_stat.txt`): 22 ô nhớ đã ánh xạ + 8 ô `$_ALDFFE_NPP_` **chưa ánh xạ được**. Lý do lệch giải thích ở `03_ARCHITECTURE/block_diagram.md` §5. |
> | W-4 | Mô phỏng RTL phải PASS | ❌ **FAIL** | `05_VERIFICATION/simulation.log`: `RX mismatch`, `Time: 85`. Phán xử đầy đủ ở `05_VERIFICATION/known_issues.md`. |
> | W-5 | STA phải chạy được | ❌ **FAIL** | `06_GDSII/sta/sta.log`: `netlist.v line 39, syntax error`. Phán xử ở `05_VERIFICATION/known_issues.md` §6. |
>
> **Không tự sửa RTL.** Bản gốc được giữ nguyên; mọi bản vá đề xuất nằm ở `known_issues.md`
> và **cần thầy duyệt** trước khi áp dụng.

---

## 1. Khối này phải làm gì

`h04_spi_slave` là **phía tớ (slave)** của một liên kết SPI chạy **chế độ 0**
(`CPOL = 0`, `CPHA = 0`). Khối không tự sinh nhịp: `sclk` và `cs_n` đều **do phía chủ
(master) cấp từ bên ngoài**. Khối trao đổi song công (full-duplex) đúng 8 bit mỗi lần
`cs_n` được kéo xuống.

### 1.1 Quy ước chế độ 0

| Đại lượng | Giá trị chốt cho H04 | Hệ quả |
|---|---|---|
| `CPOL` | 0 — `sclk` nghỉ ở mức thấp | Sườn đầu tiên sau khi `cs_n` xuống là **sườn lên** |
| `CPHA` | 0 — lấy mẫu ở **sườn đầu tiên** | Lấy mẫu `mosi` tại **sườn lên**; đổi `miso` tại **sườn xuống** |
| Thứ tự bit | MSB trước (`MSB_FIRST = 1`, tham số) | Bit 7 đi trước, bit 0 đi cuối |
| Mức tích cực `cs_n` | Thấp | `cs_n = 1` ⇒ nghỉ / huỷ giao dịch |

### 1.2 Bảng hành vi theo sự kiện

| Sự kiện | Điều kiện | Tác động lên trạng thái |
|---|---|---|
| `cs_n` ở mức cao | bất kỳ lúc nào | `rx_shift ← 0`, `rx_count ← 0` (reset bất đồng bộ) |
| Sườn lên `cs_n` | — | `tx_shift ← tx_byte`, `tx_count ← 0`, `miso ← tx_byte[7]`; **và** nếu `rx_count == 7` thì `rx_byte ← rx_shift` |
| Sườn lên `sclk`, `cs_n = 0` | luôn | `rx_shift ← {rx_shift[6:0], mosi}`; nếu `rx_count ≠ 7` thì `rx_count ← rx_count + 1` |
| Sườn xuống `sclk`, `cs_n = 0` | `tx_count ≠ 7` | `tx_shift ← {tx_shift[6:0], 0}`, `miso ← tx_shift[6]`, `tx_count ← tx_count + 1` |
| Sườn xuống `sclk`, `cs_n = 0` | `tx_count == 7` | Giữ nguyên `tx_shift` và `miso` |

### 1.3 Định nghĩa từng đầu ra

| Đầu ra | Định nghĩa chính xác |
|---|---|
| `miso` | Bit đang được phát ra đường MISO. Nạp `tx_byte[7]` tại sườn lên `cs_n`; sau đó cập nhật tại **mỗi sườn xuống** `sclk` trong lúc `cs_n = 0`, lấy từ `tx_shift[6]`. Là **thanh ghi**, không phải tổ hợp — đường ra ổn định giữa hai sườn xuống. |
| `rx_byte[7:0]` | Byte đã nhận trọn vẹn. **Chỉ** cập nhật tại sườn lên `cs_n` và **chỉ** khi `rx_count == 7`. Ngoài thời điểm đó giữ giá trị cũ. |

---

## 2. Ràng buộc cấu trúc bắt buộc

Tên đề chỉ định **"Tớ SPI chế độ 0"**. Hai ràng buộc cấu trúc suy trực tiếp từ đó:

1. **Tách hai miền sườn.** Chế độ 0 bắt buộc đường nhận lấy mẫu ở sườn **lên** và đường
   phát đổi dữ liệu ở sườn **xuống**. RTL phải mô tả **tường minh** hai khối
   `always_ff` riêng — không được gộp vào một miền rồi bù trễ nửa chu kỳ bằng logic tổ hợp.
   *RTL hiện tại thoả:* dòng 21 `@(posedge sclk …)` và dòng 37 `@(negedge sclk …)`.
2. **Không có xung nhịp hệ thống.** Khối bị cấm dùng một `clk` nội bộ để tái tạo `sclk`;
   `sclk` **chính là** xung nhịp của khối. *RTL hiện tại thoả* — xem `03_ARCHITECTURE/control.md` §4.

Ràng buộc **không** được suy diễn thêm: Charter mục 3 liệt "nhiều mode, vượt miền xung nhịp
đầy đủ, bộ đệm sâu" vào **ngoài phạm vi**, nên khối chỉ hỗ trợ đúng mode 0, đúng 1 byte đệm.

---

## 3. Tính chất bất biến (invariants)

Dùng trực tiếp làm assertion. Ký hiệu `↑x` = sườn lên của `x`, `↓x` = sườn xuống.

| Mã | Phát biểu | Trạng thái trên RTL hiện tại |
|---|---|---|
| **INV-1** | Khi `cs_n = 1`: `rx_shift == 0` và `rx_count == 0` | ✅ đúng — reset bất đồng bộ dòng 22–24 |
| **INV-2** | Sau `k` sườn lên `sclk` liên tiếp trong một lần `cs_n = 0` (k ≤ 8), `rx_shift[k-1:0]` bằng `k` bit `mosi` gần nhất theo thứ tự MSB-trước | ✅ đúng |
| **INV-3** | `rx_byte` chỉ đổi giá trị tại `↑cs_n` | ✅ đúng — chỉ có một khối gán, `@(posedge cs_n)` |
| **INV-4** | `rx_byte` chỉ được nạp khi giao dịch đã đủ **8** bit | ❌ **SAI trên RTL hiện tại.** Điều kiện `rx_count == 3'd7` đúng **ngay sau sườn thứ 7**. Xem §5.2 |
| **INV-5** | `miso` chỉ đổi tại `↓sclk` (khi `cs_n = 0`) hoặc tại `↑cs_n` | ✅ đúng |
| **INV-6** | Trong một giao dịch, `miso` phát đúng dãy `tx_byte[7], tx_byte[6], …, tx_byte[0]` | ✅ đúng (kiểm bằng tay trên mã; testbench **chưa** kiểm — xem `corner_cases.md` §4) |
| **INV-7** | `tx_count` và `rx_count` không bao giờ vượt 7 | ✅ đúng — cả hai đều có chốt `!= 3'd7` |
| **INV-8** | Sau reset nguồn (chưa có sườn `↑cs_n` nào), `rx_count` phải xác định | ❌ **SAI.** `rx_count` kẹt `3'bxxx` — đây chính là lỗi mô phỏng, xem `known_issues.md` |

Cách kiểm INV-1, INV-3, INV-5 bằng SVA đã gợi ý trong `05_VERIFICATION/testbench/properties.sv`
(hiện chỉ có một property khung, chưa đủ).

---

## 4. Độ trễ tính theo sườn

| Từ | Tới | Độ trễ |
|---|---|---|
| Bit `mosi` thứ `i` ổn định | Bit đó nằm trong `rx_shift` | 1 sườn lên `sclk` |
| Sườn lên `sclk` thứ 8 | `rx_byte` hợp lệ | Phải chờ tới `↑cs_n` — **không** có số chu kỳ cố định; do chủ quyết định |
| `↑cs_n` (nạp `tx_byte`) | `miso` mang `tx_byte[7]` | 0 sườn `sclk` — nạp ngay tại `↑cs_n` |
| Sườn xuống `sclk` thứ `k` | `miso` mang `tx_byte[7-k]` | 1 sườn xuống |

Tổng một giao dịch: **8 sườn lên + 8 sườn xuống** của `sclk`, cộng một `↑cs_n` để chốt
`rx_byte`. Khối **không** có khái niệm "số chu kỳ hệ thống" vì không có xung nhịp hệ thống.

---

## 5. Điều kiện biên và hành vi không xác định

### 5.1 Trạng thái sau khi cấp nguồn

Khối **không có cổng reset**. Trạng thái ban đầu của `rx_shift`, `rx_count`, `tx_shift`,
`tx_count`, `miso`, `rx_byte` là **không xác định** cho tới khi có sườn `↑cs_n` đầu tiên.
Nghĩa vụ hợp đồng của tầng ngoài: **phải tạo ít nhất một sườn lên thật của `cs_n`**
(kéo `cs_n` xuống rồi lên, hoặc đưa `cs_n` từ 0 lên 1) **trước** giao dịch đầu tiên.
Testbench hiện tại **không** làm điều này — đó là nguyên nhân trực tiếp của lỗi mô phỏng.

### 5.2 CS nhả giữa chừng — điều kiện biên quan trọng nhất của đề

| Số sườn lên đã nhận khi `cs_n` lên | `rx_count` lúc đó | `rx_byte` có bị nạp không? | Đúng hay sai |
|---:|---:|---|---|
| 0 | 0 | không | ✅ đúng |
| 1…6 | 1…6 | không | ✅ đúng |
| **7** | **7** | **CÓ** | ❌ **SAI** — byte chỉ có 7 bit, bit cao nhất là rác của lần dịch trước |
| 8 | 7 | có | ✅ đúng |
| >8 | 7 | có | ⚠️ nhận 8 bit **cuối cùng**, bit đầu bị đẩy ra ngoài |

Hàng "7" là lỗ hổng thật. `rx_count` chỉ có 3 bit nên không phân biệt được "đã đếm 7"
với "đã đếm 8 và bão hoà". Bản vá tối thiểu ở `known_issues.md` §5.

### 5.3 Các trường hợp khác

| Tình huống | Hành vi RTL | Ghi chú |
|---|---|---|
| `tx_byte` đổi **trong lúc** `cs_n = 0` | Không ảnh hưởng — `tx_shift` đã chốt tại `↑cs_n` | ✅ Đúng thiết kế |
| Sườn `sclk` xuất hiện khi `cs_n = 1` | Bị chặn: mức `cs_n = 1` giữ reset bất đồng bộ đè lên | ✅ An toàn |
| `sclk` có glitch | **Bị đếm như một bit thật** | ⚠️ Không có bộ lọc; nghĩa vụ của tầng ngoài |
| `mosi` đổi quá gần sườn lên | Vi phạm setup của `dfrtp_1` — kết quả bất định | ⚠️ Không thể kiểm bằng mô phỏng hành vi |
| Sườn `↑cs_n` và sườn `↑sclk` trùng nhau | Reset bất đồng bộ thắng (mức `cs_n` được kiểm trước) | Mô phỏng zero-delay cho kết quả tất định; **phần cứng thật thì không** |
| Hơn 8 sườn trong một lần `cs_n` thấp | `rx_shift` tiếp tục dịch; `tx_shift` dừng, `miso` giữ nguyên | Hành vi hợp lý nhưng **chưa có ca kiểm thử** |

---

## 6. Những gì đặc tả này **không** quy định

- Tốc độ `sclk` tối đa — phải có STA chạy được mới nói được, mà STA đang FAIL.
- Hành vi khi có nhiều tớ trên cùng bus — ngoài phạm vi Charter mục 3.
- Giao thức lệnh/địa chỉ ở tầng trên (khối này chỉ là tầng liên kết byte).

---

*Phiên bản: v1.0 · Ngày: 2026-09-24*
