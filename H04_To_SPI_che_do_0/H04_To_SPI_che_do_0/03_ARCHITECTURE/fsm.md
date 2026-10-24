# H04 · Máy trạng thái (FSM)

---

## 1. Kết luận: H04 **không có FSM tường minh** — nhưng có trạng thái

Cần phân biệt hai khái niệm mà sinh viên hay lẫn:

| Khái niệm | H04 có không? |
|---|---|
| **Trạng thái** (state) — mạch nhớ được quá khứ | ✅ **CÓ**, 30 bit nhớ |
| **FSM tường minh** — một biến `state` với tập trạng thái có tên, bảng chuyển, và `case` | ❌ **KHÔNG** |

H04 là **mạch tuần tự không có FSM**. Trạng thái của nó được mã hoá **trực tiếp bằng dữ
liệu**: nội dung thanh ghi dịch và giá trị bộ đếm, chứ không bằng một biến điều khiển riêng.

---

## 2. Bằng chứng

### 2.1 Bằng chứng từ RTL

| Dấu hiệu của FSM | Có trong `h04_spi_slave.sv` không? |
|---|---|
| `typedef enum … state_t;` | ❌ không có — file không có từ khoá `enum` |
| Biến `state` / `next_state` | ❌ không có |
| Khối `case (state) … endcase` | ❌ không có — file không có từ khoá `case` |
| Nhánh `default:` xử lý trạng thái bất hợp lệ | ❌ không có |
| Gán `state <= …` | ❌ không có |

Toàn bộ điều khiển chỉ gồm **ba `if`** trên `cs_n`, `rx_count`, `tx_count`
(dòng 22, 31, 43, 62).

### 2.2 Bằng chứng từ công cụ

`06_GDSII/synthesis/yosys.log` dòng 155–159:

```
5.1. Executing FSM_DETECT pass (finding FSMs in design).

5.2. Executing FSM_EXTRACT pass (extracting FSM from design).

5.3. Executing FSM_OPT pass (simple optimizations of FSMs).
```

Ba pass này chạy nhưng **không in ra dòng "Found FSM" nào**, và `synth_stat.txt` không có
cell `$fsm` nào. Yosys **không tìm thấy** cấu trúc FSM để trích xuất và mã hoá lại.

### 2.3 Bằng chứng từ netlist

`netlist.v` có 22 FF đã ánh xạ, chia thành ba nhóm theo **chức năng dữ liệu**, không nhóm
nào là thanh ghi trạng thái:

| Nhóm | Cell | Số lượng | Vai trò |
|---|---|---:|---|
| `rx_shift[0..7]` | `dfrtp_1 _86_…_93_` | 8 | dữ liệu |
| `rx_count[0..2]` | `dfrtp_1 _83_…_85_` | 3 | **đếm** — gần nhất với "trạng thái" |
| `tx_count[0..2]` | `dfrtn_1 _80_…_82_` | 3 | **đếm** |
| `rx_byte[0..7]` | `dfxtp_1 _64_…_71_` | 8 | dữ liệu |
| `tx_shift[0..6]`, `miso` | `$_ALDFFE_NPP_` | 8 | dữ liệu (chưa ánh xạ) |

---

## 3. Máy trạng thái **ngầm** — vẽ ra để dạy

Dù không có FSM tường minh, hành vi của H04 **tương đương** một máy 10 trạng thái. Vẽ ra
để thấy bộ đếm bão hoà đang đóng vai gì:

```
                  cs_n = 1 (mức)  ⇒ về IDLE từ MỌI trạng thái
        ┌──────────────────────────────────────────────────────────┐
        │                                                          │
        ▼                                                          │
   ┌─────────┐   cs_n↓    ┌─────────┐  ↑sclk  ┌─────────┐        ┌─────────┐
   │  IDLE   │──────────▶│  BIT 0  │────────▶│  BIT 1  │─ … ──▶│  BIT 7  │
   │ cnt = 0 │            │ cnt = 1 │         │ cnt = 2 │        │ cnt = 7 │
   └─────────┘            └─────────┘         └─────────┘        └────┬────┘
        ▲                                                             │ ↑sclk
        │                                                             ▼
        │                                                       ┌──────────┐
        │  cs_n↑  (nạp rx_byte nếu cnt == 7)                     │   FULL   │
        └────────────────────────────────────────────────────────│ cnt = 7  │
                                                                 └──────────┘
                                                                  ▲ ↑sclk (giữ nguyên)
                                                                  └──── thừa sườn
```

### ⚠️ Chỗ hỏng lộ ra ngay trên sơ đồ

