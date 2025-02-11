/*-
 ***********************************************************************
 *
 * $Id: mapmode.c,v 1.62 2019/08/29 19:24:56 klm Exp $
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
 * MapModeInitialize
 *
 ***********************************************************************
 */
int
MapModeInitialize(void *pvProperties, char *pcError)
{
  const char          acRoutine[] = "MapModeInitialize()";
  char                acLocalError[MESSAGE_SIZE] = "";
  char                acMapItem[FTIMES_MAX_PATH];
  char               *pcMapItem = NULL;
  FTIMES_PROPERTIES  *psProperties = (FTIMES_PROPERTIES *)pvProperties;
  int                 iError = 0;

  /*-
   *******************************************************************
   *
   * Initialize variables.
   *
   *********************************************************************
   */
  psProperties->pFileLog = stderr;
  psProperties->pFileOut = stdout;
  if (psProperties->iRunMode == FTIMES_MAPAUTO)
  {
    psProperties->bAnalyzeDeviceFiles = TRUE;
    psProperties->bAnalyzeRemoteFiles = TRUE;
  }
  psProperties->bHashSymbolicLinks = TRUE;

  /*-
   *******************************************************************
   *
   * Conditionally read the config file.
   *
   *******************************************************************
   */
  if (psProperties->iRunMode == FTIMES_MAPMODE)
  {
    iError = PropertiesReadFile(psProperties->acConfigFile, psProperties, acLocalError);
    if (iError != ER_OK)
    {
      snprintf(pcError, MESSAGE_SIZE, "%s: %s", acRoutine, acLocalError);
      return iError;
    }
  }

  /*-
   *********************************************************************
   *
   * Set the priority.
   *
   *********************************************************************
   */
  iError = SupportSetPriority(psProperties, acLocalError);
  if (iError != ER_OK)
  {
    snprintf(pcError, MESSAGE_SIZE, "%s: %s", acRoutine, acLocalError);
    return iError;
  }

  /*-
   *******************************************************************
   *
   * Add any command line items to the Include list.
   *
   *******************************************************************
   */
  while ((pcMapItem = OptionsGetNextOperand(psProperties->psOptionsContext)) != NULL)
  {
    iError = SupportExpandPath(pcMapItem, acMapItem, FTIMES_MAX_PATH, 0, acLocalError);
    if (iError != ER_OK)
    {
      snprintf(pcError, MESSAGE_SIZE, "%s: %s", acRoutine, acLocalError);
      return iError;
    }

    iError = SupportAddToList(acMapItem, &psProperties->psIncludeList, "Include", acLocalError);
    if (iError != ER_OK)
    {
      snprintf(pcError, MESSAGE_SIZE, "%s: %s", acRoutine, acLocalError);
      return iError;
    }
  }

  /*-
   *********************************************************************
   *
   * LogDir defaults to OutDir.
   *
   *********************************************************************
   */
  if (psProperties->acLogDirName[0] == 0)
  {
    snprintf(psProperties->acLogDirName, FTIMES_MAX_PATH, "%s", psProperties->acOutDirName);
  }

  /*-
   *********************************************************************
   *
   * Set up the DevelopOutput function pointer.
   *
   *********************************************************************
   */
  psProperties->piDevelopMapOutput = (psProperties->bCompress) ? DevelopCompressedOutput : DevelopNormalOutput;

  return ER_OK;
}


/*-
 ***********************************************************************
 *
 * MapModeCheckDependencies
 *
 ***********************************************************************
 */
