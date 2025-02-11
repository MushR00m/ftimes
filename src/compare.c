/*-
 ***********************************************************************
 *
 * $Id: compare.c,v 1.58 2019/07/23 20:27:01 klm Exp $
 *
 ***********************************************************************
 *
 * Copyright 2000-2019 The FTimes Project, All Rights Reserved.
 *
 ***********************************************************************
 */
#include "all-includes.h"

/*-
 ***********************************************************************
 *
 * Globals
 *
 ***********************************************************************
 */
static CMP_PROPERTIES *gpsCmpProperties;

/*-
 ***********************************************************************
 *
 * CompareDecodeLine
 *
 ***********************************************************************
 */
int
CompareDecodeLine(char *pcLine, SNAPSHOT_CONTEXT *psBaseline, char **ppcDecodeFields, char *pcError)
{
  const char          acRoutine[] = "CompareDecodeLine()";
  char                acTempLine[CMP_MAX_LINE] = { 0 };
  char               *pcHead = NULL;
  char               *pcTail = NULL;
  int                 i = 0;
  int                 iDone = 0;
  int                 iFound = 0;
  int                 iField = 0;
  int                 iLength = 0;
  int                 iMaskTableLength = MaskGetTableLength(MASK_MASK_TYPE_CMP);
  unsigned long       ul = 0;

  /*-
   *********************************************************************
   *
   * Terminate each output field.
   *
   *********************************************************************
   */
  for (i = 0; i < iMaskTableLength; i++)
  {
    ppcDecodeFields[i][0] = 0;
  }

  /*-
   *********************************************************************
   *
   * Check the line's length.
   *
   *********************************************************************
   */
  iLength = strlen(pcLine);
  if (iLength > CMP_MAX_LINE - 1)
  {
    snprintf(pcError, MESSAGE_SIZE, "%s: Length = [%d]: Length exceeds %d bytes.", acRoutine, iLength, CMP_MAX_LINE - 1);
    return ER;
  }
  snprintf(acTempLine, CMP_MAX_LINE, "%s", pcLine);

  /*-
   *********************************************************************
   *
   * Parse data, and make a copy of each specified field.
   *
   *********************************************************************
   */
  for (pcHead = pcTail = acTempLine, iDone = iField = 0; !iDone; pcHead = ++pcTail, iField++)
  {
    while (*pcTail != CMP_SEPARATOR_C && *pcTail != 0)
    {
      pcTail++;
    }
    if (*pcTail == 0)
    {
      iDone = 1;
    }
    else
    {
      *pcTail = 0;
    }
    for (i = 0, iFound = -1; i < iMaskTableLength; i++)
    {
      ul = 1 << i;
      if (MASK_BIT_IS_SET(psBaseline->ulFieldMask, ul))
      {
        iFound++;
      }
      if (iFound == iField)
      {
        break;
      }
    }
    if (i != iMaskTableLength)
    {
      snprintf(ppcDecodeFields[psBaseline->aiIndex2Map[iField]], CMP_MAX_LINE, "%s", pcHead);
    }
  }

  return ER_OK;
}


/*-
 ***********************************************************************
 *
 * CompareEnumerateChanges
 *
 ***********************************************************************
 */
