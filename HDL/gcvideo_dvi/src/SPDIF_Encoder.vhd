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
-- SPDIF_Encoder.vhd: A simple SPDIF encoder
--
-- Inspired (but then written from scratch) by the SPDIF encoder from
-- Mike Field at http://hamsterworks.co.nz/mediawiki/index.php/SPDIF_out
--
-- Clock/ClockEnable inputs must result in 384 times the sample frequency
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity SPDIF_Encoder is
  port (
    Clock54       : in  std_logic;
    Clock162      : in  std_logic;
    Clock162Enable: in  boolean;
    AudioLeft     : in  signed(15 downto 0);
    AudioRight    : in  signed(15 downto 0);
    EnableLeft    : in  boolean;
    SPDIF         : out std_logic
  );
end SPDIF_Encoder;

architecture Behavioral of SPDIF_Encoder is
  constant PREAMBLE_X: std_logic_vector(7 downto 0) := "00111001"; -- left, start of new audio block
  constant PREAMBLE_Y: std_logic_vector(7 downto 0) := "01101001"; -- right
  constant PREAMBLE_Z: std_logic_vector(7 downto 0) := "11001001"; -- left, not start of block

  type channel_t    is (CHAN_LEFT, CHAN_RIGHT);
  type shiftstate_t is (SHIFT_PREAMBLE, SHIFT_PREFIX, SHIFT_SAMPLE, SHIFT_STATUS, SHIFT_PARITY);
  type bitphase_t   is (PHASE_FIRST, PHASE_SECOND);

  signal subcode_bit    : natural range 0 to 191 := 0;
  signal channel_status : std_logic := '0';

  signal current_channel: channel_t    := CHAN_LEFT;
  signal shift_state    : shiftstate_t := SHIFT_PREAMBLE;
  signal shifter        : std_logic_vector(15 downto 0) := (others => '0');
  signal shifter_bits   : natural range 0 to 15;
  signal bit_phase      : bitphase_t := PHASE_FIRST;
  signal parity         : std_logic  := '1';
  signal spdif_out      : std_logic  := '1';

  signal shift_delay    : natural range 0 to 2 := 0;

  signal enable_slow     : std_logic;
  signal enable_slow_sync: std_logic_vector(2 downto 0);

begin

  -- create a signal that toggles when EnableLeft is true
  process(Clock54)
  begin
    if rising_edge(Clock54) then
      if EnableLeft then
        enable_slow <= not enable_slow;
      end if;
    end if;
  end process;

  process(Clock162, Clock162Enable)
  begin
    if rising_edge(Clock162) and Clock162Enable then
      -- sync EnableSlow into this clock domain
      enable_slow_sync <= enable_slow & enable_slow_sync(2 downto 1);

      if shift_delay = 0 then
        shift_delay <= 2;

        -- shift out the next bit
        if bit_phase   = PHASE_SECOND or
           shift_state = SHIFT_PREAMBLE then
          -- second half of bit (or preamble): flip if shifter is 1
          spdif_out <= spdif_out xor shifter(0);
          shifter   <= "0" & shifter(15 downto 1);
          bit_phase <= PHASE_FIRST;

          -- update parity
          if shift_state /= SHIFT_PREAMBLE then
            parity <= parity xor shifter(0);
          end if;
        else
          -- first half of bit: just flip
          spdif_out <= not spdif_out;
          bit_phase <= PHASE_SECOND;
        end if;
      else
        shift_delay <= shift_delay - 1;
      end if;

      -- check for new sample or empty shifter
      if enable_slow_sync(0) /= enable_slow_sync(1) then
        -- new sample, start from scratch at next bit
        -- (avoids synchronization issues)
        shifter_bits    <= 0;
        shift_delay     <= 0;
        shift_state     <= SHIFT_PREAMBLE;
        bit_phase       <= PHASE_SECOND;
        current_channel <= CHAN_LEFT;
      elsif shift_delay = 0 then
        if bit_phase = PHASE_SECOND or shift_state = SHIFT_PREAMBLE then
          if shifter_bits > 0 then
            shifter_bits <= shifter_bits - 1;
          else
            -- shifter is empty, move on to next state
            case shift_state is
              when SHIFT_PREAMBLE =>
                shift_state  <= SHIFT_PREFIX;
                shifter      <= (others => '0');
                shifter_bits <= 8 -1;

              when SHIFT_PREFIX =>
                shift_state  <= SHIFT_SAMPLE;
                if current_channel = CHAN_LEFT then
                  shifter <= std_logic_vector(AudioLeft);
                else
                  shifter <= std_logic_vector(AudioRight);
                end if;
                shifter_bits <= 16 -1;

              when SHIFT_SAMPLE =>
                shift_state  <= SHIFT_STATUS;
                shifter      <= (2 => channel_status, others => '0');
                shifter_bits <= 3 -1;

              when SHIFT_STATUS =>
                shift_state  <= SHIFT_PARITY;
                -- hack: this happens while the channel status is shifted out, so parity hasn't updated yet
                shifter      <= (0 => parity xor channel_status, others => '0');
                shifter_bits <= 1 -1;

              when SHIFT_PARITY =>
                -- new subframe
                shift_state  <= SHIFT_PREAMBLE;
                parity       <= '0';
                if current_channel = CHAN_LEFT then
                  -- same frame, other channel
                  current_channel <= CHAN_RIGHT;
                  shifter         <= x"00" & PREAMBLE_Y;
                else
                  -- new frame, new channel status bis
                  current_channel <= CHAN_LEFT;
                  if subcode_bit /= 0 then
                    -- new block
                    if subcode_bit = 190 then
                      -- set "copy allowed" bit
                      channel_status <= '1';
                    else
                      channel_status <= '0';
                    end if;
                    subcode_bit <= subcode_bit - 1;
                    shifter <= x"00" & PREAMBLE_Z;
                  else
                    subcode_bit <= 191;
                    shifter <= x"00" & PREAMBLE_X;
                  end if;

                end if;
                shifter_bits <= 8 -1;
            end case;
          end if;
        end if;
      end if;
    end if;
  end process;

  SPDIF <= spdif_out;

end Behavioral;

