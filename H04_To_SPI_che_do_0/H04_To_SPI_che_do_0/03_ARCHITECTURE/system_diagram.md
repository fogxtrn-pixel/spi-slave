# H04 · Sơ đồ hệ thống (System Diagram)

---

## 1. Bối cảnh ứng dụng (Charter mục 1)

> "Khối làm vi mạch phụ trợ cho một vi điều khiển chủ: nhận lệnh và trả số liệu qua SPI."

`h04_spi_slave` là **cửa vào duy nhất** của con chip phụ trợ. Mọi lệnh từ vi điều khiển đều
phải đi qua nó.

```
 ┌──────────────────────┐                        ┌───────────────────────────────────────┐
 │  VI ĐIỀU KHIỂN CHỦ   │                        │   VI MẠCH PHỤ TRỢ (Tiny Tapeout)      │
 │  (bo mạch, ngoài     │                        │                                       │
 │   phạm vi đề)        │                        │   ┌───────────────────────────────┐   │
 │                      │  SCLK  ───────────────▶│──▶│ sclk                          │   │
 │  ┌────────────────┐  │  MOSI  ───────────────▶│──▶│ mosi     h04_spi_slave        │   │
 │  │ SPI master     │  │  CS#   ───────────────▶│──▶│ cs_n     ◀── ĐỀ H04 ──▶        │   │
 │  │ (tạo SCLK, CS) │  │  MISO  ◀───────────────│◀──│ miso                          │   │
 │  └────────────────┘  │                        │   └──────┬─────────────▲──────────┘   │
 │                      │                        │          │ rx_byte[7:0]│ tx_byte[7:0] │
 └──────────────────────┘                        │          ▼             │              │
                                                 │   ┌──────────────────────────────┐    │
                                                 │   │  BỘ GIẢI LỆNH + THANH GHI    │    │
                                                 │   │  (ngoài phạm vi đề H04)      │    │
                                                 │   └──────────┬───────────────────┘    │
                                                 │              ▼                        │
                                                 │   ┌──────────────────────────────┐    │
                                                 │   │  TẢI CHỨC NĂNG (cảm biến,    │    │
                                                 │   │  bộ đếm, ADC…) — ngoài phạm  │    │
                                                 │   │  vi đề                       │    │
                                                 │   └──────────────────────────────┘    │
                                                 └───────────────────────────────────────┘
```

## 2. Ranh giới khối — cái gì thuộc H04, cái gì không

| Chức năng | Thuộc H04? | Ai làm? |
|---|---|---|
| Chuyển nối tiếp → song song (`mosi` → `rx_byte`) | ✅ **có** | `rx_shift` + `rx_count` |
| Chuyển song song → nối tiếp (`tx_byte` → `miso`) | ✅ **có** | `tx_shift` + `tx_count` |
| Chọn sườn lấy mẫu / sườn cập nhật (chế độ 0) | ✅ **có** | hai khối `always_ff` riêng |
| Chính sách "chỉ chốt byte trọn vẹn" | ✅ **có** | khối `@(posedge cs_n)` |
| **Tạo** `sclk`, **tạo** `cs_n` | ❌ không | Vi điều khiển chủ |
| Giải mã lệnh, bản đồ thanh ghi | ❌ không | Bộ giải lệnh bên trong chip phụ trợ |
| Đệm nhiều byte, FIFO | ❌ không | Charter mục 3 — ngoài phạm vi |
| Lọc glitch trên `sclk`, chống dội `cs_n` | ❌ không | Tầng chân/bo mạch |
| Đồng bộ `rx_byte` sang miền `clk` hệ thống | ❌ không | **Tầng bọc** — xem §3 |
| Ánh xạ 24 chân Tiny Tapeout, chọn chiều `uio` | ❌ **không — và hiện CHƯA CÓ AI LÀM** | xem `functional_spec.md` W-1 |

## 3. Nghĩa vụ hợp đồng của tầng ngoài

Vì `rx_byte` chỉ đổi tại `↑cs_n` (một sườn **bất đồng bộ** so với mọi xung nhịp khác),
phần logic đọc `rx_byte` **bắt buộc** phải:

