library ieee;
use ieee.std_logic_1164.all;

library std;
use std.env.all;

entity UART_tx_tb is
end entity UART_tx_tb;

architecture Behavioral of UART_tx_tb is

    constant CLK_PERIOD      : time    := 10 ns;
    constant BAUD_CLK_TICKS  : integer := 868;
    constant BIT_PERIOD      : time    := CLK_PERIOD * BAUD_CLK_TICKS;

    signal clk               : std_logic := '0';
    signal reset             : std_logic := '1';
    signal tx_start          : std_logic := '0';
    signal tx_rdy            : std_logic;
    signal tx_data_in        : std_logic_vector(7 downto 0) := (others => '0');
    signal tx_data_out       : std_logic;
    signal frames_checked    : boolean := false;

    procedure check_serial_byte (
        signal   serial_tx     : in std_logic;
        constant expected_data : in std_logic_vector(7 downto 0);
        constant test_name     : in string
    ) is
    begin
        wait until falling_edge(serial_tx);
        wait for BIT_PERIOD / 2;

        assert serial_tx = '0'
            report test_name & ": bit de inicio incorrecto"
            severity error;

        for bit_index in 0 to 7 loop
            wait for BIT_PERIOD;
            assert serial_tx = expected_data(bit_index)
                report test_name & ": bit de datos " &
                       integer'image(bit_index) & " incorrecto; esperado " &
                       std_logic'image(expected_data(bit_index)) &
                       ", recibido " & std_logic'image(serial_tx)
                severity error;
        end loop;

        wait for BIT_PERIOD;
        assert serial_tx = '1'
            report test_name & ": bit de parada incorrecto"
            severity error;
    end procedure check_serial_byte;

begin

    clk <= not clk after CLK_PERIOD / 2;

    dut: entity work.UART_tx(Behavioral)
        generic map (
            BAUD_CLK_TICKS => BAUD_CLK_TICKS
        )
        port map (
            clk         => clk,
            reset       => reset,
            tx_start    => tx_start,
            tx_rdy      => tx_rdy,
            tx_data_in  => tx_data_in,
            tx_data_out => tx_data_out
        );

    serial_checker: process
    begin
        wait until reset = '0';

        check_serial_byte(tx_data_out, x"41", "Prueba TX 0x41");
        check_serial_byte(tx_data_out, x"5A", "Prueba TX consecutiva 0x5A");

        frames_checked <= true;
        wait;
    end process serial_checker;

    stimulus: process
        variable tx_rdy_start : time;
    begin
        tx_start   <= '0';
        tx_data_in <= (others => '0');
        reset      <= '1';

        for reset_cycle in 1 to 3 loop
            wait until rising_edge(clk);
            wait for 1 ns;
            assert tx_data_out = '1'
                report "Prueba de reset: TX no permanece en reposo lógico '1'"
                severity error;
            assert tx_rdy = '0'
                report "Prueba de reset: tx_rdy debe permanecer en '0'"
                severity error;
        end loop;

        reset <= '0';
        wait until rising_edge(clk);

        tx_data_in <= x"41";
        tx_start   <= '1';
        wait until rising_edge(clk);
        tx_start <= '0';

        wait until rising_edge(tx_rdy);
        tx_rdy_start := now;
        wait until falling_edge(tx_rdy);

        assert (now - tx_rdy_start) = CLK_PERIOD
            report "Prueba TX 0x41: tx_rdy no permaneció activo exactamente un ciclo de clk"
            severity failure;
        assert tx_rdy = '0'
            report "Prueba TX 0x41: tx_rdy no regresó a '0'"
            severity failure;

        tx_data_in <= x"5A";
        tx_start   <= '1';
        wait until rising_edge(clk);
        tx_start <= '0';

        wait until rising_edge(tx_rdy);
        tx_rdy_start := now;
        wait until falling_edge(tx_rdy);

        assert (now - tx_rdy_start) = CLK_PERIOD
            report "Prueba TX 0x5A: tx_rdy no permaneció activo exactamente un ciclo de clk"
            severity failure;
        assert tx_rdy = '0'
            report "Prueba TX 0x5A: tx_rdy no regresó a '0'"
            severity failure;

        if not frames_checked then
            wait until frames_checked;
        end if;

        report "UART_tx_tb: todas las pruebas finalizaron correctamente"
            severity note;
        stop;
        wait;
    end process stimulus;

end architecture Behavioral;
