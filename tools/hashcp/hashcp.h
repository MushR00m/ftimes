/*-
 ***********************************************************************
 *
 * $Id: hashcp.h,v 1.5 2013/02/14 16:55:22 mavrik Exp $
 *
 ***********************************************************************
 *
 * Copyright 2009-2013 The FTimes Project, All Rights Reserved.
 *
 ***********************************************************************
 */

/*-
 ***********************************************************************
 *
 * Defines
 *
 ***********************************************************************
 */
#define PROGRAM_NAME "hashcp"

#define XER_OK    0
#define XER_Usage 1
#define XER_Abort 2

#define HASHCP_MAX_MD5_LENGTH (((MD5_HASH_SIZE)*2)+1)
#define HASHCP_MAX_SHA1_LENGTH (((SHA1_HASH_SIZE)*2)+1)
#define HASHCP_READ_SIZE 32768
#define HASHCP_STDIN "stdin"