int
CompareEnumerateChanges(SNAPSHOT_CONTEXT *psBaseline, SNAPSHOT_CONTEXT *psSnapshot, char *pcError)
{
  const char          acRoutine[] = "CompareEnumerateChanges()";
  char                acLocalError[MESSAGE_SIZE] = "";
  char              **ppcBaselineFields = NULL;
  char              **ppcSnapshotFields = NULL;
  CMP_DATA            sCompareData;
  CMP_PROPERTIES     *psProperties = CompareGetPropertiesReference();
  int                 iLastIndex = 0;
  int                 iTempIndex = 0;
  int                 i = 0;
  int                 iError = 0;
  int                 iFound = 0;
  int                 iKeysIndex = 0;
  int                 iMaskTableLength = MaskGetTableLength(MASK_MASK_TYPE_CMP);
  unsigned long       ul = 0;

  /*-
   *********************************************************************
   *
   * Allocate enough memory to hold one complete baseline record broken
   * down into individual fields and stored in an array.
   *
   *********************************************************************
   */
/* FIXME Move this code to a subroutine. Add logic to free this memory when it's no longer required. */
  ppcBaselineFields = (char **) malloc(iMaskTableLength * sizeof(char **));
  if (ppcBaselineFields == NULL)
  {
    snprintf(pcError, MESSAGE_SIZE, "%s: malloc(): %s", acRoutine, strerror(errno));
    return ER;
  }

  for (i = 0; i < iMaskTableLength; i++)
  {
    ppcBaselineFields[i] = (char *) malloc(CMP_MAX_LINE);
    if (ppcBaselineFields[i] == NULL)
    {
      snprintf(pcError, MESSAGE_SIZE, "%s: malloc(): %s", acRoutine, strerror(errno));
      return ER;
    }
  }

  /*-
   *********************************************************************
   *
   * Enumerate changed and new files.
   *
   *********************************************************************
   */

  /*-
   *********************************************************************
   *
   * Read and process baseline data. If the read returns NULL, it
   * could mean an error has occured or EOF was reached. If a record
   * fails to parse (compressed files only), set a flag so that the
   * next read will automatically skip all records up to the next
   * checkpoint.
   *
   *********************************************************************
   */
  while (DecodeReadLine(psSnapshot, acLocalError) != NULL)
  {
    psSnapshot->sDecodeStats.ulAnalyzed++;
    iError = DecodeParseRecord(psSnapshot, acLocalError);
    if (iError != ER_OK)
    {
      if (psSnapshot->iCompressed)
      {
        psSnapshot->iSkipToNext = TRUE;
      }
      psSnapshot->sDecodeStats.ulSkipped++;
      continue;
    }
    psSnapshot->sDecodeStats.ulDecoded++;

    /*-
     *******************************************************************
     *
     * Search for the hash and compare specified fields.
     *
     *******************************************************************
     */
    psProperties->ulAnalyzed++;
    iFound = 0;
    ppcSnapshotFields = psSnapshot->psCurrRecord->ppcFields;
    sCompareData.cCategory = 0;
    sCompareData.pcRecord = NULL;
    sCompareData.iBaselineRecord = 0;
    sCompareData.iSnapshotRecord = psSnapshot->iLineNumber;
    iKeysIndex = CMP_GET_NODE_INDEX(psSnapshot->psCurrRecord->aucHash);

    iLastIndex = iTempIndex = psProperties->aiBaselineKeys[iKeysIndex];
    while (iTempIndex != -1)
    {
      if (memcmp(psProperties->psBaselineNodes[iTempIndex].aucHash, psSnapshot->psCurrRecord->aucHash, MD5_HASH_SIZE) == 0)
      {
        iFound++;
        if (++psProperties->psBaselineNodes[iTempIndex].iFound > 1)
        {
          snprintf(pcError, MESSAGE_SIZE, "%s: File = [%s], Line = [%d]: Hash collision. Check for duplicate filenames.", acRoutine, psSnapshot->pcFile, psSnapshot->iLineNumber);
          return ER;
        }
        CompareDecodeLine(psProperties->psBaselineNodes[iTempIndex].pcData, psBaseline, ppcBaselineFields, acLocalError);
        sCompareData.ulChangedMask = 0;
        sCompareData.ulUnknownMask = 0;
        sCompareData.iBaselineRecord = psProperties->psBaselineNodes[iTempIndex].iLineNumber;
        for (i = 0; i < iMaskTableLength; i++)
        {
          ul = 1 << i;
          if (MASK_BIT_IS_SET(psProperties->psCompareMask->ulMask, ul))
          {
            if (ppcBaselineFields[i][0] != 0 && ppcSnapshotFields[i][0] != 0)
            {
              if (strcmp(ppcBaselineFields[i], ppcSnapshotFields[i]) != 0)
              {
                sCompareData.ulChangedMask |= ul;
              }
            }
            else
            {
              sCompareData.ulUnknownMask |= ul;
            }
          }
        }
        if (sCompareData.ulChangedMask && !sCompareData.ulUnknownMask)
        {
          sCompareData.cCategory = 'C';
          psProperties->ulChanged++;
        }
        else if (!sCompareData.ulChangedMask && sCompareData.ulUnknownMask)
        {
          sCompareData.cCategory = 'U';
          psProperties->ulUnknown++;
        }
        else if (sCompareData.ulChangedMask && sCompareData.ulUnknownMask)
        {
          sCompareData.cCategory = 'X';
          psProperties->ulCrossed++;
        }
        sCompareData.pcRecord = ppcBaselineFields[0];
        break;
      }
      iLastIndex = iTempIndex;
      iTempIndex = psProperties->psBaselineNodes[iTempIndex].iNextIndex;
    }
    if (iFound == 0 || iLastIndex == -1)
    {
      sCompareData.cCategory = 'N';
      sCompareData.pcRecord = ppcSnapshotFields[0];
      psProperties->ulNew++;
    }
    else if (sCompareData.cCategory == 0)
    {
      continue; /* Nothing to report. */
    }
    iError = CompareWriteRecord(psProperties, &sCompareData, acLocalError);
    if (iError != ER_OK)
    {
      snprintf(pcError, MESSAGE_SIZE, "%s: File = [%s], Line = [%d]: %s", acRoutine, psSnapshot->pcFile, psSnapshot->iLineNumber, acLocalError);
      return ER;
    }
  }
  if (ferror(psSnapshot->pFile))
  {
    snprintf(pcError, MESSAGE_SIZE, "%s: File = [%s], Line = [%d]: %s", acRoutine, psSnapshot->pcFile, psSnapshot->iLineNumber, acLocalError);
    psSnapshot->sDecodeStats.ulSkipped++;
    return ER;
  }

  /*-
   *********************************************************************
   *
   * Enumerate missing objects.
   *
   *********************************************************************
   */
  sCompareData.iSnapshotRecord = 0;
  for (iKeysIndex = 0; iKeysIndex < CMP_MODULUS; iKeysIndex++)
  {
    iTempIndex = psProperties->aiBaselineKeys[iKeysIndex];
    while (iTempIndex != -1)
    {
      if (psProperties->psBaselineNodes[iTempIndex].iFound == 0)
      {
        sCompareData.cCategory = 'M';
        sCompareData.pcRecord = psProperties->psBaselineNodes[iTempIndex].pcData;
        sCompareData.iBaselineRecord = psProperties->psBaselineNodes[iTempIndex].iLineNumber;
        iError = CompareWriteRecord(psProperties, &sCompareData, acLocalError);
        if (iError != ER_OK)
        {
          snprintf(pcError, MESSAGE_SIZE, "%s: File = [%s], Line = [%d]: %s", acRoutine, psSnapshot->pcFile, psSnapshot->iLineNumber, acLocalError);
          return ER;
        }
        psProperties->ulMissing++;
      }
      iTempIndex = psProperties->psBaselineNodes[iTempIndex].iNextIndex;
    }
  }

  return ER_OK;
}


