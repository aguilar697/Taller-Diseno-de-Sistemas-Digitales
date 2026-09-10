library ieee;
use ieee.std_logic_1164.all;

library std;
use std.env.all;

entity UART_tb is
end entity UART_tb;

architecture Behavioral of UART_tb is

    constant CLK_PERIOD          : time := 10 ns;
    constant SIMULATION_TIMEOUT  : time := 1 ms;

    signal clk                   : std_logic := '0';
    signal reset                 : std_logic := '1';
    signal tx_start              : std_logic := '0';
    signal tx_rdy                : std_logic;
    signal rx_data_rdy           : std_logic;
    signal data_in               : std_logic_vector(7 downto 0) := (others => '0');
    signal data_out              : std_logic_vector(7 downto 0);
    signal serial_loopback       : std_logic;
    signal tx_rdy_count          : natural range 0 to 2 := 0;
    signal rx_data_rdy_count     : natural range 0 to 2 := 0;

begin

    clk <= not clk after CLK_PERIOD / 2;

    dut: entity work.UART(Behavioral)
        port map (
            clk         => clk,
            reset       => reset,
            tx_start    => tx_start,
            tx_rdy      => tx_rdy,
            rx_data_rdy => rx_data_rdy,
            data_in     => data_in,
            data_out    => data_out,
            rx          => serial_loopback,
            tx          => serial_loopback
        );

    tx_rdy_monitor: process
        variable pulse_start : time;
    begin
        loop
            wait until rising_edge(tx_rdy);
            pulse_start := now;
            wait until falling_edge(tx_rdy);

            assert (now - pulse_start) = CLK_PERIOD
                report "tx_rdy no permaneció activo exactamente un ciclo de clk"
                severity failure;
            assert tx_rdy_count < 2
                report "Se observó un pulso adicional inesperado de tx_rdy"
                severity failure;

            tx_rdy_count <= tx_rdy_count + 1;
        end loop;
    end process tx_rdy_monitor;

    rx_data_rdy_monitor: process
        variable pulse_start : time;
    begin
        loop
            wait until rising_edge(rx_data_rdy);
            pulse_start := now;

            case rx_data_rdy_count is
                when 0 =>
                    assert data_out = x"41"
                        report "Primera recepción: se esperaba 0x41"
                        severity failure;
                when 1 =>
                    assert data_out = x"5A"
                        report "Segunda recepción: se esperaba 0x5A"
                        severity failure;
                when others =>
                    assert false
                        report "Se observó un pulso adicional inesperado de rx_data_rdy"
                        severity failure;
            end case;

            wait until falling_edge(rx_data_rdy);

            assert (now - pulse_start) = CLK_PERIOD
                report "rx_data_rdy no permaneció activo exactamente un ciclo de clk"
                severity failure;
            assert rx_data_rdy_count < 2
                report "Se observó un pulso adicional inesperado de rx_data_rdy"
                severity failure;

            rx_data_rdy_count <= rx_data_rdy_count + 1;
        end loop;
    end process rx_data_rdy_monitor;

    stimulus: process
    begin
        reset    <= '1';
        tx_start <= '0';
        data_in  <= (others => '0');

        for reset_cycle in 1 to 3 loop
            wait until rising_edge(clk);
            wait for 1 ns;
            assert serial_loopback = '1'
                report "Prueba de reset: TX no permanece en reposo lógico '1'"
                severity failure;
            assert tx_rdy = '0'
                report "Prueba de reset: tx_rdy debe permanecer en '0'"
                severity failure;
            assert rx_data_rdy = '0'
                report "Prueba de reset: rx_data_rdy debe permanecer en '0'"
                severity failure;
        end loop;

        reset <= '0';

        data_in  <= x"41";
        tx_start <= '1';
        wait until rising_edge(clk);
        tx_start <= '0';

        wait until (tx_rdy_count = 1) and (rx_data_rdy_count = 1);

        data_in  <= x"5A";
        tx_start <= '1';
        wait until rising_edge(clk);
        tx_start <= '0';

        wait until (tx_rdy_count = 2) and (rx_data_rdy_count = 2);

        assert tx_rdy_count = 2
            report "No se observaron exactamente dos pulsos válidos de tx_rdy"
            severity failure;
        assert rx_data_rdy_count = 2
            report "No se observaron exactamente dos pulsos válidos de rx_data_rdy"
            severity failure;

        report "UART_tb: todas las pruebas finalizaron correctamente"
            severity note;
        stop;
        wait;
    end process stimulus;

    watchdog: process
    begin
        wait for SIMULATION_TIMEOUT;
        assert false
            report "UART_tb: tiempo máximo de simulación excedido"
            severity failure;
        wait;
    end process watchdog;

end architecture Behavioral;
