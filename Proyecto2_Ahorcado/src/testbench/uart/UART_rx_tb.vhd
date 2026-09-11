library ieee;
use ieee.std_logic_1164.all;

library std;
use std.env.all;

entity UART_rx_tb is
end entity UART_rx_tb;

architecture Behavioral of UART_rx_tb is

    constant CLK_PERIOD              : time    := 10 ns;
    constant BAUD_X16_CLK_TICKS      : integer := 54;
    constant BIT_PERIOD              : time    := 8680 ns;
    constant SIMULATION_TIMEOUT      : time    := 1 ms;

    signal clk                       : std_logic := '0';
    signal reset                     : std_logic := '1';
    signal rx_data_in                : std_logic := '1';
    signal rx_data_rdy               : std_logic;
    signal rx_data_out               : std_logic_vector(7 downto 0);
    signal frames_checked            : boolean := false;
    signal serial_driver_done        : boolean := false;

    procedure send_uart_frame (
        signal   serial_line : out std_logic;
        constant data_byte   : in  std_logic_vector(7 downto 0)
    ) is
    begin
        serial_line <= '0';
        wait for BIT_PERIOD;

        for bit_index in 0 to 7 loop
            serial_line <= data_byte(bit_index);
            wait for BIT_PERIOD;
        end loop;

        serial_line <= '1';
        wait for BIT_PERIOD;
    end procedure send_uart_frame;

begin

    clk <= not clk after CLK_PERIOD / 2;

    dut: entity work.UART_rx(Behavioral)
        generic map (
            BAUD_X16_CLK_TICKS => BAUD_X16_CLK_TICKS
        )
        port map (
            clk         => clk,
            reset       => reset,
            rx_data_in  => rx_data_in,
            rx_data_rdy => rx_data_rdy,
            rx_data_out => rx_data_out
        );

    serial_driver: process
    begin
        wait until reset = '0';
        wait for 5 * CLK_PERIOD;

        send_uart_frame(rx_data_in, x"41");
        wait for BIT_PERIOD;
        send_uart_frame(rx_data_in, x"5A");

        serial_driver_done <= true;
        wait;
    end process serial_driver;

    reception_checker: process
        variable rx_rdy_start : time;
    begin
        wait until rising_edge(rx_data_rdy);
        rx_rdy_start := now;

        assert rx_data_out = x"41"
            report "Prueba RX 0x41: dato recibido incorrecto"
            severity failure;

        wait until falling_edge(rx_data_rdy);

        assert (now - rx_rdy_start) = CLK_PERIOD
            report "Prueba RX 0x41: rx_data_rdy no permaneció activo exactamente un ciclo de clk"
            severity failure;
        assert rx_data_rdy = '0'
            report "Prueba RX 0x41: rx_data_rdy no regresó a '0'"
            severity failure;

        wait until rising_edge(rx_data_rdy);
        rx_rdy_start := now;

        assert rx_data_out = x"5A"
            report "Prueba RX 0x5A: dato recibido incorrecto"
            severity failure;

        wait until falling_edge(rx_data_rdy);

        assert (now - rx_rdy_start) = CLK_PERIOD
            report "Prueba RX 0x5A: rx_data_rdy no permaneció activo exactamente un ciclo de clk"
            severity failure;
        assert rx_data_rdy = '0'
            report "Prueba RX 0x5A: rx_data_rdy no regresó a '0'"
            severity failure;

        frames_checked <= true;
        wait;
    end process reception_checker;

    stimulus: process
    begin
        reset <= '1';

        for reset_cycle in 1 to 3 loop
            wait until rising_edge(clk);
            wait for 1 ns;
            assert rx_data_in = '1'
                report "Prueba de reset: rx_data_in no permanece en reposo lógico '1'"
                severity failure;
            assert rx_data_rdy = '0'
                report "Prueba de reset: rx_data_rdy debe permanecer en '0'"
                severity failure;
        end loop;

        reset <= '0';

        wait until frames_checked and serial_driver_done;

        report "UART_rx_tb: todas las pruebas finalizaron correctamente"
            severity note;
        stop;
        wait;
    end process stimulus;

    watchdog: process
    begin
        wait for SIMULATION_TIMEOUT;
        assert false
            report "UART_rx_tb: tiempo máximo de simulación excedido"
            severity failure;
        wait;
    end process watchdog;

end architecture Behavioral;
