library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.datapath_signals_pkg.all;


entity data_path is
   port(
      -- sinhronizacioni signali
      clk                 : in  std_logic;
      reset               : in  std_logic;
      -- interfejs ka memoriji za instrukcije
      instr_mem_address_o : out std_logic_vector (31 downto 0);
      instr_mem_read_i    : in  std_logic_vector(31 downto 0);
      instruction_o       : out std_logic_vector(31 downto 0);
      -- interfejs ka memoriji za podatke
      data_mem_address_o  : out std_logic_vector(31 downto 0);
      data_mem_write_o    : out std_logic_vector(31 downto 0);
      data_mem_read_i     : in  std_logic_vector (31 downto 0);
      -- kontrolni signali
      mem_to_reg_i        : in  std_logic;
      alu_op_i            : in  std_logic_vector (4 downto 0);
      alu_src_b_i         : in  std_logic;
      pc_next_sel_i       : in  std_logic;
      rd_we_i             : in  std_logic;
      branch_condition_o  : out std_logic;
      
      -----------------------------SIGNAL_IZ_CP-A_PREMA_DP-U_ZA_AUIPC-------------------
      auipc_sel_i         : in std_logic;  
      -----------------------------------------------------------------------------------      
      
      -- kontrolni signali za prosledjivanje operanada u ranije faze protocne obrade
      alu_forward_a_i     : in  std_logic_vector (1 downto 0);
      alu_forward_b_i     : in  std_logic_vector (1 downto 0);
      branch_forward_a_i  : in  std_logic;
      branch_forward_b_i  : in  std_logic;
      -- kontrolni signal za resetovanje if/id registra
      if_id_flush_i       : in  std_logic;
      -- kontrolni signali za zaustavljanje protocne obrade
      pc_en_i             : in  std_logic;
      if_id_en_i          : in  std_logic);

end entity;