/*-
 ***********************************************************************
 *
 * CompareFreeNodeData
 *
 ***********************************************************************
 */
void
CompareFreeNodeData(int *piKeys, CMP_NODE *psNodes)
{
  int                 iKeysIndex = 0;
  int                 iNodeIndex = 0;

  for (iKeysIndex = 0; iKeysIndex < CMP_MODULUS; iKeysIndex++)
  {
    iNodeIndex = piKeys[iKeysIndex];
    while (iNodeIndex != -1)
    {
      if (psNodes[iNodeIndex].pcData)
      {
        free(psNodes[iNodeIndex].pcData);
      }
      iNodeIndex = psNodes[iNodeIndex].iNextIndex;
    }
  }
}


/*-
 ***********************************************************************
 *
 * CompareFreeProperties
 *
 ***********************************************************************
 */
void
CompareFreeProperties(CMP_PROPERTIES *psProperties)
{
  if (psProperties != NULL)
  {
    if (psProperties->pcMemoryMapFile != NULL)
    {
      free(psProperties->pcMemoryMapFile);
    }
    if (psProperties->psBaselineNodes != NULL)
    {
      /*-
       *****************************************************************
       * NOTE: CompareFreeNodeData() should be used to free this data,
       * but it causes severe cleanup lag (e.g., it takes more time to
       * free the data than it did to compare it) on some systems such
       * as FreeBSD for large jobs (~700K+ records). Therefore, the
       * following code has been disabled, and it is being kept as a
       * reminder. Other systems such as Linux and Solaris didn't have
       * this problem, so there may be other issues involved that are
       * not yet understood. However, since the program is essentially
       * terminal at this point, the risk of not doing this seems low.
       *
       * if (!psProperties->iMemoryMapFile)
       * {
       *   CompareFreeNodeData(psProperties->aiBaselineKeys, psProperties->psBaselineNodes);
       * }
       *
       *****************************************************************
       */
      free(psProperties->psBaselineNodes);
    }
    free(psProperties);
  }
}


