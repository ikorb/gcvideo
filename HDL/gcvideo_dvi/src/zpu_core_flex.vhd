-- ZPU (flex variant)
--
-- Copyright 2004-2008 oharboe - �yvind Harboe - oyvind.harboe@zylin.com
--
-- Changes by Alastair M. Robinson, 2013
-- to allow the core to run from external RAM, and to balance performance and area.
-- The goal is to make the ZPU a useful support CPU for such tasks as loading
-- ROMs from SD Card, while keeping the area under 1,000 logic cells.
-- To this end, there are a number of generics which can be used to adjust the
-- speed / area balance.
--
-- The FreeBSD license
--
-- Redistribution and use in source and binary forms, with or without
-- modification, are permitted provided that the following conditions
-- are met:
--
-- 1. Redistributions of source code must retain the above copyright
--    notice, this list of conditions and the following disclaimer.
-- 2. Redistributions in binary form must reproduce the above
--    copyright notice, this list of conditions and the following
--    disclaimer in the documentation and/or other materials
--    provided with the distribution.
--
-- THIS SOFTWARE IS PROVIDED BY THE ZPU PROJECT ``AS IS'' AND ANY
-- EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
-- THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
-- PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
-- ZPU PROJECT OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
-- INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
-- (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
-- OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
-- HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
-- STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
-- ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
-- ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
--
-- The views and conclusions contained in the software and documentation
-- are those of the authors and should not be interpreted as representing
-- official policies, either expressed or implied, of the ZPU Project.


-- WARNING - the stack bit has changed from bit 26 to bit 30.
-- RTL code which relies upon this will need updating.
-- Provided the linkscripts and CPU are kept in sync,
-- this change should be essentially invisible to the user.


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.zpupkg.all;


entity zpu_core_flex is
  generic (
	IMPL_MULTIPLY : boolean; -- Self explanatory
	IMPL_COMPARISON_SUB : boolean; -- Include sub and (U)lessthan(orequal)
	IMPL_EQBRANCH : boolean; -- Include eqbranch and neqbranch
	IMPL_STOREBH : boolean; -- Include halfword and byte writes
	IMPL_LOADBH : boolean; -- Include halfword and byte reads
	IMPL_CALL : boolean; -- Include call
	IMPL_SHIFT : boolean; -- Include lshiftright, ashiftright and ashiftleft
	IMPL_XOR : boolean; -- include xor instruction
	EXECUTE_RAM : boolean; -- include support for executing code from outside the Boot ROM
	REMAP_STACK : boolean; -- Map the stack / Boot ROM to an address specific by "stackbit" - default 0x40000000
	stackbit : integer; -- Specify base address of stack - defaults to 0x40000000
	maxAddrBit : integer; -- Address up to 64 megabytes of RAM.
	maxAddrBitExternalRAM : integer; -- Max bit for Program Counter when EXECUTE_RAM is true
	maxAddrBitBRAM : integer -- Specify significant bits of BRAM.
  );
  port (
		clk                 : in std_logic;
		-- asynchronous reset signal
		reset               : in std_logic;
		-- this particular implementation of the ZPU does not
		-- have a clocked enable signal
		enable              : in  std_logic;
		in_mem_busy         : in  std_logic;
		mem_read            : in  std_logic_vector(wordSize-1 downto 0);
		mem_write           : out std_logic_vector(wordSize-1 downto 0);
		out_mem_addr        : out std_logic_vector(MaxAddrBit downto 0);
		out_mem_writeEnable : out std_logic;
		out_mem_bEnable : out std_logic;  -- Enable byte write
		out_mem_hEnable : out std_logic;  -- Enable halfword write
		out_mem_readEnable  : out std_logic;
		-- Set to one to jump to interrupt vector
		-- The ZPU will communicate with the hardware that caused the
		-- interrupt via memory mapped IO or the interrupt flag can
		-- be cleared automatically
		interrupt           : in  std_logic;
		-- Signal that the break instruction is executed, normally only used
		-- in simulation to stop simulation
		break               : out std_logic;
		from_rom : in ZPU_FromROM;
		to_rom : out ZPU_ToROM
	);
end zpu_core_flex;


architecture behave of zpu_core_flex is

  -- start byte address of stack.
  -- point to top of RAM - 2*words
  constant spStart : std_logic_vector(MaxAddrBit downto 0) :=
    std_logic_vector(to_unsigned((2**(maxAddrBitBRAM+1))-8, MaxAddrBit+1));

  signal memAWriteEnable : std_logic;
  signal memAAddr        : unsigned(maxAddrBitBRAM downto minAddrBit);
  signal memAWrite       : unsigned(wordSize-1 downto 0);
  signal memARead        : unsigned(wordSize-1 downto 0);
  signal memBWriteEnable : std_logic;
  signal memBAddr        : unsigned(maxAddrBitBRAM downto minAddrBit);
  signal memBWrite       : unsigned(wordSize-1 downto 0);
  signal memBRead        : unsigned(wordSize-1 downto 0);

  signal pc : unsigned(maxAddrBit downto 0);  -- Synthesis tools should reduce this automatically
  signal sp : unsigned(maxAddrBitBRAM downto minAddrBit);

  -- this signal is set upon executing an IM instruction
  -- the subsequence IM instruction will then behave differently.
  -- all other instructions will clear the idim_flag.
  -- this yields highly compact immediate instructions.
  signal idim_flag  : std_logic;
  --
  signal busy       : std_logic;
  --
  signal begin_inst : std_logic;
  signal fetchneeded : std_logic;

  signal trace_opcode      : std_logic_vector(7 downto 0);
  signal trace_pc          : std_logic_vector(MaxAddrBit downto 0);
  signal trace_sp          : std_logic_vector(MaxAddrBit downto minAddrBit);
  signal trace_topOfStack  : std_logic_vector(wordSize-1 downto 0);
  signal trace_topOfStackB : std_logic_vector(wordSize-1 downto 0);

  -- state machine.
  type State_Type is (
    State_Fetch,
    State_WriteIODone,
    State_Execute,
    State_StoreToStack,
    State_Add,
    State_Or,
    State_And,
    State_Xor,
    State_Store,
    State_ReadIO,
    State_ReadIOBH,
    State_WriteIO,
    State_WriteIOBH,
    State_Load,
    State_FetchNext,
    State_AddSP,
    State_AddSP2,
    State_ReadIODone,
    State_Decode,
    State_Resync,
    State_Interrupt,
	 State_Mult,
	 State_Comparison,
	 State_EqNeq,
	 State_Sub,
	 State_IncSP,
	 State_Shift
    );

  type DecodedOpcodeType is (
    Decoded_Nop,
    Decoded_Im,
    Decoded_ImShift,
    Decoded_LoadSP,
    Decoded_StoreSP ,
    Decoded_AddSP,
    Decoded_Emulate,
    Decoded_Break,
    Decoded_PushSP,
    Decoded_PopPC,
    Decoded_Add,
    Decoded_Or,
    Decoded_And,
    Decoded_Load,
    Decoded_LoadBH,
    Decoded_Not,
    Decoded_Xor,
    Decoded_Flip,
    Decoded_Store,
    Decoded_StoreBH,
    Decoded_PopSP,
    Decoded_Interrupt,
	 Decoded_Mult,
	 Decoded_Sub,
	 Decoded_Comparison,
	 Decoded_EqNeq,
	 Decoded_EqBranch,
	 Decoded_Call,
	 Decoded_Shift
    );


  signal programword : std_logic_vector(wordSize-1 downto 0);
  signal inrom : std_logic;
  signal sampledOpcode        : std_logic_vector(OpCode_Size-1 downto 0);
  signal opcode               : std_logic_vector(OpCode_Size-1 downto 0);
  signal opcode_saved         : std_logic_vector(OpCode_Size-1 downto 0);
  --
  signal decodedOpcode        : DecodedOpcodeType;
  signal sampledDecodedOpcode : DecodedOpcodeType;


  signal  state              : State_Type;
  --
  subtype AddrBitBRAM_range is natural range maxAddrBitBRAM downto minAddrBit;
  signal  memAAddr_stdlogic  : std_logic_vector(AddrBitBRAM_range);
  signal  memAWrite_stdlogic : std_logic_vector(memAWrite'range);
  signal  memARead_stdlogic  : std_logic_vector(memARead'range);
  signal  memBAddr_stdlogic  : std_logic_vector(AddrBitBRAM_range);
  signal  memBWrite_stdlogic : std_logic_vector(memBWrite'range);
  signal  memBRead_stdlogic  : std_logic_vector(memBRead'range);
  --
  subtype index is integer range 0 to 3;
  --
  signal  tOpcode_sel        : index;
  --
  signal  inInterrupt        : std_logic;

  signal comparison_sub_result : unsigned(wordSize downto 0); -- Extra bit needed for signed comparisons
  signal comparison_sign_mod : std_logic;
  signal comparison_eq : std_logic;

  signal eqbranch_zero : std_logic;

  signal shift_done : std_logic;
  signal shift_sign : std_logic;
  signal shift_count : unsigned(5 downto 0);
  signal shift_reg : unsigned(31 downto 0);
  signal shift_direction : std_logic;

  signal add_low : unsigned(17 downto 0);


  function selectconstant(cond : boolean;
		int1 : integer;
		int2 : integer)
         return integer is
      begin
			if cond=true then
            return int1;
         else
            return int2;
         end if;
      end function selectconstant;

	constant pcmaxbit : integer := selectconstant(REMAP_STACK,stackbit-1,
				selectconstant(EXECUTE_RAM,maxAddrBitExternalRAM,maxAddrBitBRAM));

	constant pcmaxbitincstack : integer := selectconstant(REMAP_STACK,stackbit,
				selectconstant(EXECUTE_RAM,maxAddrBitExternalRAM,maxAddrBitBRAM));

begin


	memAAddr_stdlogic  <= std_logic_vector(memAAddr(AddrBitBRAM_range));
	memAWrite_stdlogic <= std_logic_vector(memAWrite);
	memBAddr_stdlogic  <= std_logic_vector(memBAddr(AddrBitBRAM_range));
	memBWrite_stdlogic <= std_logic_vector(memBWrite);

	-- Wire up the ROM

	memARead_stdlogic <= from_rom.memARead;
	memBRead_stdlogic <= from_rom.memBRead;

	to_rom.memAWriteEnable <= memAWriteEnable;
	to_rom.memAAddr(AddrBitBRAM_range) <= memAAddr_stdlogic;
	to_rom.memAWrite       <= memAWrite_stdlogic;
	to_rom.memBWriteEnable <= memBWriteEnable;
	to_rom.memBAddr(AddrBitBRAM_range) <= memBAddr_stdlogic;
	to_rom.memBWrite       <= memBWrite_stdlogic;

	memARead <= unsigned(memARead_stdlogic);
	memBRead <= unsigned(memBRead_stdlogic);


  tOpcode_sel <= to_integer(pc(minAddrBit-1 downto 0));

	CodeFromRAM: if EXECUTE_RAM=true generate
		inrom <='1' when pc(stackBit)='1' else '0';
		programword <= memBRead_stdlogic when inrom='1' else mem_read;
	end generate;
	CodeFromRAM2: if EXECUTE_RAM=false generate
		programword <= memBRead_stdlogic;
		inrom <='1';
	end generate;

  -- move out calculation of the opcode to a separate process
  -- to make things a bit easier to read
  decodeControl : process(programword, pc, tOpcode_sel)
    variable tOpcode : std_logic_vector(OpCode_Size-1 downto 0);
  begin

    -- simplify opcode selection a bit so it passes more synthesizers
    case (tOpcode_sel) is

      when 0 => tOpcode := std_logic_vector(programword(31 downto 24));

      when 1 => tOpcode := std_logic_vector(programword(23 downto 16));

      when 2 => tOpcode := std_logic_vector(programword(15 downto 8));

      when 3 => tOpcode := std_logic_vector(programword(7 downto 0));

      when others => tOpcode := std_logic_vector(programword(7 downto 0));
    end case;

    sampledOpcode <= tOpcode;

    if (tOpcode(7 downto 7) = OpCode_Im) then
      sampledDecodedOpcode <= Decoded_Im;
    elsif (tOpcode(7 downto 5) = OpCode_StoreSP) then
      sampledDecodedOpcode <= Decoded_StoreSP;
    elsif (tOpcode(7 downto 5) = OpCode_LoadSP) then
      sampledDecodedOpcode <= Decoded_LoadSP;
    elsif (tOpcode(7 downto 5) = OpCode_Emulate) then
      sampledDecodedOpcode <= Decoded_Emulate;
      if IMPL_CALL=true and tOpcode(5 downto 0) = OpCode_Call then
        sampledDecodedOpcode <= Decoded_Call;
      end if;
      if IMPL_MULTIPLY=true and tOpcode(5 downto 0) = OpCode_Mult then
        sampledDecodedOpcode <= Decoded_Mult;
      end if;
      if IMPL_XOR=true and tOpcode(5 downto 0) = OpCode_Xor then
        sampledDecodedOpcode <= Decoded_Xor;
      end if;
      if IMPL_COMPARISON_SUB=true then
        if tOpcode(5 downto 0) = OpCode_Eq
          or tOpcode(5 downto 0) = OpCode_Neq then
            sampledDecodedOpcode <= Decoded_EqNeq;
        elsif tOpcode(5 downto 0)= OpCode_Sub then
          sampledDecodedOpcode <= Decoded_Sub;
        elsif tOpcode(5 downto 0)= OpCode_Lessthanorequal
          or tOpcode(5 downto 0)= OpCode_Lessthan
          or tOpcode(5 downto 0)= OpCode_Ulessthanorequal
          or tOpcode(5 downto 0)= OpCode_Ulessthan
            then
          sampledDecodedOpcode <= Decoded_Comparison;
        end if;
      end if;
      if IMPL_EQBRANCH=true then
        if tOpcode(5 downto 0) = OpCode_EqBranch
          or tOpcode(5 downto 0)= OpCode_NeqBranch then
          sampledDecodedOpcode <= Decoded_EqBranch;
        end if;
      end if;
      if IMPL_STOREBH=true then
        if tOpcode(5 downto 0) = OpCode_StoreB
          or tOpcode(5 downto 0) = OpCode_StoreH then
          sampledDecodedOpcode <= Decoded_StoreBH;
        end if;
      end if;
      -- LOADB and LOADH don't do any bitshifting based on address- it's the supporting
      -- SOC's responsibility to make sure the result is in the low order bits.
      if IMPL_LOADBH=true then
        if tOpcode(5 downto 0) = OpCode_LoadB
          or tOpcode(5 downto 0) = OpCode_LoadH then
  --			if tOpcode(5 downto 0) = OpCode_LoadH then -- Disable LoadB for now, since it doesn't yet work.
          sampledDecodedOpcode <= Decoded_LoadBH;
        end if;
      end if;
      if IMPL_SHIFT=true then
        if tOpcode(5 downto 0) = OpCode_Lshiftright
          or tOpcode(5 downto 0) = OpCode_Ashiftright
          or tOpcode(5 downto 0) = OpCode_Ashiftleft then
          sampledDecodedOpcode <= Decoded_Shift;
        end if;
      end if;
    elsif (tOpcode(7 downto 4) = OpCode_AddSP) then
      sampledDecodedOpcode <= Decoded_AddSP;
    else
      case tOpcode(3 downto 0) is
        when OpCode_Break =>
          sampledDecodedOpcode <= Decoded_Break;
        when OpCode_PushSP =>
          sampledDecodedOpcode <= Decoded_PushSP;
        when OpCode_PopPC =>
          sampledDecodedOpcode <= Decoded_PopPC;
        when OpCode_Add =>
          sampledDecodedOpcode <= Decoded_Add;
        when OpCode_Or =>
          sampledDecodedOpcode <= Decoded_Or;
        when OpCode_And =>
          sampledDecodedOpcode <= Decoded_And;
        when OpCode_Load =>
          sampledDecodedOpcode <= Decoded_Load;
        when OpCode_Not =>
          sampledDecodedOpcode <= Decoded_Not;
        when OpCode_Flip =>
          sampledDecodedOpcode <= Decoded_Flip;
        when OpCode_Store =>
          sampledDecodedOpcode <= Decoded_Store;
        when OpCode_PopSP =>
          sampledDecodedOpcode <= Decoded_PopSP;
        when others =>
          sampledDecodedOpcode <= Decoded_Nop;
      end case;  -- tOpcode(3 downto 0)
    end if; -- tOpcode
  end process;


  opcodeControl: process(clk, reset)
    variable spOffset : unsigned(4 downto 0);
    variable tMultResult    : unsigned(wordSize*2-1 downto 0);
  begin


		if IMPL_COMPARISON_SUB=true and comparison_sub_result='0'&X"00000000" then
			comparison_eq<='1';
		else
			comparison_eq<='0';
		end if;

		if IMPL_SHIFT=true and shift_count="000000" then
			shift_done<='1';
		else
			shift_done<='0';
		end if;


-- Needs to happen outside the clock edge
	eqbranch_zero<='0';
	if IMPL_EQBRANCH=true and memBRead=X"00000000" then
		eqbranch_zero <='1';
	end if;

    if reset = '1' then
      state               <= State_Resync;
      break               <= '0';
      sp                  <= unsigned(spStart(maxAddrBitBRAM downto minAddrBit));
      pc                  <= (others => '0');
		if REMAP_STACK=true then
			pc(stackBit)		  <= '1';
		end if;
      idim_flag           <= '0';
      begin_inst          <= '0';
      memAAddr(AddrBitBRAM_range) <= (others => '0');
      memBAddr(AddrBitBRAM_range) <= (others => '0');
      memAWriteEnable     <= '0';
      memBWriteEnable     <= '0';
      out_mem_writeEnable <= '0';
      out_mem_readEnable  <= '0';
      out_mem_bEnable <= '0';
      out_mem_hEnable <= '0';
      memAWrite           <= (others => '0');
      memBWrite           <= (others => '0');
      inInterrupt         <= '0';
		fetchneeded			  <= '1';

    elsif (clk'event and clk = '1') then
      memAWriteEnable <= '0';
      memBWriteEnable <= '0';
      -- This saves ca. 100 LUT's, by explicitly declaring that the
      -- memAWrite can be left at whatever value if memAWriteEnable is
      -- not set.
      memAWrite       <= (others => DontCareValue);
      memBWrite       <= (others => DontCareValue);
--    out_mem_addr    <= (others => DontCareValue);
--    mem_write       <= (others => DontCareValue);
      spOffset        := (others => DontCareValue);

		-- We want memAAddr to remain stable since the length of the fetch depends on external RAM.
--      memAAddr        <= (others => DontCareValue);
--      memBAddr(AddrBitBRAM_range) <= (others => DontCareValue);

      out_mem_writeEnable <= '0';
--      out_mem_bEnable <= '0';
--      out_mem_hEnable <= '0';
      out_mem_readEnable  <= '0';
      begin_inst          <= '0';
--      out_mem_addr        <= std_logic_vector(memARead(MaxAddrBit downto 0));
--      mem_write           <= std_logic_vector(memBRead);

		decodedOpcode <= sampledDecodedOpcode;
		opcode <= sampledOpcode;

		if interrupt = '0' then
			inInterrupt <= '0';             -- no longer in an interrupt
		end if;

		-- Handle shift instructions
		IF IMPL_SHIFT=true then
			if shift_done='0' then
				if shift_direction='1' then
					shift_reg<=shift_reg(30 downto 0)&"0";	-- Shift left
				else
					shift_reg<=shift_sign&shift_reg(31 downto 1); -- Shift right
				end if;
				shift_count<=shift_count-1;
			end if;
		end if;

		-- Pipelining of addition
		add_low<=("00"&memARead(15 downto 0)) + ("00"&memBRead(15 downto 0));

		if IMPL_MULTIPLY=true then
			tMultResult := memARead * memBRead;
		end if;

		if IMPL_COMPARISON_SUB=true then
			comparison_sub_result<=unsigned('0'&memBRead)-unsigned('0'&memARead);
			comparison_sign_mod<=memARead(wordSize-1) xor memBRead(wordSize-1);
		end if;

      case state is

        when State_Execute =>
			 opcode_saved<=opcode;
          state <= State_Fetch;
          -- at this point:
          -- memBRead contains opcode word
          -- memARead contains top of stack
          pc(pcmaxbitincstack downto 0)    <= pc(pcmaxbitincstack downto 0) + 1;
			 if pc(1 downto 0)="11" then -- We fetch four bytes at a time.
				fetchneeded<='1';
			 end if;

          -- during the next cycle we'll be reading the next opcode
          spOffset(4)          := not opcode(4);
          spOffset(3 downto 0) := unsigned(opcode(3 downto 0));

          idim_flag <= '0';

          case decodedOpcode is

            when Decoded_Interrupt =>
              sp                             <= sp - 1;
              memAAddr(AddrBitBRAM_range)    <= sp - 1;
              memAWriteEnable                <= '1';
              memAWrite                      <= (others => DontCareValue);
              memAWrite(pcmaxbitincstack downto 0) <= pc(pcmaxbitincstack downto 0);
				  pc(pcmaxbit downto 0)	<= (others => '0');

              pc(5 downto 0) <= to_unsigned(32, 6);  -- interrupt address
				  fetchneeded<='1'; -- Need to set this any time PC changes.
              report "ZPU jumped to interrupt!" severity note;

            when Decoded_Im =>
              idim_flag       <= '1';
              memAWriteEnable <= '1';
              if (idim_flag = '0') then
                sp       <= sp - 1;
                memAAddr(AddrBitBRAM_range) <= sp-1;
                for i in wordSize-1 downto 7 loop
                  memAWrite(i) <= opcode(6);
                end loop;
                memAWrite(6 downto 0) <= unsigned(opcode(6 downto 0));
              else
                memAAddr(AddrBitBRAM_range) <= sp;
                memAWrite(wordSize-1 downto 7) <= memARead(wordSize-8 downto 0);
                memAWrite(6 downto 0)          <= unsigned(opcode(6 downto 0));
              end if;  -- idim_flag

            when Decoded_StoreSP =>
              memBWriteEnable <= '1';
              memBAddr(AddrBitBRAM_range) <= sp+spOffset;
              memBWrite       <= memARead;
              sp              <= sp + 1;
              state           <= State_Resync;

            when Decoded_LoadSP =>
              sp       <= sp - 1;
              memAAddr(AddrBitBRAM_range) <= sp+spOffset;

            when Decoded_Emulate =>
              sp                             <= sp - 1;
              memAWriteEnable                <= '1';
              memAAddr(AddrBitBRAM_range)    <= sp - 1;
              memAWrite                      <= (others => DontCareValue);
              memAWrite(pcmaxbitincstack downto 0) <= pc(pcmaxbitincstack downto 0) + 1;
              -- The emulate address is:
              --        98 7654 3210
              -- 0000 00aa aaa0 0000
              pc(pcmaxbit downto 0)	<= (others => '0');
              pc(9 downto 5)				<= unsigned(opcode(4 downto 0));
				  fetchneeded<='1'; -- Need to set this any time pc changes.


            when Decoded_AddSP =>
              memAAddr(AddrBitBRAM_range) <= sp;
              memBAddr(AddrBitBRAM_range) <= sp+spOffset;
              state    <= State_AddSP;

            when Decoded_Break =>
              report "Break instruction encountered" severity failure;
              break <= '1';

            when Decoded_PushSP =>
              memAWriteEnable                         <= '1';
              memAAddr(AddrBitBRAM_range)             <= sp - 1;
              sp                                      <= sp - 1;
              memAWrite                               <= (others => DontCareValue);
					if REMAP_STACK=true then
						memAWrite(MaxAddrBit) <='0'; -- Mark address as being in the stack
						memAWrite(stackBit) <='1'; -- Mark address as being in the stack
					end if;
					memAWrite(maxAddrBitBRAM downto minAddrBit) <= sp;

            when Decoded_PopPC =>
              pc(pcmaxbitincstack downto 0)    <= memARead(pcmaxbitincstack downto 0);
				  fetchneeded<='1'; -- Need to set this any time PC changes.
              sp    <= sp + 1;
              state <= State_Resync;

				when Decoded_EqBranch =>
					if IMPL_EQBRANCH=true then
						sp    <= sp + 1;
						if (eqbranch_zero xor opcode(0))='0' then -- eqbranch is 55, neqbranch is 56
							pc(pcmaxbit downto 0)    <= pc(pcmaxbit downto 0)+memARead(pcmaxbit downto 0);
							fetchneeded<='1'; -- Need to set this any time PC changes.
						end if;
						state <= State_IncSP;
					end if;

				when Decoded_Comparison =>
					if IMPL_COMPARISON_SUB=true then
						sp    <= sp + 1;
						state <= State_Comparison;
					end if;

            when Decoded_Add =>
              sp    <= sp + 1;
              state <= State_Add;

			   when Decoded_Sub =>
					if IMPL_COMPARISON_SUB=true then
						sp    <= sp + 1;
						state <= State_Sub;
					end if;

            when Decoded_Or =>
              sp    <= sp + 1;
              state <= State_Or;

            when Decoded_And =>
              sp    <= sp + 1;
              state <= State_And;

            when Decoded_Xor =>
              sp    <= sp + 1;
              state <= State_Xor;

				  when Decoded_Mult =>
              sp    <= sp + 1;
              state <= State_Mult;

            when Decoded_Load =>
              if (REMAP_STACK=true and
						memARead(stackbit-1)='0' and memARead(stackBit) = '1')
--						or (REMAP_STACK=false and memARead(MaxAddrBit)='0') then
						or (REMAP_STACK=false and memARead(MaxAddrBit downto maxAddrBitBRAM+1)=to_unsigned(0,MaxAddrBit-maxAddrBitBRAM)) then -- Access is bound for stack RAM
							memAAddr(AddrBitBRAM_range) <= memARead(AddrBitBRAM_range);
				  else
					 out_mem_addr(1 downto 0) <="00";
					 out_mem_addr(MaxAddrBit downto 2)<= std_logic_vector(memARead(MaxAddrBit downto 2));
                out_mem_readEnable <= '1';
                state              <= State_ReadIO;
             end if;

				 when Decoded_LoadBH =>
					if REMAP_STACK=true and memARead(stackbit-1)='0' and memARead(stackBit) = '1' then
					-- We don't try and cope with half or byte reads from Stack RAM so fall back to emulation...
						sp                             <= sp - 1;
						memAWriteEnable                <= '1';
						memAAddr(AddrBitBRAM_range)    <= sp - 1;
						memAWrite                      <= (others => DontCareValue);
						memAWrite(pcmaxbitincstack downto 0) <= pc(pcmaxbitincstack downto 0) + 1;
						-- The emulate address is:
						--        98 7654 3210
						-- 0000 00aa aaa0 0000
						pc(pcmaxbit downto 0)	<= (others => '0');
						pc(9 downto 5)				<= unsigned(opcode(4 downto 0));
						fetchneeded<='1'; -- Need to set this any time pc changes.
					else
						out_mem_addr(MaxAddrBit downto 0)<= std_logic_vector(memARead(MaxAddrBit downto 0));
						out_mem_bEnable <= opcode(0); -- Loadb is opcode 51, %00110011
						out_mem_hEnable <= not opcode(0); -- Loadh is opcode 34, %00100010
						out_mem_readEnable <= '1';
						state              <= State_ReadIOBH;
					end if;

				when Decoded_EqNeq =>
					sp <= sp + 1;
					state <= State_EqNeq;

            when Decoded_Not =>
              memAAddr(AddrBitBRAM_range) <= sp(maxAddrBitBRAM downto minAddrBit);
              memAWriteEnable <= '1';
              memAWrite       <= not memARead;

            when Decoded_Flip =>
              memAAddr(AddrBitBRAM_range) <= sp(maxAddrBitBRAM downto minAddrBit);
              memAWriteEnable <= '1';
              for i in 0 to wordSize-1 loop
                memAWrite(i) <= memARead(wordSize-1-i);
              end loop;

            when Decoded_Store =>
              memBAddr(AddrBitBRAM_range) <= sp + 1;
              sp       <= sp + 1;
              if (REMAP_STACK=true and memARead(stackbit-1)='0'	and memARead(stackBit) = '1')
--						or (REMAP_STACK=false and memARead(MaxAddrBit)='0') then
						or (REMAP_STACK=false and memARead(MaxAddrBit downto maxAddrBitBRAM+1)=to_unsigned(0,MaxAddrBit-maxAddrBitBRAM)) then -- Access is bound for stack RAM
                state <= State_Store;
				  else
                state <= State_WriteIO;
              end if;

				when Decoded_StoreBH =>
					if REMAP_STACK=true and memARead(stackbit-1)='0' and memARead(stackBit) = '1' then
						-- We don't try and cope with half or byte reads from Stack RAM so fall back to emulation...
						sp                             <= sp - 1;
						memAWriteEnable                <= '1';
						memAAddr(AddrBitBRAM_range)    <= sp - 1;
						memAWrite                      <= (others => DontCareValue);
						memAWrite(pcmaxbitincstack downto 0) <= pc(pcmaxbitincstack downto 0) + 1;
						-- The emulate address is:
						--        98 7654 3210
						-- 0000 00aa aaa0 0000
						pc(pcmaxbit downto 0)	<= (others => '0');
						pc(9 downto 5)				<= unsigned(opcode(4 downto 0));
						fetchneeded<='1'; -- Need to set this any time pc changes.
					else
						memBAddr(AddrBitBRAM_range) <= sp + 1;
						sp       <= sp + 1;
						state <= State_WriteIOBH;
					end if;

            when Decoded_PopSP =>
              sp    <= memARead(maxAddrBitBRAM downto minAddrBit);
              state <= State_Resync;

				when Decoded_Call =>
					if IMPL_CALL=true then
						pc(pcmaxbitincstack downto 0) <= memARead(pcmaxbitincstack downto 0); -- Set PC to value on top of stack
						fetchneeded<='1'; -- Need to set this any time PC changes.

						memAWriteEnable                <= '1';
						memAAddr(AddrBitBRAM_range)    <= sp; -- Replace stack top with PC+1
						memAWrite                      <= (others => DontCareValue);
						memAWrite(pcmaxbitincstack downto 0) <= pc(pcmaxbitincstack downto 0) + 1;
					end if;

				when Decoded_Shift =>
					IF IMPL_SHIFT=true then
						sp    <= sp + 1;
						shift_count<=unsigned(memARead(5 downto 0));	-- 6 bit distance
						shift_reg<=memBRead;	-- 32-bit value
						shift_direction<=opcode(0); -- 1 for left, (Opcode 43 for Ashiftleft)
						shift_sign<=memBRead(31) and opcode(2);  -- 1 for arithmetic, (opcode 44 for Ashiftright, 42 for lshiftright)
						state <= State_Shift;
					end if;

				when Decoded_Nop =>
              memAAddr(AddrBitBRAM_range) <= sp;

            when others =>
              null;

          end case;  -- decodedOpcode

		  -- From this point on opcode is not guaranteed to be valid if using BlockRAM.

        when State_ReadIO =>
				memAAddr(AddrBitBRAM_range) <= sp;
				if (in_mem_busy = '0') then
					state           <= State_Fetch;
					memAWriteEnable <= '1';
					memAWrite       <= unsigned(mem_read);
				end if;
				fetchneeded<='1'; -- Need to set this any time out_mem_addr changes.


        when State_ReadIOBH =>
				if IMPL_LOADBH=true then
					out_mem_bEnable <= opcode_saved(0); -- Loadb is opcode 51, %00110011
					out_mem_hEnable <= not opcode_saved(0); -- Loadh is copde 34, %00100010
					if in_mem_busy = '0' then
						memAAddr(AddrBitBRAM_range) <= sp;
--						memAWrite(31 downto 16)<=(others =>'0');
						memAWrite(31 downto 8)<=(others =>'0');
--						if opcode_saved(0)='1' then -- byte read; upper 24 bits should be zeroed
--							if memARead(0)='1' then -- odd address
--								memAWrite(7 downto 0) <= unsigned(mem_read(7 downto 0));
--							else
--								memAWrite(7 downto 0) <= unsigned(mem_read(15 downto 8));
--							end if;
--						else	-- short read; upper word should be zeroed.
						if opcode_saved(0)='0' then -- only write the top 8 bits for halfword reads
							memAWrite(15 downto 8) <= unsigned(mem_read(15 downto 8));
						end if;
						memAWrite(7 downto 0) <= unsigned(mem_read(7 downto 0));
--						end if;
						state           <= State_Fetch;
						memAWriteEnable <= '1';
						out_mem_bEnable	<=	'0';
						out_mem_hEnable	<=	'0';
					end if;
					fetchneeded<='1'; -- Need to set this any time out_mem_addr changes.
				end if;

		 when State_WriteIO =>
--			 mem_writeMask <= (others => '1');
          sp                  <= sp + 1;
          out_mem_writeEnable <= '1';
          out_mem_addr        <= std_logic_vector(memARead(MaxAddrBit downto 0));
          mem_write           <= std_logic_vector(memBRead);
          state               <= State_WriteIODone;
			 fetchneeded<='1'; -- Need to set this any time out_mem_addr changes.
									-- (actually, only necessary for writes if mem_read doesn't hold its contents)

			when State_WriteIOBH =>
				if IMPL_STOREBH=true then
--					mem_writeMask <= (others => '1');
					sp                  <= sp + 1;
					out_mem_writeEnable <= '1';
					out_mem_bEnable <= not opcode_saved(0); -- storeb is opcode 52
					out_mem_hEnable <= opcode_saved(0); -- storeh is opcode 35
					out_mem_addr        <= std_logic_vector(memARead(MaxAddrBit downto 0));
					mem_write           <= std_logic_vector(memBRead);
					state               <= State_WriteIODone;
					fetchneeded<='1'; -- Need to set this any time out_mem_addr changes.
											-- (actually, only necessary for writes if mem_read doesn't hold its contents)
				end if;

        when State_WriteIODone =>
          if (in_mem_busy = '0') then
            state <= State_Resync;
				out_mem_bEnable	<=	'0';
				out_mem_hEnable	<=	'0';
          end if;

        when State_Fetch =>
			 -- AMR - fetch from external RAM, not Block RAM.
			 if EXECUTE_RAM=true then -- Selectable
				out_mem_addr <= (others => '0');
				out_mem_addr(pcmaxbit downto 2)<=std_logic_vector(pc(pcmaxbit downto 2));
				out_mem_readEnable <= fetchneeded and not inrom;
			 end if;
          -- FIXME - don't refetch if data is still valid.

          -- We need to resync. During the *next* cycle
          -- we'll fetch the opcode @ pc and thus it will
          -- be available for State_Execute the cycle after
          -- next
          memBAddr(AddrBitBRAM_range) <= pc(maxAddrBitBRAM downto minAddrBit);
			 state    <= State_FetchNext;

        when State_FetchNext =>
          -- at this point memARead contains the value that is either
          -- from the top of stack or should be copied to the top of the stack
			 if in_mem_busy='0' or fetchneeded='0' or inrom='1' then
				 memAWriteEnable <= '1';
				 fetchneeded<='0';
				 memAWrite       <= memARead;
				 memAAddr(AddrBitBRAM_range) <= sp;
				 memBAddr(AddrBitBRAM_range) <= sp + 1;
				 state           <= State_Decode;
			 end if;

        when State_Decode =>
          if interrupt = '1' and inInterrupt = '0' and idim_flag = '0' then
            -- We got an interrupt, execute interrupt instead of next instruction
            inInterrupt   <= '1';
            decodedOpcode <= Decoded_Interrupt;
          end if;
          -- during the State_Execute cycle we'll be fetching SP+1  (AMR - already done at FetchNext, yes?)
          memAAddr(AddrBitBRAM_range) <= sp;
          memBAddr(AddrBitBRAM_range) <= sp + 1;
          state    <= State_Execute;

        when State_Store =>
          sp              <= sp + 1;
          memAWriteEnable <= '1';
          memAAddr(AddrBitBRAM_range) <= memARead(maxAddrBitBRAM downto minAddrBit);
          memAWrite       <= memBRead;
          state           <= State_Resync;

			when State_AddSP =>
				state <= State_AddSP2;

			when State_AddSP2 =>
              state    <= State_Add;

			when State_Add =>
				memAAddr(AddrBitBRAM_range) <= sp;
				memAWriteEnable <= '1';
				memAWrite(31 downto 16)<=memARead(31 downto 16)+memBRead(31 downto 16)+add_low(17 downto 16);
				memAWrite(15 downto 0) <= add_low(15 downto 0);
				state <= State_Fetch;

			when State_Sub =>
				memAAddr(AddrBitBRAM_range) <= sp;
				memAWriteEnable <= '1';
				memAWrite       <= comparison_sub_result(wordSize-1 downto 0);
				state           <= State_Fetch;

			when State_Mult =>
          memAAddr(AddrBitBRAM_range) <= sp;
          memAWriteEnable <= '1';
          memAWrite       <= tMultResult(wordSize-1 downto 0);
          state           <= State_Fetch;

		  when State_Or =>
          memAAddr(AddrBitBRAM_range) <= sp;
          memAWriteEnable <= '1';
          memAWrite       <= memARead or memBRead;
          state           <= State_Fetch;

		  when State_Xor =>
          memAAddr(AddrBitBRAM_range) <= sp;
          memAWriteEnable <= '1';
          memAWrite       <= memARead xor memBRead;
          state           <= State_Fetch;

			 when State_IncSP =>
				sp<=sp+1;
				state <= State_Resync;

        when State_Resync =>
          memAAddr(AddrBitBRAM_range) <= sp;
          state    <= State_Fetch;

        when State_And =>
          memAAddr(AddrBitBRAM_range) <= sp;
          memAWriteEnable <= '1';
          memAWrite       <= memARead and memBRead;
          state           <= State_Fetch;

		  when State_EqNeq =>
				memAAddr(AddrBitBRAM_range) <= sp;
				memAWriteEnable <= '1';
				memAWrite       <= (others =>'0');
				memAWrite(0) <= comparison_eq xor opcode_saved(4); -- eq is 46, neq is 48.
				state <= State_Fetch;

			when State_Comparison =>
				memAAddr(AddrBitBRAM_range) <= sp;
				memAWriteEnable <= '1';
				memAWrite <= (others => '0');
				-- ulessthan: opcode 38, ulessthanorequal, 39
				if opcode_saved(1)='1' then
					memAWrite(0) <= not (comparison_sub_result(wordSize)
												or (not opcode_saved(0) and comparison_eq));
				else	-- Signed comparison, lt: 36, ult: 37
					memAWrite(0) <= not ((comparison_sub_result(wordSize) xor comparison_sign_mod)
												or (not opcode_saved(0) and comparison_eq));
				end if;
				state <= State_Fetch;

			when State_Shift =>
				if shift_done='1' then
					memAAddr(AddrBitBRAM_range) <= sp;
					memAWriteEnable <= '1';
					memAWrite       <= shift_reg;
					state           <= State_Fetch;
				end if;

        when others =>
          null;

      end case;  -- state

    end if;  -- reset, enable
  end process;



end behave;