architecture Behavioral of data_path is
begin

   --***********  Sekvencijalna logika  ******************
   --Programski brojac
   pc_proc : process (clk) is
   begin
      if (rising_edge(clk)) then
         if (reset = '0')then
            pc_reg_if_s <= (others => '0');
         elsif (pc_en_i = '1') then
            pc_reg_if_s <= pc_next_if_s;
         end if;
      end if;
   end process;

   --IF/ID registar
   if_id : process (clk) is
   begin
      if (rising_edge(clk)) then
         if(if_id_en_i = '1')then
            if (reset = '0' or if_id_flush_i = '1')then
               pc_reg_id_s      <= (others => '0');
               pc_adder_id_s    <= (others => '0');
               instruction_id_s <= (others => '0');
            else
               pc_reg_id_s      <= pc_reg_if_s;
               pc_adder_id_s    <= pc_adder_if_s;
               instruction_id_s <= instruction_if_s;
            end if;
         end if;
      end if;
   end process;

   --ID/EX registar
   id_ex : process (clk) is
   begin
      if (rising_edge(clk)) then
         if (reset = '0')then
            pc_adder_ex_s           <= (others => '0');
            rs1_data_ex_s           <= (others => '0');
            rs2_data_ex_s           <= (others => '0');
            immediate_extended_ex_s <= (others => '0');
            rd_address_ex_s         <= (others => '0');
            
            -----------------AUIPC---------------------
            imm_adder_ex_s          <= (others => '0');
            -------------------------------------------
            
         else
            pc_adder_ex_s           <= pc_adder_id_s;
            rs1_data_ex_s           <= rs1_data_id_s;
            rs2_data_ex_s           <= rs2_data_id_s;
            immediate_extended_ex_s <= immediate_extended_id_s;
            rd_address_ex_s         <= rd_address_id_s;
            
            -----------------AUIPC---------------------
            imm_adder_ex_s          <= imm_adder_id_s;
            -------------------------------------------
            
         end if;
      end if;
   end process;

   --EX/MEM registar
   ex_mem : process (clk) is
   begin
      if (rising_edge(clk)) then
         if (reset = '0')then
            alu_result_mem_s <= (others => '0');
            rs2_data_mem_s   <= (others => '0');
            pc_adder_mem_s   <= (others => '0');
            rd_address_mem_s <= (others => '0');
            
            -----------------AUIPC---------------------
            --imm_adder_mem_s  <= (others => '0');
            -------------------------------------------
            
         else
            alu_result_mem_s <= alu_result_ex_s;
            rs2_data_mem_s   <= alu_forward_b_ex_s;
            pc_adder_mem_s   <= pc_adder_ex_s;
            rd_address_mem_s <= rd_address_ex_s;
            
            -----------------AUIPC---------------------
            --imm_adder_mem_s  <= imm_adder_ex_s;
            -------------------------------------------
            
         end if;
      end if;
   end process;

   --MEM/WB registar
   mem_wb : process (clk) is
   begin
      if (rising_edge(clk)) then
         if (reset = '0')then
            alu_result_wb_s    <= (others => '0');
            pc_adder_wb_s      <= (others => '0');
            rd_address_wb_s    <= (others => '0');
            data_mem_read_wb_s <= (others => '0');
            
            -----------------AUIPC---------------------
            --imm_adder_wb_s     <= (others => '0');
            -------------------------------------------
            
         else
            alu_result_wb_s    <= alu_result_mem_s;
            pc_adder_wb_s      <= pc_adder_mem_s;
            rd_address_wb_s    <= rd_address_mem_s;
            data_mem_read_wb_s <= data_mem_read_mem_s;
            
            -----------------AUIPC---------------------
            --imm_adder_wb_s     <= imm_adder_mem_s;
            -------------------------------------------
            
         end if;
      end if;
   end process;




   --***********  Kombinaciona logika  ***************
   -- sabirac za uvecavanje programskog brojaca (sledeca instrukcija)
   pc_adder_if_s <= std_logic_vector(unsigned(pc_reg_if_s) + to_unsigned(4, 32));

   -- sabirac za uslovne skokove
   branch_adder_id_s <= std_logic_vector(signed(immediate_extended_id_s) + signed(pc_reg_id_s));
    
   ------------------------------------------AUIPC---------------------------------------------
   --za_realizaciju_auipc_ideja_je_iskoristiti_branch_adder_i_internom_signalu_imm_adder_id_s--
   --proslediti_vrednost_signala_branch_adder_id_s---------------------------------------------
   imm_adder_id_s <= branch_adder_id_s;
   --------------------------------------------------------------------------------------------
   
   -- multiplekseri za prosledjivanje operanada komparatoru za proveravanje uslova za skok
   branch_condition_a_ex_s <= alu_result_mem_s when branch_forward_a_i = '1' else
                              rs1_data_id_s;
   branch_condition_b_ex_s <= alu_result_mem_s when branch_forward_b_i = '1' else
                              rs2_data_id_s;

   -- provera uslova za skok
   branch_condition_o <= '1' when (signed(branch_condition_a_ex_s) = signed(branch_condition_b_ex_s)) else
                         '0';

   -- multiplekser za azuriranje programskog brojaca
   with pc_next_sel_i select
      pc_next_if_s <= pc_adder_if_s when '0',
      branch_adder_id_s             when others;

   -- multiplekseri za prosledjivanje operanada iz kasnijih faza pajplajna
   alu_forward_a_ex_s <= rd_data_wb_s when alu_forward_a_i = "01" else
                         alu_result_mem_s when alu_forward_a_i = "10" else
                         rs1_data_ex_s;
   alu_forward_b_ex_s <= rd_data_wb_s when alu_forward_b_i = "01" else
                         alu_result_mem_s when alu_forward_b_i = "10" else
                         rs2_data_ex_s;

   -- multiplekser za biranje 'b' operanda alu jedinice
   b_ex_s <= immediate_extended_ex_s when alu_src_b_i = '1' else
             alu_forward_b_ex_s;

   a_ex_s <= alu_forward_a_ex_s;

   -- multiplekser koji selektuje sta se upisuje u odredisni registar
   rd_data_wb_s <= data_mem_read_wb_s when mem_to_reg_i = '1' else
                   alu_result_wb_s;
                   
   --------------------------AUIPC-------------------------------------
   -----------dodatni_mux_za_AUIPC_instrukciju_u_EX_fazi---------------
   alu_result_ex_s <= imm_adder_ex_s when auipc_sel_i = '1' else
                      alu_mux_ex_s;
   --------------------------------------------------------------------

   -- izdvoji adrese opereanada iz 32-bitne instrukcije
   rs1_address_id_s <= instruction_id_s(19 downto 15);
   rs2_address_id_s <= instruction_id_s(24 downto 20);
   rd_address_id_s  <= instruction_id_s(11 downto 7);

   --***********  Instanciranje modula ***********
   -- Registarska banka
   register_bank_1 : entity work.register_bank
      generic map (
         WIDTH => 32)
      port map (
         clk           => clk,
         reset         => reset,
         rd_we_i       => rd_we_i,
         rs1_address_i => rs1_address_id_s,
         rs2_address_i => rs2_address_id_s,
         rs1_data_o    => rs1_data_id_s,
         rs2_data_o    => rs2_data_id_s,
         rd_address_i  => rd_address_wb_s,
         -----------AUIPC--------------
         rd_data_i     => rd_data_wb_s);
         ------------------------------
         
   -- Jedinice za prosirivanje konstante (immediate)
   immediate_1 : entity work.immediate
      port map (
         instruction_i        => instruction_id_s,
         immediate_extended_o => immediate_extended_id_s);

   -- ALU jedinica
   ALU_1 : entity work.ALU
      generic map (
         WIDTH => 32)
      port map (
         a_i    => a_ex_s,
         b_i    => b_ex_s,
         op_i   => alu_op_i,
         -----------AUIPC-----------
         res_o  => alu_mux_ex_s,
         ---------------------------
         zero_o => alu_zero_ex_s,
         of_o   => alu_of_ex_s);

   --***********  Ulazi/Izlazi  ***************
   -- Ka controlpath-u
   instruction_o       <= instruction_id_s;
   
   ----------------AUIPC-----------------------
   --auipc_sel_i
   --------------------------------------------
   
   -- Sa memorijom za instrukcije
   instr_mem_address_o <= pc_reg_if_s;
   instruction_if_s    <= instr_mem_read_i;
   -- Sa memorijom za podatke
   data_mem_address_o  <= alu_result_mem_s;
   data_mem_write_o    <= rs2_data_mem_s;
   data_mem_read_mem_s <= data_mem_read_i;

end architecture;


