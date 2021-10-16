----------------------------------------------------------------------------------
-- GCVideo DVI HDL
-- Copyright (C) 2014-2021, Ingo Korb <ingo@akana.de>
-- All rights reserved.
--
-- Redistribution and use in source and binary forms, with or without
-- modification, are permitted provided that the following conditions are met:
--
-- 1. Redistributions of source code must retain the above copyright notice,
--    this list of conditions and the following disclaimer.
-- 2. Redistributions in binary form must reproduce the above copyright notice,
--    this list of conditions and the following disclaimer in the documentation
--    and/or other materials provided with the distribution.
--
-- THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
-- AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
-- IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
-- ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
-- LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
-- CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
-- SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
-- INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
-- CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
-- ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF
-- THE POSSIBILITY OF SUCH DAMAGE.
--
-- ZPUSignalDiag.vhd: signal diagnosis module
--
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use work.ZPUDevices.all;
use work.video_defs.all;

entity ZPUSignalDiag is
  port (
    Clock           : in  std_logic;
    ZSelect         : in  std_logic;
    ZPUBusIn        : in  ZPUDeviceIn;
    ZPUBusOut       : out ZPUDeviceOut;

    -- diagnosed signals
    VideoIn         : in  VideoY422;
    PixelClockEnable: in  boolean;
    I2S_BClock      : in  std_logic;
    I2S_LRClock     : in  std_logic;
    I2S_Data        : in  std_logic
  );
end ZPUSignalDiag;

architecture Behavioral of ZPUSignalDiag is

  signal prev_vsync  : boolean;
  signal current_line: VerticalLines;

  signal stuck_0_cur : std_logic_vector(7 downto 0);
  signal stuck_1_cur : std_logic_vector(7 downto 0);
  signal stuck_0_prev: std_logic_vector(7 downto 0);
  signal stuck_1_prev: std_logic_vector(7 downto 0);

  signal deglitch_bclock : std_logic_vector(2 downto 0);
  signal deglitch_lrclock: std_logic_vector(2 downto 0);
  signal deglitch_adata  : std_logic_vector(2 downto 0);

  signal bclock_glitches_cur  : unsigned(20 downto 0);
  signal lrclock_glitches_cur : unsigned(20 downto 0);
  signal adata_glitches_cur   : unsigned(20 downto 0);
  signal bclock_glitches_prev : unsigned(20 downto 0);
  signal lrclock_glitches_prev: unsigned(20 downto 0);
  signal adata_glitches_prev  : unsigned(20 downto 0);

  signal clean_bclock : std_logic;
  signal clean_lrclock: std_logic;
  signal clean_adata  : std_logic;

  signal prev_bclock : std_logic;
  signal prev_lrclock: std_logic;
  signal prev_adata  : std_logic;

  signal bclock_active_cur  : boolean;
  signal lrclock_active_cur : boolean;
  signal adata_active_cur   : boolean;
  signal bclock_active_prev : boolean;
  signal lrclock_active_prev: boolean;
  signal adata_active_prev  : boolean;

  function majority(v: std_logic_vector(2 downto 0))
    return std_logic is
  begin
    case v is
      when "000"  => return '0';
      when "001"  => return '0';
      when "010"  => return '0';
      when "011"  => return '1';
      when "100"  => return '0';
      when "101"  => return '1';
      when "110"  => return '1';
      when "111"  => return '1';
      when others => return 'U';
    end case;
  end function;

