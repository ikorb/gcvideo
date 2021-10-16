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
-- video_defs.vhd: Video signal record definitions
--
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.ALL;

package video_defs is

  type console_mode_t is (MODE_GC, MODE_WII);
  type Pair_Swap_t is (Pair_Regular, Pair_Swapped);

  type VideoY422 is record
    PixelY       : unsigned(7 downto 0);
    PixelCbCr    : unsigned(7 downto 0);

    -- pixel-exact signals
    CurrentIsCb  : boolean; -- if true, Cb is updated in the current pixel
    Blanking     : boolean;
    HSync        : boolean;
    VSync        : boolean;
    CSync        : boolean;
    IsEvenField  : boolean;

    -- non-pixel-exact signals
    IsProgressive: boolean;
    IsPAL        : boolean;
    Is30kHz      : boolean;
  end record;

  type VideoYCbCr is record
    PixelY       : unsigned(7 downto 0);
    PixelCb      :   signed(7 downto 0);
    PixelCr      :   signed(7 downto 0);

    -- pixel-exact signals
    Blanking     : boolean;
    HSync        : boolean;
    VSync        : boolean;
    CSync        : boolean;
    IsEvenField  : boolean;

    -- non-pixel-exact signals
    IsProgressive: boolean;
    IsPAL        : boolean;
    Is30kHz      : boolean;
  end record;

  type VideoRGB is record
    PixelR       : unsigned(7 downto 0);
    PixelG       : unsigned(7 downto 0);
    PixelB       : unsigned(7 downto 0);

    -- pixel-exact signals
    Blanking     : boolean;
    HSync        : boolean;
    VSync        : boolean;
    CSync        : boolean;
    IsEvenField  : boolean;

    -- non-pixel-exact signals
    IsProgressive: boolean;
    IsPAL        : boolean;
    Is30kHz      : boolean;
  end record;

  type AudioData is record
    Left       : signed(15 downto 0);
    Right      : signed(15 downto 0);
    LeftEnable : boolean;
    RightEnable: boolean;
  end record;

  type OSDSettings_t is record
    BGAlpha   : unsigned(7 downto 0);
    BGTintCb  :   signed(7 downto 0);
    BGTintCr  :   signed(7 downto 0);
  end record;

  type ColorMatrix_t is record
    YBias    : signed( 9 downto 0); -- -127 to +144
    YRFactor : signed(15 downto 0); -- -8.00 to +7.999755, scaled by 4096
    YGFactor : signed(15 downto 0);
    YBFactor : signed(15 downto 0);
    CbGFactor: signed(15 downto 0);
    CbBFactor: signed(15 downto 0);
    CrRFactor: signed(15 downto 0);
    CrGFactor: signed(15 downto 0);
  end record;

  subtype HorizontalPixels is natural range 0 to 880;
  subtype VerticalPixels is natural range 0 to 880*650;
  subtype VerticalLines is natural range 0 to 625;

  type ReblankerSettings_t is record
    HSyncStart  : HorizontalPixels;
    HSyncEnd    : HorizontalPixels;
    HActiveStart: HorizontalPixels;
    HActiveEnd  : HorizontalPixels;
    VSyncStart  : VerticalPixels;
    VSyncEnd    : VerticalPixels;
    VActiveStart: VerticalLines;
    VActiveLines: VerticalLines;
  end record;

  type VideoSettings_t is record
    ScanlineProfile   : std_logic_vector(1 downto 0);
    ScanlinesAlternate: boolean;
    ScanlinesEven     : boolean;
    LinedoublerEnabled: boolean;
    DisableOutput     : boolean;
    CableDetect       : boolean;
    EnhancedMode      : boolean;
    Widescreen        : boolean;
    AnalogRGBOutput   : boolean;
    SyncOnGreen       : boolean;
    Volume            : unsigned(7 downto 0);
    EnableReblanking  : boolean;
    EnableResyncing   : boolean;
    RebuildCSync      : boolean;
    SampleRateHack    : boolean;
    InterpolateChroma : boolean;
    ColorMode         : std_logic_vector(1 downto 0);
    Matrix            : ColorMatrix_t;
    RBSettings        : ReblankerSettings_t;
  end record;

  type VideoMeasurements_t is record
    HTotal       : HorizontalPixels;
    HActiveStart : HorizontalPixels;
    VTotal       : VerticalPixels;
    VActiveStart0: VerticalLines;
    VHOffset0    : HorizontalPixels;
    VActiveStart1: VerticalLines;
    VHOffset1    : HorizontalPixels;
  end record;

  -- 8 bit unsigned to 9 bit signed, no modifications
  function mksigned(a: unsigned)
    return signed is
  begin
    return signed("0" & a);
  end function;

  function to_444_mono(vin: VideoY422)
    return VideoYCbCr is
    variable output: VideoYCbCr;
  begin
    output.PixelY        := vin.PixelY;
    output.PixelCb       := x"00";
    output.PixelCr       := x"00";
    output.Blanking      := vin.Blanking;
    output.HSync         := vin.HSync;
    output.VSync         := vin.VSync;
    output.CSync         := vin.CSync;
    output.IsEvenField   := vin.IsEvenField;
    output.IsProgressive := vin.IsProgressive;
    output.IsPAL         := vin.IsPAL;
    output.Is30kHz       := vin.Is30kHz;

    return output;
  end function;

  function to_rgb_mono(vin: VideoYCbCr)
    return VideoRGB is
    variable output: VideoRGB;
  begin
    output.PixelR        := vin.PixelY;
    output.PixelG        := vin.PixelY;
    output.PixelB        := vin.PixelY;
    output.Blanking      := vin.Blanking;
    output.HSync         := vin.HSync;
    output.VSync         := vin.VSync;
    output.CSync         := vin.CSync;
    output.IsEvenField   := vin.IsEvenField;
    output.IsProgressive := vin.IsProgressive;
    output.IsPAL         := vin.IsPAL;
    output.Is30kHz       := vin.Is30kHz;

    return output;
  end function;

  function to_422_mono(vin: VideoYCbCr)
    return VideoY422 is
    variable output: VideoY422;
  begin
    output.PixelY        := vin.PixelY;
    output.PixelCbCr     := x"80";
    output.CurrentIsCb   := true;
    output.Blanking      := vin.Blanking;
    output.HSync         := vin.HSync;
    output.VSync         := vin.VSync;
    output.CSync         := vin.CSync;
    output.IsEvenField   := vin.IsEvenField;
    output.IsProgressive := vin.IsProgressive;
    output.IsPAL         := vin.IsPAL;
    output.Is30kHz       := vin.Is30kHz;

    return output;
  end function;

end video_defs;

package body video_defs is
end video_defs;