/*-
 ***********************************************************************
 *
 * CompareGetChangedCount
 *
 ***********************************************************************
 */
int
CompareGetChangedCount(void)
{
  return gpsCmpProperties->ulChanged;
}


/*-
 ***********************************************************************
 *
 * CompareGetCrossedCount
 *
 ***********************************************************************
 */
int
CompareGetCrossedCount(void)
{
  return gpsCmpProperties->ulCrossed;
}


/*-
 ***********************************************************************
 *
 * CompareGetMissingCount
 *
 ***********************************************************************
 */
int
CompareGetMissingCount(void)
{
  return gpsCmpProperties->ulMissing;
}


/*-
 ***********************************************************************
 *
 * CompareGetNewCount
 *
 ***********************************************************************
 */
int
CompareGetNewCount(void)
{
  return gpsCmpProperties->ulNew;
}


/*-
 ***********************************************************************
 *
 * CompareGetNodeIndexReference
 *
 ***********************************************************************
 */
int *
CompareGetNodeIndexReference(unsigned char *pucHash, int *piKeys, CMP_NODE *psNodes)
{
  int                 iKeysIndex = 0;
  int                 iLastIndex = 0;
  int                 iTempIndex = 0;

  iKeysIndex = CMP_GET_NODE_INDEX(pucHash);

  if ((iLastIndex = iTempIndex = piKeys[iKeysIndex]) == -1)
  {
    return &piKeys[iKeysIndex];
  }
  else
  {
    while (iTempIndex != -1)
    {
      if (memcmp(psNodes[iTempIndex].aucHash, pucHash, MD5_HASH_SIZE) == 0)
      {
        return NULL;
      }
      iLastIndex = iTempIndex;
      iTempIndex = psNodes[iTempIndex].iNextIndex;
    }
    return &psNodes[iLastIndex].iNextIndex;
  }
}


/*-
 ***********************************************************************
 *
 * CompareGetPropertiesReference
 *
 ***********************************************************************
 */
CMP_PROPERTIES *
CompareGetPropertiesReference(void)
{
  return gpsCmpProperties;
}


/*-
 ***********************************************************************
 *
 * CompareGetRecordCount
 *
 ***********************************************************************
 */
int
CompareGetRecordCount(void)
{
  return gpsCmpProperties->ulAnalyzed;
}


/*-
 ***********************************************************************
 *
 * CompareGetUnknownCount
 *
 ***********************************************************************
 */
int
CompareGetUnknownCount(void)
{
  return gpsCmpProperties->ulUnknown;
}


/*-
 ***********************************************************************
 *
 * CompareLoadBaselineData
 *
 ***********************************************************************
 */
