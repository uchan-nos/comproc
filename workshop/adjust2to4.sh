#!/bin/sh

if [ $# -lt 1 ]
then
  echo "Usage: $0 <chap>"
  exit 1
fi

chap=$1
src_prj=rev2_tangnano9k
dst_prj=rev4_tangnano9k
src_dir=$chap/board/$src_prj
dst_dir=$chap/board/$dst_prj

echo "Adjusting files for rev4"

mv $dst_dir/$src_prj.gprj $dst_dir/$dst_prj.gprj

sed -i "/OUTPUT_BASE_NAME/ s/rev2/rev4/" $dst_dir/impl/project_process_config.json
sed -i "/assign led_row =/ s/= /= 9'h1ff ^ (/" $dst_dir/src/main.sv
sed -i "/assign led_row =/ s/;/);/" $dst_dir/src/main.sv
echo "Please check: $dst_dir/src/main.sv"

cat << EOF > $dst_dir/src/port.cst
IO_LOC "sys_clk" 52;
IO_PORT "sys_clk" PULL_MODE=NONE IO_TYPE=LVCMOS33;
IO_LOC "rst_n_raw" 4;
IO_PORT "rst_n_raw" PULL_MODE=UP IO_TYPE=LVCMOS18;

IO_LOC "uart_rx" 54;
IO_PORT "uart_rx" IO_TYPE=LVCMOS33;
IO_LOC "uart_tx" 53;
IO_PORT "uart_tx" IO_TYPE=LVCMOS33;

IO_LOC "led_col[0]" 30;
IO_LOC "led_col[1]" 33;
IO_LOC "led_col[2]" 34;
IO_LOC "led_col[3]" 40;
IO_LOC "led_col[4]" 35;
IO_LOC "led_col[5]" 41;
IO_LOC "led_col[6]" 42;
IO_LOC "led_col[7]" 51;
IO_PORT "led_col[0]" IO_TYPE=LVCMOS33;
IO_PORT "led_col[1]" IO_TYPE=LVCMOS33;
IO_PORT "led_col[2]" IO_TYPE=LVCMOS33;
IO_PORT "led_col[3]" IO_TYPE=LVCMOS33;
IO_PORT "led_col[4]" IO_TYPE=LVCMOS33;
IO_PORT "led_col[5]" IO_TYPE=LVCMOS33;
IO_PORT "led_col[6]" IO_TYPE=LVCMOS33;
IO_PORT "led_col[7]" IO_TYPE=LVCMOS33;

IO_LOC "led_row[0]" 37; // ROW1
IO_LOC "led_row[1]" 36;
IO_LOC "led_row[2]" 39;
IO_LOC "led_row[3]" 25;
IO_LOC "led_row[4]" 26;
IO_LOC "led_row[5]" 27;
IO_LOC "led_row[6]" 28;
IO_LOC "led_row[7]" 29; // ROW8
IO_LOC "led_row[8]" 38; // 7SEG
IO_PORT "led_row[0]" IO_TYPE=LVCMOS33;
IO_PORT "led_row[1]" IO_TYPE=LVCMOS33;
IO_PORT "led_row[2]" IO_TYPE=LVCMOS33;
IO_PORT "led_row[3]" IO_TYPE=LVCMOS33;
IO_PORT "led_row[4]" IO_TYPE=LVCMOS33;
IO_PORT "led_row[5]" IO_TYPE=LVCMOS33;
IO_PORT "led_row[6]" IO_TYPE=LVCMOS33;
IO_PORT "led_row[7]" IO_TYPE=LVCMOS33;
IO_PORT "led_row[8]" IO_TYPE=LVCMOS33;

// IO_LOC "lcd_e"     76;
// IO_LOC "lcd_rw"    77;
// IO_LOC "lcd_rs"    63;
// IO_LOC "lcd_db[7]" 32;
// IO_LOC "lcd_db[6]" 31;
// IO_LOC "lcd_db[5]" 49;
// IO_LOC "lcd_db[4]" 48;
// IO_PORT "lcd_e"     IO_TYPE=LVCMOS33;
// IO_PORT "lcd_rw"    IO_TYPE=LVCMOS33;
// IO_PORT "lcd_rs"    IO_TYPE=LVCMOS33;
// IO_PORT "lcd_db[7]" IO_TYPE=LVCMOS33;
// IO_PORT "lcd_db[6]" IO_TYPE=LVCMOS33;
// IO_PORT "lcd_db[5]" IO_TYPE=LVCMOS33;
// IO_PORT "lcd_db[4]" IO_TYPE=LVCMOS33;
EOF

echo "Adjusted."
