library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.std_logic_unsigned.all;
use work.types.all;

entity done_controller is
    port(
        clk               : in  STD_LOGIC;
        rst               : in  STD_LOGIC;
        start_convolution : in  STD_LOGIC;
        convolution_done  : in  STD_LOGIC;
        MAC_buffer_empty  : in  STD_LOGIC;
        done              : out STD_LOGIC
    );
end done_controller;

architecture done_controller_arch of done_controller is
    type tp_state is (
        IDLE,
        CONVOLVING,
        FLUSHING_MAC_BUFFER
    );
    signal fsm_cs, fsm_ns: tp_state;
begin    
    done_controller_FSM: process(
        fsm_cs,             -- Default
        start_convolution,  -- IDLE
        convolution_done,   -- CONVOLVING
        MAC_buffer_empty    -- FLUSHING_MAC_BUFFER
    )
    begin
        done   <= '0';        
        fsm_ns <= fsm_cs;

        case fsm_cs is
            when IDLE =>
                done <= '1';
                
                if start_convolution = '1' then
                    fsm_ns <= CONVOLVING;
                end if;
           
            when CONVOLVING =>
                if convolution_done = '1' then
                    fsm_ns <= FLUSHING_MAC_BUFFER;
                end if;
            
            when FLUSHING_MAC_BUFFER =>
                if MAC_buffer_empty = '1' then
                    fsm_ns <= IDLE;
                end if;
        end case;
    end process done_controller_FSM;    

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
end done_controller_arch;