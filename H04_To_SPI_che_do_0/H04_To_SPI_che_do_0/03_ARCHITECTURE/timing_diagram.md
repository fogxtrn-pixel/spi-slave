# H04 · Giản đồ thời gian (Timing Diagram)

Mọi giản đồ dưới đây **đọc từ RTL thật** (`h04_spi_slave.sv`) và được đối chiếu với mô
phỏng Icarus Verilog thực chạy. Vì H04 không có xung nhịp hệ thống, **đơn vị đánh số là
"sườn `sclk`"**, không phải "chu kỳ clock".

> ⚠️ **Đây là mô phỏng hành vi (zero-delay).** Mọi tín hiệu đổi **đúng** tại sườn, không có
> `tCO`, không có trễ dây, không có slew. Giản đồ này chứng minh **thứ tự và số lượng sự
> kiện**, **không** chứng minh mạch chạy được ở tốc độ nào. Muốn có số thật cần STA —
> mà STA đang FAIL (`06_GDSII/sta/sta.log`).

---

## 1. Một khung truyền đầy đủ — giản đồ chuẩn (hành vi đúng)

Điều kiện: `MSB_FIRST = 1`, `tx_byte = 8'h96` (`1001_0110`),
chủ gửi `mosi = 8'h3C` (`0011_1100`).
Có **sườn `↑cs_n` khởi tạo** trước giao dịch (bắt buộc — xem §3).

```
 mốc:      POR   ┊  IDLE ┊ B7  ┊ B6  ┊ B5  ┊ B4  ┊ B3  ┊ B2  ┊ B1  ┊ B0  ┊ END
 sườn ↑sclk:     ┊       ┊ #1  ┊ #2  ┊ #3  ┊ #4  ┊ #5  ┊ #6  ┊ #7  ┊ #8  ┊
                 ┊       ┊     ┊     ┊     ┊     ┊     ┊     ┊     ┊     ┊
 cs_n  ____/‾‾‾‾‾\_______________________________________________________/‾‾‾‾
           ↑A            ↑B                                              ↑E
                 ┊       ┊     ┊     ┊     ┊     ┊     ┊     ┊     ┊     ┊
 sclk  ________________┌─┐___┌─┐___┌─┐___┌─┐___┌─┐___┌─┐___┌─┐___┌─┐_________
                       │1│   │2│   │3│   │4│   │5│   │6│   │7│   │8│
                       └─┘   └─┘   └─┘   └─┘   └─┘   └─┘   └─┘   └─┘
                        ↑     ↑     ↑     ↑     ↑     ↑     ↑     ↑
                     lấy mẫu mosi tại SƯỜN LÊN  (CPHA = 0)
                          ↓     ↓     ↓     ↓     ↓     ↓     ↓     ↓
                        đổi miso tại SƯỜN XUỐNG
                 ┊       ┊     ┊     ┊     ┊     ┊     ┊     ┊     ┊     ┊
 mosi  ══════════╪═══════╪══0══╪══0══╪══1══╪══1══╪══1══╪══1══╪══0══╪══0══╪════
       (chủ lái) ┊       ┊ b7  ┊ b6  ┊ b5  ┊ b4  ┊ b3  ┊ b2  ┊ b1  ┊ b0  ┊
                 ┊       ┊     ┊     ┊     ┊     ┊     ┊     ┊     ┊     ┊
 miso  ══════════╪══1════╪══1══╪══0══╪══0══╪══1══╪══0══╪══1══╪══1══╪══0══╪═1══
       (tớ lái)  ┊ nạp   ┊ b7  ┊ b6  ┊ b5  ┊ b4  ┊ b3  ┊ b2  ┊ b1  ┊ b0  ┊nạp
                 ┊ 9 6 → 1001_0110                                       ┊ lại
                 ┊       ┊     ┊     ┊     ┊     ┊     ┊     ┊     ┊     ┊
 rx_count ═══0═══╪═══0═══╪══1══╪══2══╪══3══╪══4══╪══5══╪══6══╪══7══╪══7══╪══0═
                 ┊       ┊     ┊     ┊     ┊     ┊     ┊     ┊  ▲  ┊  ▲  ┊
                 ┊       ┊     ┊     ┊     ┊     ┊     ┊     ┊  │  ┊  │  ┊
                 ┊       ┊  đạt 7 sau sườn #7 ──────────────────┘  │  ┊
                 ┊       ┊  BÃO HOÀ, không đổi ở sườn #8 ──────────┘  ┊
                 ┊       ┊     ┊     ┊     ┊     ┊     ┊     ┊     ┊     ┊
 rx_shift ═══00══╪══00═══╪═00══╪═00══╪═01══╪═03══╪═07══╪═0f══╪═1e══╪═3c══╪═00═
                 ┊       ┊     ┊     ┊     ┊     ┊     ┊     ┊     ┊  ▲  ┊
                 ┊       ┊     ┊     ┊     ┊     ┊     ┊     ┊     ┊  └─ đủ 8 bit
                 ┊       ┊     ┊     ┊     ┊     ┊     ┊     ┊     ┊     ┊
 tx_shift ═══96══╪══96═══╪═2c══╪═58══╪═b0══╪═60══╪═c0══╪═80══╪═00══╪═00══╪═96═
                 ┊ (nạp tại ↑A)    dịch trái tại mỗi SƯỜN XUỐNG       ┊(nạp lại)
                 ┊       ┊     ┊     ┊     ┊     ┊     ┊     ┊     ┊     ┊
 rx_byte  ═══XX══╪══XX═══╪═XX══╪═XX══╪═XX══╪═XX══╪═XX══╪═XX══╪═XX══╪═XX══╪═3C═
                 ┊       ┊     ┊     ┊     ┊     ┊     ┊     ┊     ┊     ┊  ▲
                 ┊       ┊     ┊     ┊     ┊     ┊     ┊     ┊     ┊     ┊  └─ chốt tại ↑E
```

