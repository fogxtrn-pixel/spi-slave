# H04 · Giao diện (Interface)

---

## 1. Ánh xạ chân theo Charter (mục 4)

> Theo danh mục đề: uio_in[0]=SCLK · uio_in[1]=MOSI · uio_in[2]=CS · ui_in[7:0]=byte sẽ gửi · uo_out[0]=MISO · uio_out[7:0]=byte nhận
> Ngân sách chân: 11 bit vào + 9 bit ra = 20 trên 24 chân.
> Lỗi ánh xạ cần sửa trước khi thiết kế: chân uio[0, 1, 2] bị gán vừa làm đầu vào vừa làm đầu ra. Tổng bit vẫn trong 24 chân nên chỉ cần đánh số lại.
> Một ô Tiny Tapeout có đúng 24 chân: ui_in 8 chỉ vào, uo_out 8 chỉ ra, uio 8 chọn chiều từng chân. uio_in và uio_out là cùng một bộ chân vật lý.

## 2. Bảng giao diện đã CHỐT — module `h04_spi_slave`

Bảng dưới đây **đọc trực tiếp từ RTL** (`04_IMPLEMENTATION/rtl/`), không phải chép tay,
nên luôn nhất quán với mã nguồn.

| Tín hiệu | Chiều | Độ rộng (bit) | Vai trò | Mức tích cực / giả định |
|---|---|---:|---|---|
| `sclk` | input | 1 | clock | |
| `mosi` | input | 1 | dữ liệu vào | |
| `cs_n` | input | 1 | dữ liệu vào | |
| `tx_byte[7:0]` | input | 8 | dữ liệu vào | |
| `miso` | output | 1 | kết quả ra | |
| `rx_byte[7:0]` | output | 8 | kết quả ra | |

**Tổng hợp:** 4 cổng vào (11 bit) · 2 cổng ra (9 bit).

**Clock:** `sclk`

**Không có reset** — không có trạng thái để đặt lại.

## 3. Ngân sách chân Tiny Tapeout

| Hạng mục | Số bit |
|---|---:|
| Tổng bit vào | **11** |
| Tổng bit ra | **9** |
| **Tổng cộng** | **20** |
| Ô Tiny Tapeout có | **24** |
| **Chênh lệch** | **4 chân còn dư** |

> Nhắc lại cấu trúc chân Tiny Tapeout: một ô có đúng 24 chân — `ui_in` 8 chỉ vào,
> `uo_out` 8 chỉ ra, `uio` 8 chọn chiều từng chân; **`uio_in` và `uio_out` là cùng một bộ
> chân vật lý**.

> ✅ Ngân sách chân **đủ**: tổng số bit logic nằm trong 24 chân vật lý, không cần
> nạp nhiều nhịp và không phải hy sinh tín hiệu nào.

## 4. Điều kiện hợp lệ của đầu vào

| Điều kiện | Ai bảo đảm |
|---|---|
| Các cổng vào không chứa `X`/`Z` khi lấy mẫu | Tầng ngoài |
| Tín hiệu vào đồng bộ với `sclk` hoặc đã qua bộ đồng bộ | Tầng ngoài |
| Chuỗi reset được giữ đủ dài trước khi bắt đầu hoạt động | Tầng ngoài |

---

*Phiên bản: v1.0 · Ngày: 2026-09-24 · Truy vết: REQ-H04-002, AC-1.*
