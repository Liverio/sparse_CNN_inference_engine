library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.types.all;

entity act_val_write_arbiter is
    port(
        clk : in STD_LOGIC;
        rst : in STD_LOGIC;
        -------------------
        -- PUs interface --
        -------------------
        requests       : in  tp_act_val_bank_requests;
        requests_valid : in  STD_LOGIC_VECTOR(PUs - 1 downto 0);
        served         : out STD_LOGIC_VECTOR(PUs - 1 downto 0)
    );
end act_val_write_arbiter;

architecture act_val_write_arbiter_arch of act_val_write_arbiter is
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
    
    component counter
        generic(
            bits : positive := 2;
            step : positive := 1
        );
        port(
            clk   : in  STD_LOGIC;
            rst   : in  STD_LOGIC;
            rst_2 : in  STD_LOGIC;
            inc   : in  STD_LOGIC;
            count : out STD_LOGIC_VECTOR(bits - 1 downto 0)
        );
    end component;
    
    component priority_encoder
        generic(
            input_width : natural := 2
        );
        port(
            input    : in  STD_LOGIC_VECTOR(input_width - 1 downto 0);
            found    : out STD_LOGIC;
            position : out STD_LOGIC_VECTOR(log_2(input_width) - 1 downto 0)
        );
    end component;
    
    -- Current master counter
    signal rst_current_master : STD_LOGIC;
    signal current_master     : STD_LOGIC_VECTOR(log_2(PUs) - 1 downto 0);
    
    -- Mask
    signal mask            : STD_LOGIC_VECTOR(PUs - 1 downto 0);
    signal requests_masked : STD_LOGIC_VECTOR(PUs - 1 downto 0);
    
    -- Selector
    signal request_found    : STD_LOGIC;
    signal request_to_serve : STD_LOGIC_VECTOR(log_2(PUs) - 1 downto 0);
begin
    -----------------------------------
    -- Circular priority arbitration --
    -----------------------------------
    current_master_I: counter
        generic map(
            bits => log_2(PUs),
            step => 1
        )
        port map(clk, rst, rst_current_master, '1', current_master);
    
    rst_current_master <= '1' when to_uint(current_master) = 2**log_2(PUs) - 1 else '0';

    ----------
    -- Mask --
    ----------
    mask_below_master: for i in 0 to PUs - 1 generate
        mask(i) <= '1' when 2**log_2(PUs) - 1 - to_uint(current_master) >= i else '0';
        
        requests_masked(i) <= requests_valid(i) AND mask(i);
    end generate;
    
    --------------
    -- Selector --
    --------------
    request_selector: priority_encoder
        generic map(
            input_width => PUs
        )
        port map(
            input    => requests_masked,
            found    => request_found,
            position => request_to_serve
        );
    
    -------------
    -- Outputs --
    -------------
    -- Processing unit whose request was served
    served_gen: for i in 0 to PUs - 1 generate
        served(i) <= '1' when request_found = '1' AND i = to_uint(request_to_serve) else '0';
    end generate;
end act_val_write_arbiter_arch;