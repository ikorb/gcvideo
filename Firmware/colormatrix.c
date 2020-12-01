/* GCVideo DVI Firmware

   Copyright (C) 2015-2020, Ingo Korb <ingo@akana.de>
   All rights reserved.

   Redistribution and use in source and binary forms, with or without
   modification, are permitted provided that the following conditions are met:

   1. Redistributions of source code must retain the above copyright notice,
      this list of conditions and the following disclaimer.
   2. Redistributions in binary form must reproduce the above copyright notice,
      this list of conditions and the following disclaimer in the documentation
      and/or other materials provided with the distribution.

   THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
   AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
   IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
   ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
   LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
   CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
   SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
   INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
   CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
   ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF
   THE POSSIBILITY OF SUCH DAMAGE.


   colormatrix.c: color matrix-related things

*/

#include "portdefs.h"
#include "settings.h"
#include "utils.h"
#include "colormatrix.h"

int8_t picture_brightness;
int8_t picture_contrast;
int8_t picture_saturation;

#define FIXPT(x) ((short)((x) * 4096 + 0.5))

static const colormatrix_t matrix_rgblimited = {
  16,
  FIXPT( 1.000), FIXPT( 1.000), FIXPT(1.000),
  FIXPT(-0.336), FIXPT( 1.732),
  FIXPT( 1.371), FIXPT(-0.698)
};

static const colormatrix_t matrix_rgbfull = {
  0,
  FIXPT( 1.164), FIXPT( 1.164), FIXPT(1.164),
  FIXPT(-0.391), FIXPT( 2.018),
  FIXPT( 1.596), FIXPT(-0.813)
};

static const colormatrix_t matrix_ycbcr = {
  16,
  FIXPT(0.000), FIXPT(1.000), FIXPT(0.000),
  FIXPT(0.000), FIXPT(1.000),
  FIXPT(1.000), FIXPT(0.000)
};

colormatrix_t matrix_custon = {
  // default is a copy of RGB limited
  16,
  FIXPT( 1.000), FIXPT( 1.000), FIXPT(1.000),
  FIXPT(-0.336), FIXPT( 1.732),
  FIXPT( 1.371), FIXPT(-0.698)
};

const colormatrix_t* matrix_current;

static void apply_factor(short *value, int factor) {
  int tmp = ((int)*value) * factor / 128;
  clip_value(&tmp, -32768, 32767);
  *value = tmp;
}

void update_colormatrix(void) {
  colormatrix_t matrix;

  if (video_settings_global & VIDEOIF_SET_TEST_YCBCR) {
    matrix_current = &matrix_ycbcr;
  } else if ((video_settings_global & VIDEOIF_SET_COLORMODE_MASK) == VIDEOIF_SET_COLORMODE_RGBL) {
    matrix_current = &matrix_rgblimited;
  } else {
    matrix_current = &matrix_rgbfull;
  }

  /* apply image adjustments to matrix */
  matrix = *matrix_current;
  matrix.y_bias += picture_brightness;

  apply_factor(&matrix.yr_factor, picture_contrast + 128);
  apply_factor(&matrix.yg_factor, picture_contrast + 128);
  apply_factor(&matrix.yb_factor, picture_contrast + 128);

  int consat = (picture_contrast + 128) * (picture_saturation + 128) / 128;
  apply_factor(&matrix.cbg_factor, consat);
  apply_factor(&matrix.cbb_factor, consat);
  apply_factor(&matrix.crr_factor, consat);
  apply_factor(&matrix.crg_factor, consat);

  VIDEOIF->yr_factor_y_bias = (matrix.yr_factor  << 16) | (uint16_t)matrix.y_bias;
  VIDEOIF->yb_yg_factor     = (matrix.yb_factor  << 16) | (uint16_t)matrix.yg_factor;
  VIDEOIF->cbb_cbg_factor   = (matrix.cbb_factor << 16) | (uint16_t)matrix.cbg_factor;
  VIDEOIF->crg_crr_factor   = (matrix.crg_factor << 16) | (uint16_t)matrix.crr_factor;
}
