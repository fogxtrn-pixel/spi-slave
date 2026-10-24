# Mach TUAN TU: dinh nghia clock that tu cong clock cua thiet ke.
# Chu ky 10 ns va IO delay 1 ns la GIA DINH phan tich khoi diem,
# KHONG phai yeu cau he thong. Phai neu kem moi con so bao cao.
# Cac cong duoi day KHONG co 'clk' trong ten nhung THUC SU lai chan
# .CLK cua o nho trong netlist, nen buoc phai khai bao la clock;
# neu bo sot, cac o nho do khong duoc rang buoc va STA bo qua chung:
#   cs_n
create_clock -name sclk -period 10.0 [get_ports sclk]
create_clock -name cs_n -period 10.0 [get_ports cs_n]
# Cac mien clock doc lap nhau: khong phan tich duong cat mien bang
# STA don gian - do la viec cua phan tich CDC.
set_clock_groups -asynchronous -group {sclk} -group {cs_n}
# GIA DINH DON GIAN HOA: moi cong du lieu duoc quy chieu ve 'sclk'.
# Thiet ke nay co NHIEU mien clock; dung ra tung cong phai quy chieu ve
# clock cua chinh mien no. Phai sua lai truoc khi dung so lieu timing cho
# bat ky ket luan nao ve cac cong thuoc mien con lai.
set_input_delay  1.0 -clock sclk [get_ports {mosi tx_byte}]
set_output_delay 1.0 -clock sclk [all_outputs]
