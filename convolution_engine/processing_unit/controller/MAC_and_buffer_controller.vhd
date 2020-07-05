library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.std_logic_unsigned.all;
use work.types.all;

entity MAC_and_buffer_controller is
    port(
        clk                   : in  STD_LOGIC;
        rst                   : in  STD_LOGIC;
        new_MAC               : in  STD_LOGIC;
        convolution_step_done : in  STD_LOGIC;
        convolution_done      : in  STD_LOGIC;
        MAC_buffer_full       : in  STD_LOGIC;
        MAC_enable            : out STD_LOGIC;
        MAC_flush             : out STD_LOGIC;
        enqueue_addr          : out STD_LOGIC
    );
end MAC_and_buffer_controller;

architecture MAC_and_buffer_controller_arch of MAC_and_buffer_controller is
    type tp_state is (
        IDLE,
        MULTIPLYING,
        FLUSH_AND_MULTIPLY,
        FLUSH
    );
    signal fsm_cs, fsm_ns: tp_state;
begin
    MAC_and_buffer_controller_FSM: process(
        fsm_cs,                                             -- Default
        convolution_done, convolution_step_done, new_MAC)   -- IDLE
    begin
        MAC_enable   <= '0';
        MAC_flush    <= '0';
        enqueue_addr <= '0';
        fsm_ns       <= fsm_cs;

        case fsm_cs is
            when IDLE =>
                if (convolution_done = '1' OR convolution_step_done = '1') AND new_MAC = '1' then
                    enqueue_addr <= '1';
                    fsm_ns       <= FLUSH_AND_MULTIPLY;
                elsif convolution_done = '1' OR convolution_step_done = '1' then
                    enqueue_addr <= '1';
                    fsm_ns       <= FLUSH;
                elsif new_MAC = '1' then
                    fsm_ns       <= MULTIPLYING;
                end if;
           
            when MULTIPLYING =>
                MAC_enable <= '1';

                if (convolution_done = '1' OR convolution_step_done = '1') AND new_MAC = '1' then
                    enqueue_addr <= '1';
                    fsm_ns       <= FLUSH_AND_MULTIPLY;
                elsif convolution_done = '1' OR convolution_step_done = '1' then
                    enqueue_addr <= '1';
                    fsm_ns       <= FLUSH;
                elsif new_MAC = '0' then
                    fsm_ns       <= IDLE;
                end if;
            
            when FLUSH_AND_MULTIPLY =>
                MAC_enable <= '1';
                MAC_flush  <= '1';
                
                if new_MAC = '1' then
                    fsm_ns <= MULTIPLYING;
                else
                    fsm_ns <= IDLE;
                end if;
            
            when FLUSH =>
                MAC_flush <= '1';
                
                if new_MAC = '1' then
                    fsm_ns <= MULTIPLYING;
                else
                    fsm_ns <= IDLE;
                end if;
        end case;
    end process MAC_and_buffer_controller_FSM;    

    process(clk)
    begin              
        if rising_edge(clk) then
            if rst = '1' then
                fsm_cs <= IDLE;
            else
                fsm_cs <= fsm_ns;
            end if;
        end if;
    end process;
end MAC_and_buffer_controller_arch;