int
MapModeCheckDependencies(void *pvProperties, char *pcError)
{
  const char          acRoutine[] = "MapModeCheckDependencies()";
#ifdef USE_SSL
  char                acLocalError[MESSAGE_SIZE] = "";
#endif
  FTIMES_PROPERTIES  *psProperties = (FTIMES_PROPERTIES *)pvProperties;

  if (psProperties->psFieldMask == NULL)
  {
    snprintf(pcError, MESSAGE_SIZE, "%s: Missing FieldMask.", acRoutine);
    return ER_MissingControl;
  }

#ifdef USE_XMAGIC
  /*-
   *********************************************************************
   *
   * Conditionally check that the block size is big enough to support
   * Magic.
   *
   *********************************************************************
   */
  if (MASK_BIT_IS_SET(psProperties->psFieldMask->ulMask, MAP_MAGIC))
  {
    if (psProperties->iAnalyzeBlockSize < XMAGIC_READ_BUFSIZE)
    {
      snprintf(pcError, MESSAGE_SIZE, "%s: AnalyzeBlockSize (%d) must be at least %d bytes to support XMagic.", acRoutine, psProperties->iAnalyzeBlockSize, XMAGIC_READ_BUFSIZE);
      return ER;
    }
  }
#endif

  /*-
   *********************************************************************
   *
   * Check mode-specific properties.
   *
   *********************************************************************
   */
  if (psProperties->iRunMode == FTIMES_MAPMODE)
  {
    if (psProperties->acBaseName[0] == 0)
    {
      snprintf(pcError, MESSAGE_SIZE, "%s: Missing BaseName.", acRoutine);
      return ER_MissingControl;
    }

    if (strcmp(psProperties->acBaseName, "-") == 0)
    {
      if (psProperties->bURLPutSnapshot)
      {
        snprintf(pcError, MESSAGE_SIZE, "%s: Uploads are not allowed when the BaseName is \"-\". Either disable URLPutSnapshot or change the BaseName.", acRoutine);
        return ER;
      }
    }
    else
    {
      if (psProperties->acOutDirName[0] == 0)
      {
        snprintf(pcError, MESSAGE_SIZE, "%s: Missing OutDir.", acRoutine);
        return ER_MissingControl;
      }
    }

    if (psProperties->bURLPutSnapshot && psProperties->psPutURL == NULL)
    {
      snprintf(pcError, MESSAGE_SIZE, "%s: Missing URLPutURL.", acRoutine);
      return ER_MissingControl;
    }

    if (psProperties->bURLPutSnapshot && psProperties->psPutURL->pcPath[0] == 0)
    {
      snprintf(pcError, MESSAGE_SIZE, "%s: Missing path in URLPutURL.", acRoutine);
      return ER_MissingControl;
    }

#ifdef USE_SSL
    if (SSLCheckDependencies(psProperties->psSslProperties, acLocalError) != ER_OK)
    {
      snprintf(pcError, MESSAGE_SIZE, "%s: %s", acRoutine, acLocalError);
      return ER_MissingControl;
    }
#endif
  }

#ifdef USE_PCRE
  /*-
   *********************************************************************
   *
   * Attribute filters require the corresponding attribute to be set.
   *
   *********************************************************************
   */
   if ((psProperties->psExcludeFilterMd5List || psProperties->psIncludeFilterMd5List) && !MASK_BIT_IS_SET(psProperties->psFieldMask->ulMask, MAP_MD5))
   {
      snprintf(pcError, MESSAGE_SIZE, "%s: The specified attribute filter(s) require the MD5 attribute to be set. Either add this attribute to the FieldMask or remove/disable all include/exclude MD5 filters." , acRoutine);
      return ER;
   }

   if ((psProperties->psExcludeFilterSha1List || psProperties->psIncludeFilterSha1List) && !MASK_BIT_IS_SET(psProperties->psFieldMask->ulMask, MAP_SHA1))
   {
      snprintf(pcError, MESSAGE_SIZE, "%s: The specified attribute filter(s) require the SHA1 attribute to be set. Either add this attribute to the FieldMask or remove/disable all include/exclude SHA1 filters." , acRoutine);
      return ER;
   }

   if ((psProperties->psExcludeFilterSha256List || psProperties->psIncludeFilterSha256List) && !MASK_BIT_IS_SET(psProperties->psFieldMask->ulMask, MAP_SHA256))
   {
      snprintf(pcError, MESSAGE_SIZE, "%s: The specified attribute filter(s) require the SHA256 attribute to be set. Either add this attribute to the FieldMask or remove/disable all include/exclude SHA256 filters." , acRoutine);
      return ER;
   }
#endif

  return ER_OK;
}


/*-
 ***********************************************************************
 *
 * MapModeFinalize
 *
 ***********************************************************************
 */
