library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.std_logic_unsigned.all;
use work.types.all;

entity pipeline is
    generic(
        unit_no : natural := 0
    );
    port(
        clk                             : in  STD_LOGIC;
        rst                             : in  STD_LOGIC;        
        new_product                     : in  STD_LOGIC;
        write_addr                      : in  STD_LOGIC_VECTOR(log_2(MAX_ACT_ELEMENTS) - 1 downto 0);
        convolution_step_done           : in  STD_LOGIC;
        convolution_done                : in  STD_LOGIC;
        new_product_pipelined           : out STD_LOGIC;
        write_addr_pipelined            : out STD_LOGIC_VECTOR(log_2(MAX_ACT_ELEMENTS) - 1 downto 0);
        convolution_step_done_pipelined : out STD_LOGIC;
        convolution_done_pipelined      : out STD_LOGIC
    );
end pipeline;

architecture pipeline_arch of pipeline is
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
begin
    pipeline_arch: if unit_no /= 0 generate
        type tp_pipeline_info is
            array(unit_no downto 1) of STD_LOGIC_VECTOR(1 + log_2(MAX_ACT_ELEMENTS) + 1 + 1 - 1 downto 0);
        signal pipeline       : tp_pipeline_info;
        signal pipeline_input : STD_LOGIC_VECTOR(1 + log_2(MAX_ACT_ELEMENTS) + 1 + 1 - 1 downto 0);
    begin
        pipeline_stages: for i in unit_no downto 1 generate
            first: if i = unit_no generate
                -- new_product + convolution_step_done + write_addr
                pipeline_info: reg generic map(bits => 1 + log_2(MAX_ACT_ELEMENTS) + 1 + 1)
                    port map(clk, rst, '1', pipeline_input, pipeline(i));
                
                pipeline_input <= new_product & write_addr & convolution_step_done & convolution_done;
            end generate;
            
            remaining: if i /= unit_no generate
                pipeline_info: reg generic map(bits => 1 + log_2(MAX_ACT_ELEMENTS) + 1 + 1)
                    port map(clk, rst, '1', pipeline(i + 1), pipeline(i));
            end generate;
        end generate;
        
        -- Outputs
        new_product_pipelined           <= '1' when pipeline(1)(1 + log_2(MAX_ACT_ELEMENTS) + 1 + 1 - 1 downto log_2(MAX_ACT_ELEMENTS) + 1 + 1) = "1" else '0';
        write_addr_pipelined            <=          pipeline(1)(    log_2(MAX_ACT_ELEMENTS) + 1 + 1 - 1 downto                           1 + 1);
        convolution_step_done_pipelined <= '1' when pipeline(1)(                              1 + 1 - 1 downto                               1) = "1" else '0';
        convolution_done_pipelined      <= '1' when pipeline(1)(                                  1 - 1 downto                               0) = "1" else '0';
    end generate;
    
    last_stage: if unit_no = 0 generate
        new_product_pipelined           <= new_product;
        write_addr_pipelined            <= write_addr;
        convolution_step_done_pipelined <= convolution_step_done;
        convolution_done_pipelined      <= convolution_done;
    end generate;
end pipeline_arch;

