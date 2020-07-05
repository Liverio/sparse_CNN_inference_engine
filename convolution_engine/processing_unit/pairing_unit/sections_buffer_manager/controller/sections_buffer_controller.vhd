library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.types.all;

entity sections_buffer_controller is
    port(
        clk               : in  STD_LOGIC;
        rst               : in  STD_LOGIC;
        start_convolution : in  STD_LOGIC;
        request_ind_int   : in  STD_LOGIC_VECTOR(2 - 1 downto 0);
        convolution_done  : in  STD_LOGIC;
        request_ind       : out STD_LOGIC
    );
end sections_buffer_controller;

architecture sections_buffer_controller_arch of sections_buffer_controller is
    -- Sections buffer FSM
    type tp_state is (IDLE,
                      CONVOLVING
    );
    signal fsm_cs, fsm_ns: tp_state;
begin
    -- Sections buffer FSM
    sections_buffer_FSM : process(
        fsm_cs,                             -- Default
        start_convolution, request_ind_int, -- IDLE
        convolution_done)                   -- CONVOLVING
    begin
        request_ind <= '0';
        fsm_ns      <= fsm_cs;
        
        case fsm_cs is
            when IDLE =>
                if start_convolution = '1' then
                    request_ind <= request_ind_int(0) OR request_ind_int(1); 
                    fsm_ns      <= CONVOLVING;
                end if;
            
            when CONVOLVING =>
                request_ind <= request_ind_int(0) OR request_ind_int(1); 
                
                if convolution_done = '1' then
                    fsm_ns <= IDLE;
                end if;
        end case;        
    end process sections_buffer_FSM;
    
    process(clk)
    begin              
        if clk'event AND clk = '1' then
            if rst = '1' then
                fsm_cs <= IDLE;
            else
                fsm_cs <= fsm_ns;
            end if;
        end if;
    end process;    
end sections_buffer_controller_arch;