int
MapModeFinalize(void *pvProperties, char *pcError)
{
  const char          acRoutine[] = "MapModeFinalize()";
  char                acLocalError[MESSAGE_SIZE] = "";
#ifdef USE_XMAGIC
  char                acMessage[MESSAGE_SIZE];
#endif
  FTIMES_PROPERTIES  *psProperties = (FTIMES_PROPERTIES *)pvProperties;
  int                 iError;

  /*-
   *********************************************************************
   *
   * Enforce privilege requirements, if requested.
   *
   *********************************************************************
   */
  if (psProperties->bRequirePrivilege)
  {
    iError = SupportRequirePrivilege(acLocalError);
    if (iError != ER_OK)
    {
      snprintf(pcError, MESSAGE_SIZE, "%s: %s", acRoutine, acLocalError);
      return iError;
    }
  }

  /*-
   *********************************************************************
   *
   * Conditionally check the server uplink.
   *
   *********************************************************************
   */
  if (psProperties->bURLPutSnapshot && psProperties->iRunMode == FTIMES_MAPMODE)
  {
    iError = URLPingRequest(psProperties, acLocalError);
    if (iError != ER_OK)
    {
      snprintf(pcError, MESSAGE_SIZE, "%s: %s", acRoutine, acLocalError);
      return ER_URLPingRequest;
    }
  }

  /*-
   *********************************************************************
   *
   * Conditionally set up the Digest engine. NOTE: The conditionals are
   * tested inside the subroutine.
   *
   *********************************************************************
   */
  AnalyzeEnableDigestEngine(psProperties);

#ifdef USE_XMAGIC
  /*-
   *********************************************************************
   *
   * Conditionally set up the Magic engine.
   *
   *********************************************************************
   */
  if (MASK_BIT_IS_SET(psProperties->psFieldMask->ulMask, MAP_MAGIC))
  {
    iError = AnalyzeEnableXMagicEngine(psProperties, acLocalError);
    if (iError != ER_OK)
    {
      snprintf(pcError, MESSAGE_SIZE, "%s: %s", acRoutine, acLocalError);
      return iError;
    }
  }
#endif

  /*-
   *********************************************************************
   *
   * If the Include list is NULL, include everything.
   *
   *********************************************************************
   */
  if (psProperties->psIncludeList == NULL)
  {
    psProperties->psIncludeList = SupportIncludeEverything(acLocalError);
    if (psProperties->psIncludeList == NULL)
    {
      snprintf(pcError, MESSAGE_SIZE, "%s: Failed to build a default Include list: %s", acRoutine, acLocalError);
      return ER_BadHandle;
    }
  }

  /*-
   *********************************************************************
   *
   * Prune the Include list.
   *
   *********************************************************************
   */
  psProperties->psIncludeList = SupportPruneList(psProperties->psIncludeList, "Include");
  if (psProperties->psIncludeList == NULL)
  {
    snprintf(pcError, MESSAGE_SIZE, "%s: There's nothing left to process in the Include list.", acRoutine);
    return ER_NothingToDo;
  }

  /*-
   *********************************************************************
   *
   * Conditionally check the Include and Exclude lists.
   *
   *********************************************************************
   */
  if (psProperties->bExcludesMustExist)
  {
    iError = SupportCheckList(psProperties->psExcludeList, "Exclude", acLocalError);
    if (iError != ER_OK)
    {
      snprintf(pcError, MESSAGE_SIZE, "%s: %s", acRoutine, acLocalError);
      return iError;
    }
  }

  if (psProperties->bIncludesMustExist)
  {
    iError = SupportCheckList(psProperties->psIncludeList, "Include", acLocalError);
    if (iError != ER_OK)
    {
      snprintf(pcError, MESSAGE_SIZE, "%s: %s", acRoutine, acLocalError);
      return iError;
    }
  }

#ifdef USE_KLEL_FILTERS
  /*-
   *********************************************************************
   *
   * Conditionally check the Include and Exclude filters. Note that we
   * manually include the name attribute bit since it's not present in
   * a normal field mask.
   *
   *********************************************************************
   */
  if (psProperties->psExcludeFilterListKlel != NULL)
  {
    unsigned long ulMask = psProperties->psFieldMask->ulMask | FILTER_NAME;
    iError = FilterCheckFilterMasks(psProperties->psExcludeFilterListKlel, ulMask, acLocalError);
    if (iError != ER_OK)
    {
      snprintf(pcError, MESSAGE_SIZE, "%s: %s", acRoutine, acLocalError);
      return iError;
    }
  }

  if (psProperties->psIncludeFilterListKlel != NULL)
  {
    unsigned long ulMask = psProperties->psFieldMask->ulMask | FILTER_NAME;
    iError = FilterCheckFilterMasks(psProperties->psIncludeFilterListKlel, ulMask, acLocalError);
    if (iError != ER_OK)
    {
      snprintf(pcError, MESSAGE_SIZE, "%s: %s", acRoutine, acLocalError);
      return iError;
    }
  }
#endif

  /*-
   *********************************************************************
   *
   * Establish Log file stream, and update Message Handler.
   *
   *********************************************************************
   */
  if (psProperties->iRunMode == FTIMES_MAPMODE && strcmp(psProperties->acBaseName, "-") != 0)
  {
    iError = SupportMakeName(psProperties->acLogDirName, psProperties->acBaseName, psProperties->acBaseNameSuffix, ".log", psProperties->acLogFileName, acLocalError);
    if (iError != ER_OK)
    {
      snprintf(pcError, MESSAGE_SIZE, "%s: Log File: %s", acRoutine, acLocalError);
      return iError;
    }

    iError = SupportAddToList(psProperties->acLogFileName, &psProperties->psExcludeList, "Exclude", acLocalError);
    if (iError != ER_OK)
    {
      snprintf(pcError, MESSAGE_SIZE, "%s: %s", acRoutine, acLocalError);
      return iError;
    }

    psProperties->pFileLog = fopen(psProperties->acLogFileName, "wb+");
    if (psProperties->pFileLog == NULL)
    {
      snprintf(pcError, MESSAGE_SIZE, "%s: LogFile = [%s]: %s", acRoutine, psProperties->acLogFileName, strerror(errno));
      return ER_fopen;
    }
/* FIXME Remove this #ifdef at some point in the future. */
#ifdef WIN32
    /*-
     *****************************************************************
     *
     * NOTE: The buffer size was explicitly set to prevent binaries
     * made with Visual Studio 2005 (no service packs) from crashing
     * when run in lean mode. This problem may have been fixed in
     * Service Pack 1.
     *
     *****************************************************************
     */
    setvbuf(psProperties->pFileLog, NULL, _IOLBF, 1024);
#else
    setvbuf(psProperties->pFileLog, NULL, _IOLBF, 0);
#endif
  }
  else
  {
    strncpy(psProperties->acLogFileName, "stderr", FTIMES_MAX_PATH);
    psProperties->pFileLog = stderr;
  }

  MessageSetNewLine(psProperties->acNewLine);
  MessageSetOutputStream(psProperties->pFileLog);
  MessageSetAutoFlush(MESSAGE_AUTO_FLUSH_ON);

  /*-
   *******************************************************************
   *
   * Establish Out file stream.
   *
   *******************************************************************
   */
  if (psProperties->iRunMode == FTIMES_MAPMODE && strcmp(psProperties->acBaseName, "-") != 0)
  {
    iError = SupportMakeName(psProperties->acOutDirName, psProperties->acBaseName, psProperties->acBaseNameSuffix, ".map", psProperties->acOutFileName, acLocalError);
    if (iError != ER_OK)
    {
      snprintf(pcError, MESSAGE_SIZE, "%s: Out File: %s", acRoutine, acLocalError);
      return iError;
    }

    iError = SupportAddToList(psProperties->acOutFileName, &psProperties->psExcludeList, "Exclude", acLocalError);
    if (iError != ER_OK)
    {
      snprintf(pcError, MESSAGE_SIZE, "%s: %s", acRoutine, acLocalError);
      return iError;
    }

    psProperties->pFileOut = fopen(psProperties->acOutFileName, "wb+");
    if (psProperties->pFileOut == NULL)
    {
      snprintf(pcError, MESSAGE_SIZE, "%s: OutFile = [%s]: %s", acRoutine, psProperties->acOutFileName, strerror(errno));
      return ER_fopen;
    }
/* FIXME Remove this #ifdef at some point in the future. */
#ifdef WIN32
    /*-
     *****************************************************************
     *
     * NOTE: The buffer size was explicitly set to prevent binaries
     * made with Visual Studio 2005 (no service packs) from crashing
     * when run in lean mode. This problem may have been fixed in
     * Service Pack 1.
     *
     *****************************************************************
     */
    setvbuf(psProperties->pFileOut, NULL, _IOLBF, 1024);
#else
    setvbuf(psProperties->pFileOut, NULL, _IOLBF, 0);
#endif
  }
  else
  {
    strncpy(psProperties->acOutFileName, "stdout", FTIMES_MAX_PATH);
    psProperties->pFileOut = stdout;
  }

  /*-
   *********************************************************************
   *
   * Display properties.
   *
   *********************************************************************
   */
  PropertiesDisplaySettings(psProperties);

#ifdef USE_XMAGIC
  if (MASK_BIT_IS_SET(psProperties->psFieldMask->ulMask, MAP_MAGIC))
  {
    snprintf(acMessage, MESSAGE_SIZE, "%s=%s", KEY_MagicFile, psProperties->acMagicFileName);
    MessageHandler(MESSAGE_QUEUE_IT, MESSAGE_INFORMATION, MESSAGE_PROPERTY_STRING, acMessage);

    snprintf(acMessage, MESSAGE_SIZE, "MagicHash=%s", psProperties->acMagicHash);
    MessageHandler(MESSAGE_QUEUE_IT, MESSAGE_INFORMATION, MESSAGE_PROPERTY_STRING, acMessage);
  }
#endif

  /*-
   *********************************************************************
   *
   * Write out a header.
   *
   *********************************************************************
   */
  iError = MapWriteHeader(psProperties, acLocalError);
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
 * MapModeWorkHorse
 *
 ***********************************************************************
 */
int
MapModeWorkHorse(void *pvProperties, char *pcError)
{
  char                acLocalError[MESSAGE_SIZE] = "";
  FILE_LIST           *psList = NULL;
  FTIMES_PROPERTIES  *psProperties = (FTIMES_PROPERTIES *)pvProperties;

  /*-
   *********************************************************************
   *
   * Process the Include list.
   *
   *********************************************************************
   */
  for (psList = psProperties->psIncludeList; psList != NULL; psList = psList->psNext)
  {
    if (SupportMatchExclude(psProperties->psExcludeList, psList->pcRegularPath) == NULL)
    {
      MapFile(psProperties, psList->pcRegularPath, acLocalError);
    }
  }

  return ER_OK;
}


/*-
 ***********************************************************************
 *
 * MapModeFinishUp
 *
 ***********************************************************************
 */
int
MapModeFinishUp(void *pvProperties, char *pcError)
{
  char                acMessage[MESSAGE_SIZE];
  int                 i;
  int                 iFirst;
  int                 iIndex;
  FTIMES_PROPERTIES  *psProperties = (FTIMES_PROPERTIES *)pvProperties;
  unsigned char       aucFileHash[MD5_HASH_SIZE];

  /*-
   *********************************************************************
   *
   * Close up the output stream, and complete the file digest.
   *
   *********************************************************************
   */
  if (psProperties->pFileOut && psProperties->pFileOut != stdout)
  {
    fflush(psProperties->pFileOut);
    fclose(psProperties->pFileOut);
    psProperties->pFileOut = NULL;
  }

  memset(aucFileHash, 0, MD5_HASH_SIZE);
  MD5Omega(&psProperties->sOutFileHashContext, aucFileHash);
  MD5HashToHex(aucFileHash, psProperties->acOutFileHash);

  /*-
   *********************************************************************
   *
   * Print output filenames.
   *
   *********************************************************************
   */
  snprintf(acMessage, MESSAGE_SIZE, "LogFileName=%s", psProperties->acLogFileName);
  MessageHandler(MESSAGE_QUEUE_IT, MESSAGE_INFORMATION, MESSAGE_PROPERTY_STRING, acMessage);

  snprintf(acMessage, MESSAGE_SIZE, "OutFileName=%s", psProperties->acOutFileName);
  MessageHandler(MESSAGE_QUEUE_IT, MESSAGE_INFORMATION, MESSAGE_PROPERTY_STRING, acMessage);

  snprintf(acMessage, MESSAGE_SIZE, "OutFileHash=%s", psProperties->acOutFileHash);
  MessageHandler(MESSAGE_QUEUE_IT, MESSAGE_INFORMATION, MESSAGE_PROPERTY_STRING, acMessage);

  snprintf(acMessage, MESSAGE_SIZE, "DataType=%s", psProperties->acDataType);
  MessageHandler(MESSAGE_QUEUE_IT, MESSAGE_INFORMATION, MESSAGE_PROPERTY_STRING, acMessage);

  /*-
   *********************************************************************
   *
   * Write out the statistics.
   *
   *********************************************************************
   */
  snprintf(acMessage, MESSAGE_SIZE, "DirectoriesEncountered=%d", MapGetDirectoryCount());
  MessageHandler(MESSAGE_QUEUE_IT, MESSAGE_INFORMATION, MESSAGE_PROPERTY_STRING, acMessage);

  snprintf(acMessage, MESSAGE_SIZE, "FilesEncountered=%d", MapGetFileCount());
  MessageHandler(MESSAGE_QUEUE_IT, MESSAGE_INFORMATION, MESSAGE_PROPERTY_STRING, acMessage);

#ifdef UNIX
  snprintf(acMessage, MESSAGE_SIZE, "SpecialsEncountered=%d", MapGetSpecialCount());
  MessageHandler(MESSAGE_QUEUE_IT, MESSAGE_INFORMATION, MESSAGE_PROPERTY_STRING, acMessage);
#endif

#ifdef WINNT
  snprintf(acMessage, MESSAGE_SIZE, "StreamsEncountered=%d", MapGetStreamCount());
  MessageHandler(MESSAGE_QUEUE_IT, MESSAGE_INFORMATION, MESSAGE_PROPERTY_STRING, acMessage);
#endif

  iIndex = 0;
  if (psProperties->iLastAnalysisStage > 0)
  {
    iIndex = sprintf(&acMessage[iIndex], "AnalysisStages=");
    for (i = 0, iFirst = 0; i < psProperties->iLastAnalysisStage; i++)
    {
      iIndex += sprintf(&acMessage[iIndex], "%s%s", (iFirst++ > 0) ? "," : "", psProperties->asAnalysisStages[i].acDescription);
    }
    MessageHandler(MESSAGE_QUEUE_IT, MESSAGE_INFORMATION, MESSAGE_PROPERTY_STRING, acMessage);

    snprintf(acMessage, MESSAGE_SIZE, "ObjectsAnalyzed=%u", AnalyzeGetFileCount());
    MessageHandler(MESSAGE_QUEUE_IT, MESSAGE_INFORMATION, MESSAGE_PROPERTY_STRING, acMessage);

#ifdef UNIX
#ifdef USE_AP_SNPRINTF
    snprintf(acMessage, MESSAGE_SIZE, "BytesAnalyzed=%qu", (unsigned long long) AnalyzeGetByteCount());
    MessageHandler(MESSAGE_QUEUE_IT, MESSAGE_INFORMATION, MESSAGE_PROPERTY_STRING, acMessage);
#else
    snprintf(acMessage, MESSAGE_SIZE, "BytesAnalyzed=%llu", (unsigned long long) AnalyzeGetByteCount());
    MessageHandler(MESSAGE_QUEUE_IT, MESSAGE_INFORMATION, MESSAGE_PROPERTY_STRING, acMessage);
#endif
#endif

#ifdef WIN32
    snprintf(acMessage, MESSAGE_SIZE, "BytesAnalyzed=%I64u", AnalyzeGetByteCount());
    MessageHandler(MESSAGE_QUEUE_IT, MESSAGE_INFORMATION, MESSAGE_PROPERTY_STRING, acMessage);
#endif
  }
  else
  {
    snprintf(acMessage, MESSAGE_SIZE, "AnalysisStages=None");
    MessageHandler(MESSAGE_QUEUE_IT, MESSAGE_INFORMATION, MESSAGE_PROPERTY_STRING, acMessage);
  }

  /*-
   *********************************************************************
   *
   * List the number of map records.
   *
   *********************************************************************
   */
  snprintf(acMessage, MESSAGE_SIZE, "MapRecords=%d", MapGetRecordCount());
  MessageHandler(MESSAGE_QUEUE_IT, MESSAGE_INFORMATION, MESSAGE_PROPERTY_STRING, acMessage);

  snprintf(acMessage, MESSAGE_SIZE, "PartialMapRecords=%d", MapGetIncompleteRecordCount());
  MessageHandler(MESSAGE_QUEUE_IT, MESSAGE_INFORMATION, MESSAGE_PROPERTY_STRING, acMessage);

  SupportDisplayRunStatistics(psProperties);

  return ER_OK;
}


/*-
 ***********************************************************************
 *
 * MapModeFinalStage
 *
 ***********************************************************************
 */
int
MapModeFinalStage(void *pvProperties, char *pcError)
{
  const char          acRoutine[] = "MapModeFinalStage()";
  char                acLocalError[MESSAGE_SIZE] = "";
  FTIMES_PROPERTIES  *psProperties = (FTIMES_PROPERTIES *)pvProperties;
  int                 iError;

  /*-
   *********************************************************************
   *
   * Conditionally upload the collected data.
   *
   *********************************************************************
   */
  if (psProperties->bURLPutSnapshot && psProperties->iRunMode == FTIMES_MAPMODE)
  {
    iError = URLPutRequest(psProperties, acLocalError);
    if (iError != ER_OK)
    {
      snprintf(pcError, MESSAGE_SIZE, "%s: %s", acRoutine, acLocalError);
      return ER_URLPutRequest;
    }

    if (psProperties->bURLUnlinkOutput)
    {
      FTimesEraseFiles(psProperties, pcError);
    }
  }

  return ER_OK;
}
