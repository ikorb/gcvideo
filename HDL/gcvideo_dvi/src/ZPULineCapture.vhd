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
-- ZPULineCapture.vhd: video data capture module
--
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use work.ZPUDevices.all;
use work.video_defs.all;

entity ZPULineCapture is
  port (
    Clock           : in  std_logic;
    ZSelect         : in  std_logic;
    ZPUBusIn        : in  ZPUDeviceIn;
    ZPUBusOut       : out ZPUDeviceOut;
    VideoIn         : in  VideoY422;
    PixelClockEnable: in  boolean
  );
end ZPULineCapture;

architecture Behavioral of ZPULineCapture is
  type line_ram_type is array(0 to 1023) of std_logic_vector(15 downto 0);
  type capture_type is array(0 to 255) of std_logic;
  type capture_state_type is (STATE_IDLE, STATE_WAIT, STATE_SYNCFOUND, STATE_CAPTURE);

  signal linebuffer      : line_ram_type := (others => (others => '0'));
  signal lines_to_capture: capture_type;
  signal capture_state   : capture_state_type := STATE_IDLE;

  signal write_delay  : std_logic := '0';
  signal write_capture: boolean := false;
  signal addr_cpu     : std_logic_vector(9 downto 0) := (others => '0');
  signal addr_capture : natural range 0 to 1023 := 0;
  signal data_capture : std_logic_vector(15 downto 0);
  signal selected_page: std_logic_vector(7 downto 0);
  signal use_marker   : boolean;

  signal prev_blanking: boolean;
  signal prev_vsync   : boolean;
  signal current_line : VerticalLines;

begin

  ZPUBusOut.mem_read(30 downto 16) <= (others => '0');
  ZPUBusOut.mem_read(31) <= '0' when capture_state = STATE_IDLE else '1';

  process(Clock)
  begin
    if rising_edge(Clock) then
      ----- ZPU side
      -- delay one cycle on reads
      ZPUBusOut.mem_busy <= ZPUBusIn.mem_readEnable;

      -- always read
      ZPUBusOut.mem_read(15 downto 0) <=
        linebuffer(to_integer(unsigned(addr_cpu)));

      -- write if it was active
      if write_delay = '1' then
        linebuffer(to_integer(unsigned(addr_cpu))) <=
          ZPUBusIn.mem_write(15 downto 0);
      end if;
      write_delay <= '0';

      -- capture address to register
      addr_cpu <= ZPUBusIn.mem_addr(11 downto 2);

      -- capture write signal for next cycle
      if ZSelect = '1' and ZPUBusIn.mem_writeEnable = '1' then
        write_delay <= '1';

        if ZPUBusIn.mem_addr(11 downto 10) = "11" then
          -- top 256 words are the line-needed-flags
          lines_to_capture(to_integer(unsigned(ZPUBusIn.mem_addr(9 downto 2))))
            <= ZPUBusIn.mem_write(0);

          if ZPUBusIn.mem_addr(11 downto 2) = "11" & x"ff" then
            -- last word is page select
            selected_page <= ZPUBusIn.mem_write(7 downto 0);

            -- page 0 is markerless capture
            use_marker <= (ZPUBusIn.mem_write(7 downto 0) /= x"00");
          end if;

        elsif capture_state = STATE_IDLE then
          -- write accesses elsewhere re-arms if idle
          capture_state <= STATE_WAIT;
        end if;

      end if;

      ----- capture side
      if write_capture then
        linebuffer(addr_capture) <= data_capture;
        addr_capture             <= addr_capture + 1;
        write_capture            <= false;
      end if;

      -- line capture
      if PixelClockEnable then
        prev_blanking <= VideoIn.Blanking;
        prev_vsync    <= VideoIn.VSync;

        if prev_vsync and not VideoIn.VSync then
          current_line <= 0;
        elsif not prev_blanking and VideoIn.Blanking then
          -- increment at end of line
          current_line <= current_line + 1;
        end if;

        case capture_state is
          when STATE_IDLE =>
            -- do nothing until armed
            null;

          when STATE_WAIT =>
            if prev_blanking and not VideoIn.Blanking then
              -- at start of line
              if not use_marker or (VideoIn.PixelY = x"55" and VideoIn.PixelCbCr = x"aa") then
                -- marker found (or markerless capture)
                capture_state <= STATE_SYNCFOUND;
                addr_capture  <= 0;
              end if;
            end if;

          when STATE_SYNCFOUND =>
            if (use_marker and lines_to_capture(to_integer(VideoIn.PixelY)) = '1' and
                std_logic_vector(VideoIn.PixelCbCr) = selected_page) or
               (not use_marker and lines_to_capture(current_line) = '1') then
              -- line is wanted, start capturing from this pixel
              capture_state <= STATE_CAPTURE;
              addr_capture  <= 0;
              data_capture  <= std_logic_vector(VideoIn.PixelY & VideoIn.PixelCbCr);
              write_capture <= true;
              lines_to_capture(to_integer(VideoIn.PixelY)) <= '0';
            else
              capture_state <= STATE_WAIT;
            end if;

          when STATE_CAPTURE =>
            if VideoIn.Blanking then
              -- end of line
              capture_state <= STATE_IDLE;
            else
              -- capture pixel
              data_capture  <= std_logic_vector(VideoIn.PixelY & VideoIn.PixelCbCr);
              write_capture <= true;
            end if;

        end case;
      end if;

    end if;
  end process;

end Behavioral;
