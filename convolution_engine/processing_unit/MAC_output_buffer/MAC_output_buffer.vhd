library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.std_logic_unsigned.all;
use work.types.all;

entity MAC_output_buffer is
    generic(
        queue_depth : positive := 2
    );
    port(
        clk               : in  STD_LOGIC;
        rst               : in  STD_LOGIC;
        enqueue_val       : in  STD_LOGIC;
        enqueue_addr      : in  STD_LOGIC;
        dequeue           : in  STD_LOGIC;
        value_in          : in  STD_LOGIC_VECTOR(ACT_VAL_WIDTH - 1 downto 0);
        addr_in           : in  STD_LOGIC_VECTOR(log_2(MAX_ACT_ELEMENTS) - 1 downto 0);
        value_queue_full  : out STD_LOGIC;
        value_queue_empty : out STD_LOGIC;
        addr_queue_empty  : out STD_LOGIC;
        value_out         : out STD_LOGIC_VECTOR(ACT_VAL_WIDTH - 1 downto 0);
        addr_out          : out STD_LOGIC_VECTOR(log_2(MAX_ACT_ELEMENTS) - 1 downto 0)
    );
end MAC_output_buffer;

architecture MAC_output_buffer_arch of MAC_output_buffer is
    component queue
        generic(
            element_width : positive := 8;
            queue_depth   : positive := 2
        );
        port(
            clk      : in  STD_LOGIC;
            rst      : in  STD_LOGIC;
            enqueue  : in  STD_LOGIC;
            dequeue  : in  STD_LOGIC;
            data_in  : in  STD_LOGIC_VECTOR(element_width - 1 downto 0);
            full     : out STD_LOGIC;
            empty    : out STD_LOGIC;
            data_out : out STD_LOGIC_VECTOR(element_width - 1 downto 0)
        );
    end component;
begin
    ------------------
    -- Values queue --
    ------------------
    value_queue: queue
        generic map(
            element_width => ACT_VAL_WIDTH,
            queue_depth   => queue_depth)
        port map(
            clk      => clk,
            rst      => rst,
            enqueue  => enqueue_val,
            dequeue  => dequeue,
            data_in  => value_in,
            full     => value_queue_full,
            empty    => value_queue_empty,
            data_out => value_out
        );
    
    ---------------------
    -- Addresses queue --
    ---------------------
    addr_queue: queue
        generic map(
            element_width => log_2(MAX_ACT_ELEMENTS),
            queue_depth   => queue_depth
        )
        port map(
            clk      => clk,
            rst      => rst,
            enqueue  => enqueue_addr,
            dequeue  => dequeue,
            data_in  => addr_in,
            full     => open,
            empty    => addr_queue_empty,
            data_out => addr_out
        );
end MAC_output_buffer_arch;