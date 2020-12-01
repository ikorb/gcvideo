#ifndef EXO_DECR_ALREADY_INCLUDED
#define EXO_DECR_ALREADY_INCLUDED

/*
 * Copyright (c) 2005 Magnus Lind.
 *
 * This software is provided 'as-is', without any express or implied warranty.
 * In no event will the authors be held liable for any damages arising from
 * the use of this software.
 *
 * Permission is granted to anyone to use this software for any purpose,
 * including commercial applications, and to alter it and redistribute it
 * freely, subject to the following restrictions:
 *
 *   1. The origin of this software must not be misrepresented * you must not
 *   claim that you wrote the original software. If you use this software in a
 *   product, an acknowledgment in the product documentation would be
 *   appreciated but is not required.
 *
 *   2. Altered source versions must be plainly marked as such, and must not
 *   be misrepresented as being the original software.
 *
 *   3. This notice may not be removed or altered from any distribution.
 *
 *   4. The names of this software and/or it's copyright holders may not be
 *   used to endorse or promote products derived from this software without
 *   specific prior written permission.
 *
 * Taken from exomizer-3.0.2, slightly modified by Ingo Korb:
 * 1) avoid "might be used uninitialized" warnings in gcc 3.4.2
 * 2) add an output buffer size to exo_decrunch and enforce it
*/

char *exo_decrunch(const char *in, char *out, unsigned int outsize);

#endif /* EXO_DECRUNCH_ALREADY_INCLUDED */