```
  rx_byte[7:0] ──▶ ┌─────────────┐ ──▶ ┌─────────────┐ ──▶ tới logic miền clk
   (miền cs_n)     │ FF tầng 1   │     │ FF tầng 2   │
                   └──────┬──────┘     └──────┬──────┘
                       clk ▲              clk ▲
        (bộ đồng bộ 2 tầng — KHÔNG có trong đề H04)
```

và phải chỉ lấy mẫu `rx_byte` **sau khi** phát hiện `cs_n` đã lên ổn định.
Đây là nội dung trả lời cho câu hỏi Charter mục 9 — xem `implementation-notes_H04.md` §8.

## 4. Sơ đồ vòng đời RTL → GDSII (trạng thái thật)

Lấy đúng từ `06_GDSII/physical_report.md` và BRIEF.

```
  ĐẶC TẢ ──▶ RTL ──▶ MÔ PHỎNG ──▶ TỔNG HỢP ──▶ STA ──▶ FLOORPLAN ──▶ PLACE ──▶ CTS ──▶ ROUTE ──▶ DRC ──▶ LVS ──▶ GDS
    ✅        ✅        ❌           ✅          ❌          ⬜           ⬜        ⬜       ⬜        ⬜      ⬜      ⬜
              │         │            │           │
              │         │            │           └── OpenSTA 3.1.0: `netlist.v line 39, syntax error`
              │         │            │               ⇒ KHÔNG CÓ slack, WNS, TNS, công suất
              │         │            └── Yosys 0.33: 62 cell, 710,6816 µm²
              │         │                 ⚠️ trong đó 8 ô `$_ALDFFE_NPP_` CHƯA ánh xạ được
              │         └── Icarus Verilog: `RX mismatch` tại t = 85
              └── h04_spi_slave.sv, 66 dòng
```

| Bước | Trạng thái | Công cụ | Bằng chứng |
|---|---|---|---|
| Mô hình chuẩn Python | ✅ PASS | CPython | `05_VERIFICATION/python_reference_run.log` |
| Biên dịch RTL | ✅ không lỗi | Icarus Verilog | `05_VERIFICATION/iverilog_compile.log` (rỗng) |
| **Mô phỏng RTL** | ❌ **FAIL** | Icarus Verilog | `05_VERIFICATION/simulation.log` |
| Tổng hợp logic | ✅ PASS (có cảnh báo) | Yosys 0.33 | `06_GDSII/synthesis/synth_stat.txt`, `yosys.log` |
| **STA** | ❌ **FAIL** | OpenSTA 3.1.0 | `06_GDSII/sta/sta.log` |
| Công suất | ⬜ **chưa có** | OpenSTA | không sinh được file — STA dừng trước `report_power` |
| Floorplan → GDS | ⬜ chưa chạy | LibreLane / OpenROAD | `06_GDSII/*/README.md` |

> ⬛ **Không áp dụng:** không có bước nào thuộc loại này cho H04 — đây là mạch tuần tự
> đầy đủ, mọi bước của vòng đời đều có ý nghĩa.

## 5. Số liệu có và không có

| Đại lượng | Giá trị | Nguồn |
|---|---:|---|
| Số cell | **62** | `synth_stat.txt` |
| Ô nhớ đã ánh xạ | **22** (`dfrtp_1`×11, `dfxtp_1`×8, `dfrtn_1`×3) | `synth_stat.txt` |
| Ô nhớ **chưa** ánh xạ | **8** (`$_ALDFFE_NPP_`) | `synth_stat.txt` |
| Diện tích | **710,6816 µm²** ⚠️ **thiếu phần của 8 ô ALDFFE** (`Area for cell type $_ALDFFE_NPP_ is unknown!`) | `synth_stat.txt` |
| Slack / WNS / TNS | ⬜ **chưa có** — cần STA chạy được; xem `known_issues.md` §6 | — |
| Đường tới hạn | ⬜ **chưa có** — cùng lý do | — |
| Công suất | ⬜ **chưa có** — điều kiện: netlist ánh xạ hết + SDC với clock định nghĩa cho cả `sclk` và `cs_n` | — |

---

*Phiên bản: v1.0 · Ngày: 2026-09-24*
