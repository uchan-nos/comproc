unsigned int timer_cnt  __attribute__((at(0x02)));
unsigned int uart_data  __attribute__((at(0x06)));
unsigned int uart_flag  __attribute__((at(0x08)));
int          adc_result __attribute__((at(0x0A)));
unsigned int uf_xadr    __attribute__((at(0x10)));
unsigned int uf_yadr    __attribute__((at(0x12)));
unsigned int uf_flags   __attribute__((at(0x14)));
unsigned int uf_din_lo  __attribute__((at(0x18)));
unsigned int uf_din_hi  __attribute__((at(0x1A)));
unsigned int uf_dout_lo __attribute__((at(0x1C)));
unsigned int uf_dout_hi __attribute__((at(0x1E)));
unsigned int spi_dat    __attribute__((at(0x20)));
unsigned int spi_ctl    __attribute__((at(0x22)));
unsigned int kbc_queue  __attribute__((at(0x24)));
unsigned int kbc_status __attribute__((at(0x26)));
unsigned int i2c_data   __attribute__((at(0x28)));
unsigned int i2c_status __attribute__((at(0x2A)));
unsigned int uart2_data __attribute__((at(0x2C)));
unsigned int uart2_flag __attribute__((at(0x2E)));
unsigned int uart3_data __attribute__((at(0x30)));
unsigned int uart3_flag __attribute__((at(0x32)));
char         led_port   __attribute__((at(0x80)));
char         lcd_port   __attribute__((at(0x81)));
char         gpio       __attribute__((at(0x82)));
char         stop_btn   __attribute__((at(0x83)));
