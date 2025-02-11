/*-
 ***********************************************************************
 *
 * $Id: ssl-pool.h,v 1.18 2019/03/14 16:07:43 klm Exp $
 *
 ***********************************************************************
 *
 * Copyright 2002-2019 The FTimes Project, All Rights Reserved.
 *
 ***********************************************************************
 */
#ifndef _SSL_POOL_H_INCLUDED
#define _SSL_POOL_H_INCLUDED

/*
 ***********************************************************************
 *
 * Defines
 *
 ***********************************************************************
 */
#define SSL_POOL_SEED 0x00000000
#define SSL_POOL_SIZE 0x00008000
#define SSL_POOL_TAPS (0) + (1)


/*
 ***********************************************************************
 *
 * Macros
 *
 ***********************************************************************
 */
#define SSL_NEW_POOL(aucPool, iLength, ulState)\
{\
  int i, j;\
  unsigned long ul = ulState;\
  for (i = 0; i < iLength; i++)\
  {\
    for (j = 0, aucPool[i] = 0; j < 8; j++)\
    {\
      aucPool[i] |= (ul & 1) << j;\
      ul = ((((ul >> 7) ^ (ul >> 6) ^ (ul >> 2) ^ (ul >> 0)) & 1) << 31) | (ul >> 1);\
    }\
  }\
}

#define SSL_TAP_POOL(aucTaps, aucPool)\
{\
  aucTaps[0] = 0;\
}

#endif /* !_SSL_POOL_H_INCLUDED */