int
CompareLoadBaselineData(SNAPSHOT_CONTEXT *psBaseline, char *pcError)
{
  const char          acRoutine[] = "CompareLoadBaselineData()";
  char                acLocalError[MESSAGE_SIZE] = "";
  char               *pcData = NULL;
  CMP_PROPERTIES     *psProperties = CompareGetPropertiesReference();
  FILE               *pFile = NULL;
  int                 i = 0;
  int                 n = 0;
  int                 iError = 0;
  int                 iNodeCount = 0;
  int                 iNodeIndex = 0;
  int                 iOffset = 0;
  int                *piNodeIndex = NULL;
#ifdef WINNT
  HANDLE              hFile = NULL;
  HANDLE              hMemoryMap = NULL;
  char               *pcMessage = NULL;
  int                 iFile = 0;
#endif

  /*-
   *********************************************************************
   *
   * Conditionally create a file to serve as the backing for a memory
   * map. For WINX platforms, convert the native handle into a FILE
   * pointer so that common code can be used when writing data to the
   * file. Next, unlink the file. This will fail for WINX systems, but
   * that should not be an issue because a second unlink is attempted
   * when the program executes its final stage.
   *
   *********************************************************************
   */
  if (psProperties->iMemoryMapFile)
  {
#ifdef WINNT
    hFile = CreateFile
    (
      psProperties->pcMemoryMapFile,
      GENERIC_READ | GENERIC_WRITE,
      0,
      NULL,
      CREATE_NEW,
      FILE_ATTRIBUTE_NORMAL,
      NULL
    );
    if (hFile == INVALID_HANDLE_VALUE)
    {
      ErrorFormatWinxError(GetLastError(), &pcMessage);
      snprintf(pcError, MESSAGE_SIZE, "%s: CreateFile(): %s", acRoutine, pcMessage);
      return ER;
    }
    iFile = _open_osfhandle((intptr_t) hFile, 0);
    if (iFile == ER)
    {
      snprintf(pcError, MESSAGE_SIZE, "%s: open_osfhandle(): Handle association failed.", acRoutine);
      return ER;
    }
    pFile = fdopen(iFile, "wb+");
    if (pFile == NULL)
    {
      snprintf(pcError, MESSAGE_SIZE, "%s: fdopen(): %s", acRoutine, strerror(errno));
      return ER;
    }
#else
    umask(077);
    pFile = fopen(psProperties->pcMemoryMapFile, "wb+");
    if (pFile == NULL)
    {
      snprintf(pcError, MESSAGE_SIZE, "%s: fopen(): %s", acRoutine, strerror(errno));
      return ER;
    }
#endif
    unlink(psProperties->pcMemoryMapFile);
  }

  /*-
   *********************************************************************
   *
   * Read and process baseline data. If the read returns NULL, it
   * could mean an error has occured or EOF was reached. If a record
   * fails to parse (compressed files only), set a flag so that the
   * next read will automatically skip all records up to the next
   * checkpoint.
   *
   *********************************************************************
   */
  while (DecodeReadLine(psBaseline, acLocalError) != NULL)
  {
    psBaseline->sDecodeStats.ulAnalyzed++;
    iError = DecodeParseRecord(psBaseline, acLocalError);
    if (iError != ER_OK)
    {
      if (psBaseline->iCompressed)
      {
        psBaseline->iSkipToNext = TRUE;
      }
      psBaseline->sDecodeStats.ulSkipped++;
      continue;
    }
    psBaseline->sDecodeStats.ulDecoded++;

    /*-
     *******************************************************************
     *
     * Allocate a block of memory to hold this record. Then, join the
     * fields to form a single record. If a memory map file is being
     * used, this memory is freed as soon as it has been written out
     * the file. Otherwise it is freed later in CompareFreeNodeData().
     *
     *******************************************************************
     */
    for (i = n = 0; i < psBaseline->iFieldCount; i++)
    {
      n += strlen(psBaseline->psCurrRecord->ppcFields[psBaseline->aiIndex2Map[i]]);
    }
    pcData = malloc(n + i + 1); /* The value for i represents the number of delimiters needed. */
    if (pcData == NULL)
    {
      snprintf(pcError, MESSAGE_SIZE, "%s: malloc(): File = [%s], Line = [%d]: %s", acRoutine, psBaseline->pcFile, psBaseline->iLineNumber, strerror(errno));
      return ER;
    }
    for (i = n = 0; i < psBaseline->iFieldCount; i++)
    {
      n += sprintf(&pcData[n], "%s%s", (i > 0) ? DECODE_SEPARATOR_S : "", psBaseline->psCurrRecord->ppcFields[psBaseline->aiIndex2Map[i]]);
    }

    /*-
     *******************************************************************
     *
     * Conditionally write this record out to the backing file.
     *
     *******************************************************************
     */
    if (psProperties->iMemoryMapFile)
    {
      iError = SupportWriteData(pFile, pcData, n + 1, acLocalError);
      if (iError != ER_OK)
      {
        snprintf(pcError, MESSAGE_SIZE, "%s: %s", acRoutine, acLocalError);
        return ER;
      }
      free(pcData);
    }

    /*-
     *******************************************************************
     *
     * Check node count, and allocate more, if necessary.
     *
     *******************************************************************
     */
    if (iNodeIndex >= iNodeCount)
    {
      iNodeCount += CMP_NODE_REQUEST_COUNT;
      psProperties->psBaselineNodes = (CMP_NODE *) realloc(psProperties->psBaselineNodes, (iNodeCount * sizeof(CMP_NODE)));
      if (psProperties->psBaselineNodes == NULL)
      {
        snprintf(pcError, MESSAGE_SIZE, "%s: realloc(): File = [%s], Line = [%d]: %s", acRoutine, psBaseline->pcFile, psBaseline->iLineNumber, strerror(errno));
        return ER;
      }
    }

    /*-
     *******************************************************************
     *
     * Insert a new node. Abort on a collision.
     *
     *******************************************************************
     */
    piNodeIndex = CompareGetNodeIndexReference(psBaseline->psCurrRecord->aucHash, psProperties->aiBaselineKeys, psProperties->psBaselineNodes);
    if (piNodeIndex == NULL)
    {
      snprintf(pcError, MESSAGE_SIZE, "%s: File = [%s], Line = [%d]: Hash collision. Check for duplicate filenames.", acRoutine, psBaseline->pcFile, psBaseline->iLineNumber);
      return ER;
    }
    else
    {
      *piNodeIndex = iNodeIndex;
      psProperties->psBaselineNodes[*piNodeIndex].iNextIndex = -1;
      memcpy(psProperties->psBaselineNodes[*piNodeIndex].aucHash, psBaseline->psCurrRecord->aucHash, MD5_HASH_SIZE);
/* FIXME See TODO list. */
      if (psProperties->iMemoryMapFile)
      {
        psProperties->psBaselineNodes[*piNodeIndex].pcData = NULL;
        psProperties->psBaselineNodes[*piNodeIndex].iLineNumber = psBaseline->iLineNumber;
        psProperties->psBaselineNodes[*piNodeIndex].iOffset = iOffset;
        iOffset += n + 1;
      }
      else
      {
        psProperties->psBaselineNodes[*piNodeIndex].pcData = pcData;
        psProperties->psBaselineNodes[*piNodeIndex].iLineNumber = psBaseline->iLineNumber;
        psProperties->psBaselineNodes[*piNodeIndex].iOffset = 0;
      }
      iNodeIndex++;
    }
  }
  if (ferror(psBaseline->pFile))
  {
    snprintf(pcError, MESSAGE_SIZE, "%s: File = [%s], Line = [%d]: %s", acRoutine, psBaseline->pcFile, psBaseline->iLineNumber, acLocalError);
    psBaseline->sDecodeStats.ulSkipped++;
    return ER;
  }

  /*-
   *********************************************************************
   *
   * Conditionally memory map the backing file.
   *
   *********************************************************************
   */
  if (psProperties->iMemoryMapFile)
  {
    psProperties->iMemoryMapSize = iOffset;
#ifdef WINNT
    hMemoryMap = CreateFileMapping(hFile, NULL, PAGE_READWRITE, 0, 0, 0);
    if (hMemoryMap == NULL)
    {
      ErrorFormatWinxError(GetLastError(), &pcMessage);
      snprintf(pcError, MESSAGE_SIZE, "%s: CreateFileMapping(): %s", acRoutine, pcMessage);
      return ER;
    }
    psProperties->pvMemoryMap = MapViewOfFile(hMemoryMap, FILE_MAP_ALL_ACCESS, 0, 0, 0);
    if (psProperties->pvMemoryMap == NULL)
    {
      ErrorFormatWinxError(GetLastError(), &pcMessage);
      snprintf(pcError, MESSAGE_SIZE, "%s: MapViewOfFile(): %s", acRoutine, pcMessage);
      return ER;
    }
    CloseHandle(hMemoryMap);
    CloseHandle(hFile);
#else
    psProperties->pvMemoryMap = mmap(0, psProperties->iMemoryMapSize, PROT_READ|PROT_WRITE, MAP_PRIVATE, fileno(pFile), 0);
#if defined(FTimes_HPUX) && !defined(MAP_FAILED)
#define MAP_FAILED ((void *)-1)
#endif
    if (psProperties->pvMemoryMap == MAP_FAILED)
    {
      snprintf(pcError, MESSAGE_SIZE, "%s: mmap(): %s", acRoutine, strerror(errno));
      return ER;
    }
#endif
    fclose(pFile);
    CompareSetNodeData(psProperties->aiBaselineKeys, psProperties->psBaselineNodes, psProperties->pvMemoryMap);
  }

  return ER_OK;
}


