library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
library UNIMACRO;
use UNIMACRO.vcomponents.all;
use work.types.all;

--  |---------------------------------------------------|
--  |                                                   |
--  |  |------------------|       |------------------|  |
--  |  |   |----------|   |       |   |----------|   |  |
--  |  |   | BRAM_0_n |   |       |   | BRAM_m_n |   |  |
--  |  |   |----------|   |       |   |----------|   |  |
--  |  |        .         |       |        .         |  |
--  |  |        .         |       |        .         |  |
--  |  |        .         | . . . |        .         |  |
--  |  |   |----------|   |       |   |----------|   |  |
--  |  |   | BRAM_0_0 |   |       |   | BRAM_m_0 |   |  |
--  |  |   |----------|   |       |   |----------|   |  |
--  |  |                  |       |                  |  |
--  |  |      Bank_0      |       |      Bank_m      |  |
--  |  |------------------|       |------------------|  |
--  |                                                   |
--  |                      Memory                       |
--  |                                                   |
--  |---------------------------------------------------|
-- 
-- ++ Asumptions ++
--      - Parallel reads/writes accross banks BUT NOT within banks

entity memory is
    generic(
        banks      : positive := 2;
        bank_depth : positive := 2;
        data_width : positive := 32
    );
    port(
        clk         : in  STD_LOGIC;
        rst         : in  STD_LOGIC;
        addrs       : in  STD_LOGIC_VECTOR(banks * (log_2(bank_depth) + addr_width(data_width)) - 1 downto 0);
        data_input  : in  STD_LOGIC_VECTOR(banks * data_width - 1 downto 0);
        we          : in  STD_LOGIC_VECTOR(banks - 1 downto 0);
        data_output : out STD_LOGIC_VECTOR(banks * data_width - 1 downto 0)
    );
end memory;

architecture memory_arch of memory is
    component blockRAM
        generic(
            data_width : positive := 8
        );
        port(
            clk         : in  STD_LOGIC;
            rst         : in  STD_LOGIC;
            addr        : in  STD_LOGIC_VECTOR(addr_width(data_width) - 1 downto 0);
            data_input  : in  STD_LOGIC_VECTOR(data_width - 1 downto 0);
            we          : in  STD_LOGIC;
            data_output : out STD_LOGIC_VECTOR(data_width - 1 downto 0)
        );
    end component;
    
    component reg
        generic(bits       : natural  := 128;
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

    -- Input
    type tp_memory_addr is
        array(banks - 1 downto 0) of STD_LOGIC_VECTOR((log_2(bank_depth) + addr_width(data_width)) - 1 downto 0);
    signal addrs_array : tp_memory_addr;

    type tp_memory_input is
        array(banks - 1 downto 0) of STD_LOGIC_VECTOR(data_width - 1 downto 0);
    signal data_input_array : tp_memory_input;

    type tp_memory_output is
        array(banks - 1 downto 0) of STD_LOGIC_VECTOR(data_width - 1 downto 0);
    signal data_output_array : tp_memory_output;
    
    -- WEs
    type tp_we is
        array(banks - 1 downto 0, bank_depth - 1 downto 0) of STD_LOGIC;
    signal we_int : tp_we;
    
    -- BlockRAM input
    type tp_blockRAM_input is
        array(banks - 1 downto 0) of STD_LOGIC_VECTOR(data_width - 1 downto 0);
    signal blockRAM_input : tp_blockRAM_input;
    
    -- BlockRAM output
    type tp_blockRAM_output is
        array(banks - 1 downto 0, bank_depth - 1 downto 0) of STD_LOGIC_VECTOR(data_width - 1 downto 0);
    signal blockRAM_output : tp_blockRAM_output;
begin
    -- Type conversion
    conv: for i in banks - 1 downto 0 generate
        addrs_array(i)      <= vector_slice(addrs, i, log_2(bank_depth) + addr_width(data_width));
        data_input_array(i) <= vector_slice(data_input, i, data_width);
        data_output(((i + 1) * data_width) - 1 downto i * data_width) <= data_output_array(i);
    end generate;   
    
    -- Memory 
    banks_I: for i in banks - 1 downto 0  generate
        type tp_BRAM_no is
            array(banks - 1 downto 0) of STD_LOGIC_VECTOR(log_2(bank_depth) - 1 downto 0);
        signal BRAM_no            : tp_BRAM_no;
        signal BRAM_no_on_request : tp_BRAM_no;
    begin
        bank_I: for j in bank_depth - 1 downto 0 generate
            BRAM_no(i)   <= addrs_array(i)((log_2(bank_depth) + addr_width(data_width)) - 1 downto addr_width(data_width));
            we_int(i, j) <= '1' when we(i) = '1' AND to_uint(BRAM_no(i)) = j else '0';
            
            blockRAM_I: blockRAM generic map(data_width)
                port map(
                    clk         => clk,
                    rst         => rst,
                    addr        => addrs_array(i)(addr_width(data_width) - 1 downto 0),
                    data_input  => data_input_array(i),
                    we          => we_int(i, j),
                    data_output => blockRAM_output(i, j)
                );
        end generate;
        
        -- #BRAM latch
        BRAM_no_reg: reg generic map(bits => log_2(bank_depth))
            port map(clk, rst, '1', BRAM_no(i), BRAM_no_on_request(i));
        
        -- Data output mux
        data_output_array(i) <= blockRAM_output(i, to_uint(BRAM_no_on_request(i)));
    end generate;   
end memory_arch;