library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.std_logic_unsigned.all;
use work.types.all;

entity queue is
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
end queue;

architecture queue_arch of queue is
    component reg
        generic(bits       : positive := 128;
                init_value : natural  := 0
        );
        port (
              clk  : in  STD_LOGIC;
              rst  : in  STD_LOGIC;
              ld   : in  STD_LOGIC;
              din  : in  STD_LOGIC_VECTOR(bits - 1 downto 0);
              dout : out STD_LOGIC_VECTOR(bits - 1 downto 0)
        );
    end component;
    
    component bidirectional_counter
        generic(
            bits : positive := 2;
            step : positive := 1
        );
        port(
            clk   : in  STD_LOGIC;
            rst   : in  STD_LOGIC;
            inc   : in  STD_LOGIC;
            dec   : in  STD_LOGIC;
            count : out STD_LOGIC_VECTOR(bits - 1 downto 0)
        );
    end component;
    
    -- Queue regs input
    signal ld_queue : STD_LOGIC_VECTOR(queue_depth - 1 downto 0);
    
    -- Queue regs output
    type tp_value_out_queue is
        array(0 to queue_depth - 1) of STD_LOGIC_VECTOR(element_width - 1 downto 0);
    signal queue_out : tp_value_out_queue;
    
    -- Queue counter
    signal queue_count  : STD_LOGIC_VECTOR(log_2(queue_depth + 1) - 1 downto 0);
    signal read_pointer : STD_LOGIC_VECTOR(log_2(queue_depth + 1) - 1 downto 0);
begin
    ----------------
    -- Queue regs --
    ----------------
    queue_regs: for i in 0 to queue_depth - 1 generate
        ld_queue(i) <= '1' when enqueue = '1'            AND 
                                to_uint(queue_count) = i else
                       '0';
        
        data_reg: reg generic map(element_width, 0)
            port map(clk, rst, ld_queue(i), data_in, queue_out(i));
    end generate;
    
    read_pointer <= queue_count - 1 when queue_count > 0 else (others => '0');
    
    -- Queue output selector
    data_out <= queue_out(to_uint(read_pointer));

    ------------------------------
    -- Queue occupation control --
    ------------------------------
    queue_counter: bidirectional_counter
        generic map(
            bits => log_2(queue_depth + 1),
            step => 1
        )
        port map(
            clk   => clk,
            rst   => rst,
            inc   => enqueue,
            dec   => dequeue,
            count => queue_count
        );
    
    full  <= '1' when to_uint(queue_count) = queue_depth else '0';
    empty <= '1' when to_uint(queue_count) = 0           else '0';
end queue_arch;