/*-
 ***********************************************************************
 *
 * CompareNewProperties
 *
 ***********************************************************************
 */
CMP_PROPERTIES *
CompareNewProperties(char *pcError)
{
  const char          acRoutine[] = "CompareNewProperties()";
  CMP_PROPERTIES     *psProperties = NULL;
  int                 i = 0;

  /*
   *********************************************************************
   *
   * Allocate and clear memory for the properties structure.
   *
   *********************************************************************
   */
  psProperties = (CMP_PROPERTIES *) calloc(sizeof(CMP_PROPERTIES), 1);
  if (psProperties == NULL)
  {
    snprintf(pcError, MESSAGE_SIZE, "%s: calloc(): %s", acRoutine, strerror(errno));
    return NULL;
  }

  /*
   *********************************************************************
   *
   * Initialize BaselineKeys and SnapshotKeys variables.
   *
   *********************************************************************
   */
  for (i = 0; i < CMP_MODULUS; i++)
  {
    psProperties->aiBaselineKeys[i] = -1;
  }

  /*-
   *********************************************************************
   *
   * Initialize NewLine variable.
   *
   *********************************************************************
   */
#ifdef WIN32
  strncpy(psProperties->acNewLine, CRLF, NEWLINE_LENGTH);
#else
  strncpy(psProperties->acNewLine, LF, NEWLINE_LENGTH);
#endif

  return psProperties;
}