Trạng thái `BIT 7` (đã nhận 7 bit) và trạng thái `FULL` (đã nhận ≥ 8 bit) **có cùng mã
`cnt = 7`**. Máy trạng thái ngầm này **không phân biệt được hai trạng thái khác nhau về
ngữ nghĩa** — vì 3 bit chỉ mã hoá được 8 giá trị trong khi cần 9 (0…8).

Nếu RTL viết FSM tường minh với `enum {IDLE, BIT0…BIT7, FULL}`, tool sẽ cấp 4 bit và lỗi
này **không thể xảy ra**. Đây là lập luận mạnh nhất cho việc "viết FSM tường minh" trong
bài giảng.

---

## 4. Bảng chuyển trạng thái ngầm (đầy đủ)

Biến trạng thái: `rx_count[2:0]`. Đầu vào: mức `cs_n`, sườn `sclk`.

| Trạng thái hiện tại | Sự kiện | Trạng thái kế | Đầu ra phụ |
|---|---|---|---|
| bất kỳ | `cs_n = 1` (mức) | `cnt = 0` | `rx_shift ← 0` |
| `cnt = k`, `k < 7` | `↑sclk`, `cs_n = 0` | `cnt = k+1` | `rx_shift` dịch |
| `cnt = 7` | `↑sclk`, `cs_n = 0` | `cnt = 7` (bão hoà) | `rx_shift` **vẫn dịch** |
| `cnt = k`, `k ≠ 7` | `↑cs_n` | `cnt = 0` | `rx_byte` **giữ nguyên** ✅ |
| `cnt = 7` | `↑cs_n` | `cnt = 0` | `rx_byte ← rx_shift` ⚠️ kể cả khi mới có 7 bit |

Máy này là **Mealy** hay **Moore**?
- Xét `rx_byte`: nó phụ thuộc `rx_count` (trạng thái) **và** sườn `cs_n` (đầu vào) ⇒ **Mealy**.
- Xét `rx_shift`: phụ thuộc trạng thái và `mosi` (đầu vào) ⇒ cũng **Mealy**.

Nhưng vì cả hai đều được **chốt vào thanh ghi**, đầu ra ra ngoài là ổn định giữa các sườn —
đây là dạng "Mealy có thanh ghi đầu ra", tương đương Moore trễ một chu kỳ về mặt giao diện.

---

## 5. Xử lý trạng thái bất hợp lệ

| Câu hỏi | Trả lời |
|---|---|
| `rx_count` có giá trị bất hợp lệ nào không? | Về mã 3 bit thì **không** — cả 8 giá trị 0…7 đều hợp lệ |
| Vậy có cần `default` không? | Không cần cho `rx_count`. **Nhưng** cần cho trạng thái **chưa khởi tạo** (`3'bxxx`) |
| RTL có xử lý `3'bxxx` không? | ❌ **Không.** Và đây là nguyên nhân lỗi mô phỏng: `rx_count = 3'bxxx` làm cả `!= 3'd7` lẫn `== 3'd7` cho kết quả `x`, khiến bộ đếm **kẹt vĩnh viễn ở X**. Xem `known_issues.md` §3 |
| Thanh ghi dịch có tự thoát X không? | ✅ **Có** — `rx_shift` tự sạch sau 8 lần dịch vì X bị đẩy ra ngoài. **Bộ đếm thì không**, vì nó có vòng hồi tiếp `cnt + 1` |

> 🔎 **Điểm dạy học rất đáng nhớ:** thanh ghi dịch tự làm sạch X, bộ đếm thì không.
> Đây là lý do mọi bộ đếm đều **phải** có reset, còn thanh ghi dịch thì đôi khi có thể bỏ.

---

## 6. Khi nào FSM sẽ xuất hiện trong bài toán này

| Nếu thêm yêu cầu | FSM cần thiết vì |
|---|---|
| Hỗ trợ cả 4 chế độ SPI (CPOL/CPHA) | Cần chọn sườn lấy mẫu theo mode ⇒ trạng thái cấu hình |
| Giao thức lệnh (byte 0 = opcode, byte 1..n = dữ liệu) | Cần trạng thái `CMD` / `ADDR` / `DATA` |
| Đệm FIFO nhiều byte | Cần trạng thái `EMPTY` / `PARTIAL` / `FULL` / `OVERRUN` |
| Sửa lỗ hổng "7 bit bị nhận nhầm" một cách tường minh | Cần `enum {IDLE, RECEIVING, COMPLETE}` — bản vá đơn giản hơn ở `known_issues.md` §5 |

Cả bốn đều bị Charter mục 3 liệt vào **ngoài phạm vi** (mode nhiều, bộ đệm sâu), trừ mục
cuối. Nên với đề H04 đúng phạm vi, **không có FSM là lựa chọn hợp lý** — miễn là bộ đếm
được đặt đủ rộng và được reset đúng.

---

*Phiên bản: v1.0 · Ngày: 2026-09-24*