### Chú giải ba mốc

| Mốc | Sự kiện | Việc RTL làm | Dòng |
|---|---|---|---|
| **↑A** | Sườn lên `cs_n` khi cấp nguồn (POR) | `rx_shift←0`, `rx_count←0`, `tx_shift←tx_byte`, `tx_count←0`, `miso←tx_byte[7]` | 22–24, 38–41 |
| **↑B** | `cs_n` xuống — bắt đầu giao dịch | Chỉ mở khoá; không có hành động nào tại sườn xuống | — |
| **↑E** | `cs_n` lên — kết thúc | `rx_byte ← rx_shift` (vì `rx_count == 7`), đồng thời reset lại tất cả | 61–63 |

### Số liệu thật lấy từ mô phỏng

Giá trị `rx_shift` và `tx_shift` trong giản đồ là **giá trị đo được**, không phải suy diễn:
`00 → 00 → 01 → 03 → 07 → 0f → 1e → 3c` (nhận) và
`96 → 2c → 58 → b0 → 60 → c0 → 80 → 00` (phát).
`miso` tại 8 sườn lên = `1,0,0,1,0,1,1,0` = `0x96` ✅ — **đường phát hoạt động đúng**.

---

## 2. Quan hệ pha chế độ 0 — phóng to một ô bit

```
                  ← một ô bit →
 sclk    ______________┌───────┐_______________┌────
                       │       │               │
                       └───────┘               └────
                       ↑       ↓               ↑
                    LẤY MẪU  ĐỔI DỮ LIỆU     LẤY MẪU
                     mosi      miso            mosi

 mosi    ─────<══════ ổn định ══════>─────< bit sau >──
              ↑                     ↑
              │← setup (tớ yêu cầu) │← hold
              │
         chủ đặt bit ở đây (trước sườn lên)

 miso    ═════ bit k ═══════════════>< bit k+1 ═══════
                              đổi ngay tại sườn xuống
```

Quy tắc chế độ 0 mà giản đồ chứng minh:
- **`mosi` phải ổn định trước sườn lên** — đó là lý do `spi_bit()` trong testbench đặt
  `mosi` rồi mới `#5 sclk=1`.
- **`miso` đổi tại sườn xuống** để chủ có nửa chu kỳ trọn vẹn để lấy mẫu nó ở sườn lên
  kế tiếp. Đây chính là mục đích của khối `always_ff @(negedge sclk …)` dòng 37.

---

## 3. Giản đồ ca LỖI thật — thiếu sườn khởi tạo

Đây là giản đồ của **testbench đang có trong hồ sơ** (`h04_spi_slave_tb.sv`), vẽ từ
`simulation.log` và từ chạy lại có `$monitor`. Khác biệt duy nhất so với §1: **không có
mốc ↑A**, vì `logic cs_n=1` ở dòng 2 chỉ là khởi tạo khai báo, **không sinh sườn**.