/*-
 ***********************************************************************
 *
 * CompareSetNewLine
 *
 ***********************************************************************
 */
void
CompareSetNewLine(char *pcNewLine)
{
  strncpy(gpsCmpProperties->acNewLine, (strcmp(pcNewLine, CRLF) == 0) ? CRLF : LF, NEWLINE_LENGTH);
}


/*-
 ***********************************************************************
 *
 * CompareSetNodeData
 *
 ***********************************************************************
 */
void
CompareSetNodeData(int *piKeys, CMP_NODE *psNodes, void *pvBaseAddress)
{
  int                 iKeysIndex = 0;
  int                 iNodeIndex = 0;

  /*-
   *********************************************************************
   *
   * The purpose of this routine is to initialize all pcData members.
   * This step must be done after the backing file has been built and
   * mapped into memory.
   *
   *********************************************************************
   */
  for (iKeysIndex = 0; iKeysIndex < CMP_MODULUS; iKeysIndex++)
  {
    iNodeIndex = piKeys[iKeysIndex];
    while (iNodeIndex != -1)
    {
      psNodes[iNodeIndex].pcData = (char *) pvBaseAddress + psNodes[iNodeIndex].iOffset;
      iNodeIndex = psNodes[iNodeIndex].iNextIndex;
    }
  }
}


/*-
 ***********************************************************************
 *
 * CompareSetOutputStream
 *
 ***********************************************************************
 */
void
CompareSetOutputStream(FILE *pFile)
{
  gpsCmpProperties->pFileOut = pFile;
}


/*-
 ***********************************************************************
 *
 * CompareSetPropertiesReference
 *
 ***********************************************************************
 */
void
CompareSetPropertiesReference(CMP_PROPERTIES *psProperties)
{
  gpsCmpProperties = psProperties;
}


/*-
 ***********************************************************************
 *
 * CompareWriteHeader
 *
 ***********************************************************************
 */
int
CompareWriteHeader(FILE *pFile, char *pcNewLine, char *pcError)
{
  const char          acRoutine[] = "CompareWriteHeader()";
  char                acHeader[FTIMES_MAX_LINE] = { 0 };
  char                acLocalError[MESSAGE_SIZE] = "";
  int                 iError = 0;
  int                 iIndex = 0;

  iIndex = sprintf(acHeader, "category|name|changed|unknown|records%s", pcNewLine);

  iError = SupportWriteData(pFile, acHeader, iIndex, acLocalError);
  if (iError != ER_OK)
  {
    snprintf(pcError, MESSAGE_SIZE, "%s: %s", acRoutine, acLocalError);
    return iError;
  }

  return ER_OK;
}


/*-
 ***********************************************************************
 *
 * CompareWriteRecord
 *
 ***********************************************************************
 */
