library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.types.all;

entity act_val_write_crossbar is    
    port(
        -----------------------------------------------
        -- Activation values write arbiter interface --
        -----------------------------------------------
        bank_requests_served : in STD_LOGIC_VECTOR(PUs - 1 downto 0);
        -------------------
        -- PUs interface --
        -------------------
        bank_requests       : in tp_act_val_bank_requests;
        bank_requests_addrs : in tp_new_act_val_addr_requests;
        requests_values     : in tp_new_act_val_requests;
        ----------------------------------------
        -- Activation values memory interface --
        ----------------------------------------
        act_mem_write  : out STD_LOGIC_VECTOR(ACT_VAL_BANKS - 1 downto 0);
        act_mem_addrs  : out tp_act_val_mem_addr;
        act_mem_values : out tp_act_val_mem_data
    );
end act_val_write_crossbar;

architecture act_val_write_crossbar_arch of act_val_write_crossbar is
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

    type tp_unit_requesting_array is
        array(0 to ACT_VAL_BANKS - 1) of STD_LOGIC_VECTOR(PUs - 1 downto 0); 
    signal unit_requesting : tp_unit_requesting_array;
    
    type tp_unit_selected_array is
        array(0 to ACT_VAL_BANKS - 1) of STD_LOGIC_VECTOR(log_2(PUs) - 1 downto 0); 
    signal unit_selected : tp_unit_selected_array;
begin    
    -----------------------------------------------------
    -- Muxes to address and feed the activation memory --
    -----------------------------------------------------
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
                bank_requests       => bank_requests,
                bank_request_served => bank_requests_served,
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
            
        ------------------
        -- Write enable --
        ------------------
        act_mem_write(i) <= '1' when unit_requesting(i) /= std_logic_vector(to_unsigned(0, PUs)) else '0';
        
        -----------------------
        -- Addres mux inputs --
        -----------------------
        act_mem_addrs(i) <= bank_requests_addrs(to_uint(unit_selected(i)));
        
        ----------------------
        -- Value mux inputs --
        ----------------------
        act_mem_values(i) <= requests_values(to_uint(unit_selected(i)));
    end generate;    
end act_val_write_crossbar_arch;