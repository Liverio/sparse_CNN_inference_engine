library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.types.all;

entity act_val_read_crossbar is    
    port(
        clk : in STD_LOGIC;
        rst : in STD_LOGIC;
        ----------------------------------------------
        -- Activation values read arbiter interface --
        ----------------------------------------------
        bank_request        : in tp_act_val_bank_requests;
        bank_request_served : in STD_LOGIC_VECTOR(PUs - 1 downto 0);
        bank_request_addrs  : in tp_addrs_selected;
        ---------------------------------
        -- Activation memory interface --
        ---------------------------------
        act_val       : in  tp_act_val_mem_data;
        act_mem_addrs : out tp_act_val_mem_addr;
        -------------------
        -- PUs interface --
        -------------------
        MAC_act_val : out tp_MACs_act_input
    );
end act_val_read_crossbar;

architecture act_val_read_crossbar_arch of act_val_read_crossbar is
    component request_comparator
        generic(
            bank_no : integer := 0
        );
        port(
            bank_requests       : in  tp_act_val_bank_requests;
            bank_request_served : in  STD_LOGIC_VECTOR(PUs - 1 downto 0);
            unit_requesting     : out STD_LOGIC_VECTOR(PUs - 1 downto 0)
        );
    end component;
    
    component encoder
        generic(
            input_width : natural
        );
        port(
            input    : in  STD_LOGIC_VECTOR(input_width - 1 downto 0);
            position : out STD_LOGIC_VECTOR(log_2(input_width) - 1 downto 0)
        );
    end component;
    
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
    
    type tp_unit_requesting_array is
        array(0 to ACT_VAL_BANKS - 1) of STD_LOGIC_VECTOR(PUs - 1 downto 0); 
    
    type tp_unit_selected_array is
        array(0 to ACT_VAL_BANKS - 1) of STD_LOGIC_VECTOR(log_2(PUs) - 1 downto 0); 
        
    signal unit_requesting  : tp_unit_requesting_array;
    signal unit_selected    : tp_unit_selected_array;
    signal bank_request_reg : tp_act_val_bank_requests;
begin    
    --------------------------------------------
    -- Muxes to address the activation memory --
    --------------------------------------------
    act_mem_addr_muxes: for i in 0 to ACT_VAL_BANKS - 1 generate
        ------------------
        -- Mux selector --
        ------------------
        -- Request comparators to find which unit is requesting bank 'i'
        comparators: request_comparator
            generic map(
                bank_no => i
            )
            port map(
                bank_requests       => bank_request,
                bank_request_served => bank_request_served,
                unit_requesting     => unit_requesting(i)
            );
        
        -- Binary encoding of the one-hot encoded comparators output 
        encoders: encoder
            generic map(
                input_width => PUs
            )
            port map(
                input    => unit_requesting(i),
                position => unit_selected(i)
            );
            
        ----------------
        -- Mux inputs --
        ----------------
        act_mem_addrs(i) <= bank_request_addrs(to_uint(unit_selected(i)));
    end generate;
    
    ----------------------------
    -- Muxes to feed the MACs --
    ----------------------------
    MACs_inputs_muxes: for i in 0 to PUs - 1 generate
        -- Mux selector is the bank_no of the request
        bank_no_regs: reg generic map(bits => log_2(ACT_VAL_BANKS))
            port map(clk, rst, '1', bank_request(i), bank_request_reg(i));
            
        MAC_act_val(i) <= act_val(to_uint(bank_request_reg(i)));
    end generate;
end act_val_read_crossbar_arch;