int
CompareWriteRecord(CMP_PROPERTIES *psProperties, CMP_DATA *psData, char *pcError)
{
  const char          acRoutine[] = "CompareWriteRecord()";
  static char        *pcOutput = NULL;
  static int          iMaskTableLength = 0;
  static MASK_B2S_TABLE *pasMaskTable = NULL;
  char                acLocalError[MESSAGE_SIZE] = "";
  char               *pc = NULL;
  int                 i = 0;
  int                 iError = 0;
  int                 iFirst = 0;
  int                 iIndex = 0;
  unsigned long       ul = 0;

  /*-
   *********************************************************************
   *
   * Allocate enough memory to hold one complete record, but only do
   * this operation once. Note that this memory is never freed.
   *
   * category      1
   * name          CMP_MAX_LINE
   * changed       (iMaskTableLength * (MASK_NAME_SIZE))
   * unknown       (iMaskTableLength * (MASK_NAME_SIZE))
   * records       (2 * (FTIMES_MAX_32BIT_SIZE))
   * |'s           3
   * newline       2
   *
   *********************************************************************
   */
  if (pcOutput == NULL)
  {
    iMaskTableLength = MaskGetTableLength(MASK_MASK_TYPE_CMP);
    pasMaskTable = MaskGetTableReference(MASK_MASK_TYPE_CMP);
    pcOutput = malloc(CMP_MAX_LINE + (2 * (iMaskTableLength * (MASK_NAME_SIZE))) + (2 * (FTIMES_MAX_32BIT_SIZE)) + 6);
    if (pcOutput == NULL)
    {
      snprintf(pcError, MESSAGE_SIZE, "%s: malloc(): %s", acRoutine, strerror(errno));
      return ER;
    }
  }

  /*-
   *********************************************************************
   *
   * Category = category
   *
   *********************************************************************
   */
  switch (psData->cCategory)
  {
  case 'C': /* changed */
  case 'M': /* missing */
  case 'N': /* new */
  case 'U': /* unknown */
  case 'X': /* both changed and unknown */
    pcOutput[0] = psData->cCategory;
    break;
  default:
    snprintf(pcError, MESSAGE_SIZE, "%s: Category = [%c] != [C|M|N|U|X]: That shouldn't happen.", acRoutine, psData->cCategory);
    return ER;
    break;
  }
  iIndex = 1;

  /*-
   *********************************************************************
   *
   * Name = name
   *
   *********************************************************************
   */
  pc = strstr(&psData->pcRecord[1], "\"");
  if (psData->pcRecord[0] != '"' || pc == NULL)
  {
    snprintf(pcError, MESSAGE_SIZE, "%s: Name = [%s]: Name is not quoted. That shouldn't happen.", acRoutine, psData->pcRecord);
    return ER;
  }
  pcOutput[iIndex++] = CMP_SEPARATOR_C;
  for (i = 0; i <= pc - psData->pcRecord; i++)
  {
    pcOutput[iIndex++] = psData->pcRecord[i];
  }

  /*-
   *********************************************************************
   *
   * Changed, Unknown, Cross = changed, unknown, cross
   *
   *********************************************************************
   */
  if (psData->cCategory == 'C' || psData->cCategory == 'U' || psData->cCategory == 'X')
  {
    pcOutput[iIndex++] = CMP_SEPARATOR_C;
    for (i = 0, iFirst = 0; i < iMaskTableLength; i++)
    {
      ul = 1 << i;
      if (MASK_BIT_IS_SET(psData->ulChangedMask, ul))
      {
        iIndex += sprintf(&pcOutput[iIndex], "%s%s", (iFirst++ > 0) ? "," : "", pasMaskTable[i].acName);
      }
    }
    pcOutput[iIndex++] = CMP_SEPARATOR_C;
    for (i = 0, iFirst = 0; i < iMaskTableLength; i++)
    {
      ul = 1 << i;
      if (MASK_BIT_IS_SET(psData->ulUnknownMask, ul))
      {
        iIndex += sprintf(&pcOutput[iIndex], "%s%s", (iFirst++ > 0) ? "," : "", pasMaskTable[i].acName);
      }
    }
  }
  else
  {
    pcOutput[iIndex++] = CMP_SEPARATOR_C;
    pcOutput[iIndex++] = CMP_SEPARATOR_C;
  }

  /*-
   *********************************************************************
   *
   * Record numbers.
   *
   *********************************************************************
   */
  pcOutput[iIndex++] = CMP_SEPARATOR_C;
  iIndex += sprintf(&pcOutput[iIndex], "%d,%d", psData->iBaselineRecord, psData->iSnapshotRecord);

  /*-
   *********************************************************************
   *
   * Newline
   *
   *********************************************************************
   */
  iIndex += sprintf(&pcOutput[iIndex], "%s", psProperties->acNewLine);

  /*-
   *********************************************************************
   *
   * Write the output data.
   *
   *********************************************************************
   */
  iError = SupportWriteData(psProperties->pFileOut, pcOutput, iIndex, acLocalError);
  if (iError != ER_OK)
  {
    snprintf(pcError, MESSAGE_SIZE, "%s: %s", acRoutine, acLocalError);
    return iError;
  }

  return ER_OK;
}