```
 sườn ↑sclk:              #1    #2    #3    #4    #5    #6    #7    #8
                          ┊     ┊     ┊     ┊     ┊     ┊     ┊     ┊
 cs_n  ‾‾‾‾‾\_________________________________________________________/‾‾‾‾‾
       t=0   t=2                                                   t=84
       ▲
       │ KHÔNG CÓ SƯỜN LÊN Ở ĐÂY — chỉ là giá trị khởi tạo
       │ ⇒ hai khối always_ff KHÔNG BAO GIỜ chạy nhánh reset
       ┊
 sclk  __________┌─┐___┌─┐___┌─┐___┌─┐___┌─┐___┌─┐___┌─┐___┌─┐_______________
                 │1│   │2│   │3│   │4│   │5│   │6│   │7│   │8│
                 └─┘   └─┘   └─┘   └─┘   └─┘   └─┘   └─┘   └─┘
                  t=8   18    28    38    48    58    68    78
                          ┊     ┊     ┊     ┊     ┊     ┊     ┊     ┊
 rx_count ══XXX═══XXX═══XXX═══XXX═══XXX═══XXX═══XXX═══XXX═══XXX═══XXX══0═══
              ▲
              │ KẸT Ở X VĨNH VIỄN:  `if (rx_count != 3'd7)` với X ⇒ điều kiện = X
              │                     ⇒ if KHÔNG thực hiện ⇒ rx_count giữ nguyên X
                          ┊     ┊     ┊     ┊     ┊     ┊     ┊     ┊
 rx_shift ══XX═══XX══XX══XX══XX══x3══X7══Xf══Xe══3c═══════════════════00═══
                                  ▲               ▲
                                  │               └─ TỰ SẠCH sau 8 lần dịch!
                                  └─ X bị đẩy dần ra ngoài
                                                              ┊       ┊
 rx_byte  ══XX══════════════════════════════════════════════════XX═══════
                                                                 ▲
                                            t=84: `if (rx_count == 3'd7)` với X
                                            ⇒ điều kiện = X ⇒ KHÔNG gán
                                            ⇒ rx_byte giữ nguyên XX
                                                                    ┊
 t=85    assert(rx_byte == 8'h3C)  →  XX ≠ 3C  →  $fatal("RX mismatch")  ❌
```

> 🔎 **Điểm dạy học đắt giá nhất của giản đồ này:** `rx_shift` **tự làm sạch X** sau 8 lần
> dịch (t=78 nó đã đúng `3c`), nhưng `rx_count` **không bao giờ** sạch. Lý do: thanh ghi
> dịch đẩy X ra ngoài, còn bộ đếm **hồi tiếp** X vào chính nó — và chốt `!= 3'd7` với X
> khiến nó không bao giờ được gán lại. Chỉ **một** trong hai thanh ghi cần reset, nhưng
> nếu không đọc kỹ thì không biết là cái nào.
>
> Sau mốc `t=84` (sườn `↑cs_n` **thật** đầu tiên) mọi thứ sạch, nên giao dịch thứ hai và
> thứ ba trong testbench đều **PASS**. Đó là dấu hiệu chẩn đoán rõ nhất.

---

## 4. Giản đồ ca "CS nhả giữa chừng" — hai kịch bản

### 4.1 Nhả sau 3 sườn — hành vi ĐÚNG

```
 sườn:          #1    #2    #3
 cs_n  ‾‾\_____________________/‾‾‾‾‾
 sclk  _____┌─┐___┌─┐___┌─┐___________
 rx_count 0  1     2     3      →  0        ← reset bất đồng bộ
 rx_shift    ..    ..    ..     →  00
 rx_byte  ══ giữ nguyên giá trị cũ ══       ✅ đúng: 3 ≠ 7 ⇒ không chốt
```

### 4.2 Nhả sau **7** sườn — hành vi SAI ❌

```
 sườn:          #1  #2  #3  #4  #5  #6  #7
 cs_n  ‾‾\_________________________________/‾‾‾‾‾
 sclk  _____┌┐__┌┐__┌┐__┌┐__┌┐__┌┐__┌┐___________
 rx_count 0  1   2   3   4   5   6   7      →  0
                                     ▲
                                     └─ ĐÃ BẰNG 7 dù mới có 7 bit!
 rx_shift ══ chứa 7 bit mới + 1 bit rác của lần trước ══
 rx_byte  ══════════════════════════════════> BỊ NẠP  ❌ SAI
                                              ↑
                               `if (rx_count == 3'd7)` cho TRUE
```

Đây là ca **chưa có trong testbench** — xem `corner_cases.md` §3 TC-3.

---

## 5. Những gì giản đồ này **không** chứng minh

| Câu hỏi | Trả lời |
|---|---|
| `sclk` chạy được tới bao nhiêu MHz? | ⬜ **Không biết.** Cần WNS từ STA; STA đang FAIL. |
| Sườn `↑cs_n` cách sườn `↑sclk` cuối bao lâu là đủ an toàn? | ⬜ **Không biết.** Cần kiểm tra recovery/removal trên `dfrtp_1`/`dfrtn_1`, chưa làm được. |
| `miso` ổn định sớm bao nhiêu trước sườn lên kế tiếp? | ⬜ **Không biết.** Zero-delay cho kết quả "ngay lập tức", phần cứng thật thì không. |
| Có glitch trên đường nào không? | ⬜ Không thể thấy ở mô phỏng hành vi. Mọi đầu ra đều là **thanh ghi**, nên rủi ro glitch thấp — nhưng phải xác nhận bằng mô phỏng gate-level có SDF. |

---

*Phiên bản: v1.0 · Ngày: 2026-09-24*