begin

  ZPUBusOut.mem_busy <= '0';

  -- ZPU interface
  process(Clock)
  begin
    if rising_edge(Clock) then
      ZPUBusOut.mem_read <= (others => '0');

      if ZSelect = '1' and ZPUBusIn.mem_readEnable = '1' then
        case ZPUBusIn.mem_addr(4 downto 2) is
          when "000" =>
            ZPUBusOut.mem_read(7 downto 0) <= stuck_0_prev;

          when "001" =>
            ZPUBusOut.mem_read(7 downto 0) <= stuck_1_prev;

          when "010" =>
            if bclock_active_prev then
              ZPUBusOut.mem_read(0) <= '1';
            end if;

            if lrclock_active_prev then
              ZPUBusOut.mem_read(1) <= '1';
            end if;

            if adata_active_prev then
              ZPUBusOut.mem_read(2) <= '1';
            end if;

          when "011" =>
            ZPUBusOut.mem_read(20 downto 0) <= std_logic_vector(bclock_glitches_prev);

          when "100" =>
            ZPUBusOut.mem_read(20 downto 0) <= std_logic_vector(lrclock_glitches_prev);

          when "101" =>
            ZPUBusOut.mem_read(20 downto 0) <= std_logic_vector(adata_glitches_prev);

          when others => null;

        end case;
      end if;
    end if;
  end process;

  -- signal analysis
  process(Clock)
    variable luma_cur  : unsigned(7 downto 0);
  begin
    if rising_edge(Clock) then
      ---- audio signals
      deglitch_bclock  <= deglitch_bclock(1 downto 0)  & I2S_BClock;
      deglitch_lrclock <= deglitch_lrclock(1 downto 0) & I2S_LRClock;
      deglitch_adata   <= deglitch_adata(1 downto 0)   & I2S_Data;

      if deglitch_bclock = "010" or deglitch_bclock = "101" then
        bclock_glitches_cur <= bclock_glitches_cur + 1;
      end if;

      if deglitch_lrclock = "010" or deglitch_lrclock = "101" then
        lrclock_glitches_cur <= lrclock_glitches_cur + 1;
      end if;

      if deglitch_adata = "010" or deglitch_adata = "101" then
        adata_glitches_cur <= adata_glitches_cur + 1;
      end if;

      clean_bclock  <= majority(deglitch_bclock);
      clean_lrclock <= majority(deglitch_lrclock);
      clean_adata   <= majority(deglitch_adata);

      prev_bclock  <= clean_bclock;
      prev_lrclock <= clean_lrclock;
      prev_adata   <= clean_adata;

      bclock_active_cur  <= bclock_active_cur  or (clean_bclock  /= prev_bclock);
      lrclock_active_cur <= lrclock_active_cur or (clean_lrclock /= prev_lrclock);
      adata_active_cur   <= adata_active_cur   or (clean_adata   /= prev_adata);

     ---- video signals and per-frame reset
      if PixelClockEnable then
        prev_vsync <= VideoIn.VSync;

        if prev_vsync and not VideoIn.VSync then
          -- start of frame
          stuck_0_prev           <= stuck_0_cur;
          stuck_1_prev           <= stuck_1_cur;
          bclock_glitches_prev   <= bclock_glitches_cur;
          lrclock_glitches_prev  <= lrclock_glitches_cur;
          adata_glitches_prev    <= adata_glitches_cur;
          bclock_active_prev     <= bclock_active_cur;
          lrclock_active_prev    <= lrclock_active_cur;
          adata_active_prev      <= adata_active_cur;

          stuck_0_cur           <= (others => '1');
          stuck_1_cur           <= (others => '1');
          bclock_glitches_cur   <= (others => '0');
          lrclock_glitches_cur  <= (others => '0');
          adata_glitches_cur    <= (others => '0');
          bclock_active_cur     <= false;
          lrclock_active_cur    <= false;
          adata_active_cur      <= false;

        else
          -- eval current pixel
          luma_cur := VideoIn.PixelY + x"10";

          stuck_0_cur <= stuck_0_cur and std_logic_vector(not luma_cur)
                         and std_logic_vector(not VideoIn.PixelCbCr);

          stuck_1_cur <= stuck_1_cur and std_logic_vector(luma_cur)
                         and std_logic_vector(VideoIn.PixelCbCr);
        end if;
      end if;
    end if;
  end process;

end Behavioral;
