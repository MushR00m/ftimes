######################################################################
#
# $Id: EadRoutines.pm,v 1.54 2019/06/26 14:15:16 klm Exp $
#
######################################################################
#
# Copyright 2008-2019 The FTimes Project, All Rights Reserved.
#
######################################################################
#
# Purpose: Home for various encoder and decoder routines.
#
######################################################################

package FTimes::EadRoutines;

require Exporter;

use 5.008;
use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %ghUnixGidMap %ghUnixUidMap);

@EXPORT = qw
(
  EadBase32Decode
  EadBase32Encode
  EadBase32ToHex
  EadBase32ToHexDump
  EadBase64Decode
  EadBase64Encode
  EadBase64ToHex
  EadBase64ToHexDump
  EadBase64UrlDecode
  EadBase64UrlEncode
  EadBase64UrlToHex
  EadBase64UrlToHexDump
  EadBookendHexDecode
  EadBookendHexEncode
  EadFTimesNssDecode
  EadFTimesNssEncode
  EadFTimesSssDecode
  EadFTimesSssEncode
  EadFTimesUrlDecode
  EadFTimesUrlEncode
  EadGetDecoders
  EadHexDecode
  EadHexDecodeArray
  EadHexDecodeCString
  EadHexDump
  EadHexDumpRecords
  EadHexEncode
  EadHexEncodeArray
  EadHexEncodeCString
  EadHexToBase32
  EadHexToBase64
  EadHexToBase64Url
  EadHexToHexDump
  EadNopDecode
  EadNopEncode
  EadNotDecode
  EadNotEncode
  EadSafeBookendHexDecode
  EadSafeBookendHexEncode
  EadUnixModeDecode
  EadUnixGidDecode
  EadUnixUidDecode
  EadUrlDecode
  EadUrlEncode
  EadWinxAceDecode
  EadWinxAttributesDecode
  EadWinxDaclDecode
  EadWrapInQuotes
  EadXformViaAnd
  EadXformViaNop
  EadXformViaNot
  EadXformViaRot13
  EadXformViaRot47
  EadXformViaXor
);
@EXPORT_OK = ();
@ISA = qw(Exporter);
$VERSION = do { my @r = (q$Revision: 1.54 $ =~ /(\d+)/g); sprintf("%d."."%03d" x $#r, @r); };

######################################################################
#
# Constants
#
######################################################################

my $gsFILE_ATTRIBUTE_READONLY            = 0x00000001; # RO
my $gsFILE_ATTRIBUTE_HIDDEN              = 0x00000002; # H
my $gsFILE_ATTRIBUTE_SYSTEM              = 0x00000004; # S
# ?                                      = 0x00000008;
my $gsFILE_ATTRIBUTE_DIRECTORY           = 0x00000010; # D
my $gsFILE_ATTRIBUTE_ARCHIVE             = 0x00000020; # A
my $gsFILE_ATTRIBUTE_DEVICE              = 0x00000040; # DEV
my $gsFILE_ATTRIBUTE_NORMAL              = 0x00000080; # N
my $gsFILE_ATTRIBUTE_TEMPORARY           = 0x00000100; # T
my $gsFILE_ATTRIBUTE_SPARSE_FILE         = 0x00000200; # SF
my $gsFILE_ATTRIBUTE_REPARSE_POINT       = 0x00000400; # RP
my $gsFILE_ATTRIBUTE_COMPRESSED          = 0x00000800; # C
my $gsFILE_ATTRIBUTE_OFFLINE             = 0x00001000; # O
my $gsFILE_ATTRIBUTE_NOT_CONTENT_INDEXED = 0x00002000; # NCI
my $gsFILE_ATTRIBUTE_ENCRYPTED           = 0x00004000; # E
my $gsFILE_ATTRIBUTE_INTEGRITY_STREAM    = 0x00008000; # IS
my $gsFILE_ATTRIBUTE_VIRTUAL             = 0x00010000; # V
my $gsFILE_ATTRIBUTE_NO_SCRUB_DATA       = 0x00020000; # NSD

my $gsADS_RIGHT_DS_CREATE_CHILD          = 0x00000001;
my $gsADS_RIGHT_DS_DELETE_CHILD          = 0x00000002;
my $gsADS_RIGHT_ACTRL_DS_LIST            = 0x00000004;
my $gsADS_RIGHT_DS_SELF                  = 0x00000008;
my $gsADS_RIGHT_DS_READ_PROP             = 0x00000010;
my $gsADS_RIGHT_DS_WRITE_PROP            = 0x00000020;
my $gsADS_RIGHT_DS_DELETE_TREE           = 0x00000040;
my $gsADS_RIGHT_DS_LIST_OBJECT           = 0x00000080;
my $gsADS_RIGHT_DS_CONTROL_ACCESS        = 0x00000100;
my $gsADS_RIGHT_DELETE                   = 0x00010000;
my $gsADS_RIGHT_READ_CONTROL             = 0x00020000;
my $gsADS_RIGHT_WRITE_DAC                = 0x00040000;
my $gsADS_RIGHT_WRITE_OWNER              = 0x00080000;
my $gsADS_RIGHT_SYNCHRONIZE              = 0x00100000;
# ?                                      = 0x00200000;
# ?                                      = 0x00400000;
# ?                                      = 0x00800000;
my $gsADS_RIGHT_ACCESS_SYSTEM_SECURITY   = 0x01000000;
# ?                                      = 0x02000000;
# ?                                      = 0x04000000;
# ?                                      = 0x08000000;
my $gsADS_RIGHT_GENERIC_ALL              = 0x10000000;
my $gsADS_RIGHT_GENERIC_EXECUTE          = 0x20000000;
my $gsADS_RIGHT_GENERIC_WRITE            = 0x40000000;
my $gsADS_RIGHT_GENERIC_READ             = 0x80000000;

my $gsFILE_READ_DATA                     = 0x00000001;
my $gsFILE_WRITE_DATA                    = 0x00000002;
my $gsFILE_APPEND_DATA                   = 0x00000004;
my $gsFILE_READ_EA                       = 0x00000008;
my $gsFILE_WRITE_EA                      = 0x00000010;
my $gsFILE_EXECUTE                       = 0x00000020;
my $gsFILE_DELETE_CHILD                  = 0x00000040;
my $gsFILE_READ_ATTRIBUTES               = 0x00000080;
my $gsFILE_WRITE_ATTRIBUTES              = 0x00000100;

my $gsKEY_QUERY_VALUE                    = 0x00000001;
my $gsKEY_SET_VALUE                      = 0x00000002;
my $gsKEY_CREATE_SUB_KEY                 = 0x00000004;
my $gsKEY_ENUMERATE_SUB_KEYS             = 0x00000008;
my $gsKEY_NOTIFY                         = 0x00000010;
my $gsKEY_CREATE_LINK                    = 0x00000020;

my $gsDELETE                             = 0x00010000;
my $gsREAD_CONTROL                       = 0x00020000;
my $gsWRITE_DAC                          = 0x00040000;
my $gsWRITE_OWNER                        = 0x00080000;
my $gsSYNCHRONIZE                        = 0x00100000;

my $gsGENERIC_ALL                        = 0x10000000;
my $gsGENERIC_EXECUTE                    = 0x20000000;
my $gsGENERIC_WRITE                      = 0x40000000;
my $gsGENERIC_READ                       = 0x80000000;

my $gsSTANDARD_RIGHTS_REQUIRED           = 0x000F0000;
my $gsSTANDARD_RIGHTS_READ               = $gsREAD_CONTROL;
my $gsSTANDARD_RIGHTS_WRITE              = $gsREAD_CONTROL;
my $gsSTANDARD_RIGHTS_EXECUTE            = $gsREAD_CONTROL;
my $gsSTANDARD_RIGHTS_ALL                = 0x001F0000;
my $gsSPECIFIC_RIGHTS_ALL                = 0x0000FFFF;

my $gsFILE_ALL_ACCESS                    = ($gsSTANDARD_RIGHTS_REQUIRED | $gsSYNCHRONIZE | 0x1FF);
my $gsFILE_GENERIC_READ                  = ($gsSTANDARD_RIGHTS_READ | $gsFILE_READ_DATA | $gsFILE_READ_ATTRIBUTES | $gsFILE_READ_EA | $gsSYNCHRONIZE);
my $gsFILE_GENERIC_WRITE                 = ($gsSTANDARD_RIGHTS_WRITE | $gsFILE_WRITE_DATA | $gsFILE_WRITE_ATTRIBUTES | $gsFILE_WRITE_EA | $gsFILE_APPEND_DATA | $gsSYNCHRONIZE);
my $gsFILE_GENERIC_EXECUTE               = ($gsSTANDARD_RIGHTS_EXECUTE | $gsFILE_READ_ATTRIBUTES | $gsFILE_EXECUTE | $gsSYNCHRONIZE);
my $gsKEY_ALL_ACCESS                     = (($gsSTANDARD_RIGHTS_ALL | $gsKEY_QUERY_VALUE | $gsKEY_SET_VALUE | $gsKEY_CREATE_SUB_KEY | $gsKEY_ENUMERATE_SUB_KEYS | $gsKEY_NOTIFY | $gsKEY_CREATE_LINK) & (~$gsSYNCHRONIZE));
my $gsKEY_READ                           = (($gsSTANDARD_RIGHTS_READ | $gsKEY_QUERY_VALUE | $gsKEY_ENUMERATE_SUB_KEYS | $gsKEY_NOTIFY) & (~$gsSYNCHRONIZE));
my $gsKEY_WRITE                          = (($gsSTANDARD_RIGHTS_WRITE | $gsKEY_SET_VALUE | $gsKEY_CREATE_SUB_KEY) & (~$gsSYNCHRONIZE));
my $gsKEY_EXECUTE                        = (($gsKEY_READ) & (~$gsSYNCHRONIZE));

######################################################################
#
# Tables
#
######################################################################

my @gaBase32 = split(//, "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567");

my @gaFromBase32;
for (my $i = 0; $i < 256; $i++)
{
  push(@gaFromBase32, -1);
}
for (my $i = 0; $i < scalar(@gaBase32); $i++)
{
  $gaFromBase32[ord($gaBase32[$i])] = $i;
}

my @gaBase64 = split(//, "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/");

my @gaFromBase64;
for (my $i = 0; $i < 256; $i++)
{
  push(@gaFromBase64, -1);
}
for (my $i = 0; $i < scalar(@gaBase64); $i++)
{
  $gaFromBase64[ord($gaBase64[$i])] = $i;
}

my @gaBase64Url = split(//, "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_");

my @gaFromBase64Url;
for (my $i = 0; $i < 256; $i++)
{
  push(@gaFromBase64Url, -1);
}
for (my $i = 0; $i < scalar(@gaBase64Url); $i++)
{
  $gaFromBase64Url[ord($gaBase64Url[$i])] = $i;
}

my %ghDecoders =
(
  'base32' => \&EadBase32Decode,
  'base64' => \&EadBase64Decode,
  'base64url' => \&EadBase64UrlDecode,
  'hex'    => \&EadHexDecode,
  'nop'    => \&EadNopDecode,
  'url'    => \&EadUrlDecode,
);

my %ghUnixPermissions =
(
  '0' => "x",
  '1' => "w",
  '2' => "r",
  '3' => "x",
  '4' => "w",
  '5' => "r",
  '6' => "x",
  '7' => "w",
  '8' => "r",
);

my %ghWinxAceFlags =
(
  'CI' => "CONTAINER_INHERIT_ACE",
  'FA' => "FAILED_ACCESS_ACE_FLAG",
  'ID' => "INHERITED_ACE",
  'IO' => "INHERIT_ONLY_ACE",
  'NP' => "NO_PROPAGATE_INHERIT_ACE",
  'OI' => "OBJECT_INHERIT_ACE",
  'SA' => "SUCCESSFUL_ACCESS_ACE_FLAG",
);

my %ghWinxAceRights =
(
  'CC' => "ADS_RIGHT_DS_CREATE_CHILD",
  'CR' => "ADS_RIGHT_DS_CONTROL_ACCESS",
  'DC' => "ADS_RIGHT_DS_DELETE_CHILD",
  'DT' => "ADS_RIGHT_DS_DELETE_TREE",
  'FA' => "FILE_ALL_ACCESS",
  'FR' => "FILE_GENERIC_READ",
  'FW' => "FILE_GENERIC_WRITE",
  'FX' => "FILE_GENERIC_EXECUTE",
  'GA' => "GENERIC_ALL",
  'GR' => "GENERIC_READ",
  'GW' => "GENERIC_WRITE",
  'GX' => "GENERIC_EXECUTE",
  'KA' => "KEY_ALL_ACCESS",
  'KR' => "KEY_READ",
  'KW' => "KEY_WRITE",
  'KX' => "KEY_EXECUTE",
  'LC' => "ADS_RIGHT_ACTRL_DS_LIST",
  'LO' => "ADS_RIGHT_DS_LIST_OBJECT",
  'RC' => "READ_CONTROL",
  'RP' => "ADS_RIGHT_DS_READ_PROP",
  'SD' => "DELETE",
  'SW' => "ADS_RIGHT_DS_SELF",
  'WD' => "WRITE_DAC",
  'WO' => "WRITE_OWNER",
  'WP' => "ADS_RIGHT_DS_WRITE_PROP",
);

my %ghWinxAceHexRights =
(
  'CC' => $gsADS_RIGHT_DS_CREATE_CHILD,
  'CR' => $gsADS_RIGHT_DS_CONTROL_ACCESS,
  'DC' => $gsADS_RIGHT_DS_DELETE_CHILD,
  'DT' => $gsADS_RIGHT_DS_DELETE_TREE,
  'FA' => $gsFILE_ALL_ACCESS,
  'FR' => $gsFILE_GENERIC_READ,
  'FW' => $gsFILE_GENERIC_WRITE,
  'FX' => $gsFILE_GENERIC_EXECUTE,
  'GA' => $gsGENERIC_ALL,
  'GR' => $gsGENERIC_READ,
  'GW' => $gsGENERIC_WRITE,
  'GX' => $gsGENERIC_EXECUTE,
  'KA' => $gsKEY_ALL_ACCESS,
  'KR' => $gsKEY_READ,
  'KW' => $gsKEY_WRITE,
  'KX' => $gsKEY_EXECUTE,
  'LC' => $gsADS_RIGHT_ACTRL_DS_LIST,
  'LO' => $gsADS_RIGHT_DS_LIST_OBJECT,
  'RC' => $gsREAD_CONTROL,
  'RP' => $gsADS_RIGHT_DS_READ_PROP,
  'SD' => $gsDELETE,
  'SW' => $gsADS_RIGHT_DS_SELF,
  'WD' => $gsWRITE_DAC,
  'WO' => $gsWRITE_OWNER,
  'WP' => $gsADS_RIGHT_DS_WRITE_PROP,
);

my %ghWinxAceTrustees =
(
  'AN' => "ANONYMOUS",
  'AO' => "ACCOUNT_OPERATORS",
  'AU' => "AUTHENTICATED_USERS",
  'BA' => "BUILTIN_ADMINISTRATORS",
  'BG' => "BUILTIN_GUESTS",
  'BO' => "BACKUP_OPERATORS",
  'BU' => "BUILTIN_USERS",
  'CA' => "CERT_SERV_ADMINISTRATORS",
  'CG' => "CREATOR_GROUP",
  'CO' => "CREATOR_OWNER",
  'DA' => "DOMAIN_ADMINISTRATORS",
  'DC' => "DOMAIN_COMPUTERS",
  'DD' => "DOMAIN_DOMAIN_CONTROLLERS",
  'DG' => "DOMAIN_GUESTS",
  'DU' => "DOMAIN_USERS",
  'EA' => "ENTERPRISE_ADMINS",
  'ED' => "ENTERPRISE_DOMAIN_CONTROLLERS",
  'IU' => "INTERACTIVE",
  'LA' => "LOCAL_ADMIN",
  'LG' => "LOCAL_GUEST",
  'LS' => "LOCAL_SERVICE",
  'LU' => "PERFLOG_USERS",
  'MU' => "PERFMON_USERS",
  'NO' => "NETWORK_CONFIGURATION_OPS",
  'NS' => "NETWORK_SERVICE",
  'NU' => "NETWORK",
  'PA' => "GROUP_POLICY_ADMINS",
  'PO' => "PRINTER_OPERATORS",
  'PS' => "PERSONAL_SELF",
  'PU' => "POWER_USERS",
  'RC' => "RESTRICTED_CODE",
  'RD' => "REMOTE_DESKTOP",
  'RE' => "REPLICATOR",
  'RS' => "RAS_SERVERS",
  'RU' => "ALIAS_PREW2KCOMPACC",
  'SA' => "SCHEMA_ADMINISTRATORS",
  'SO' => "SERVER_OPERATORS",
  'SU' => "SERVICE",
  'SY' => "LOCAL_SYSTEM",
  'WD' => "EVERYONE",
);

my %ghWinxAceTypes =
(
  'A'  => "ACCESS_ALLOWED",
  'AL' => "ALARM",
  'AU' => "AUDIT",
  'D'  => "ACCESS_DENIED",
  'OA' => "OBJECT_ACCESS_ALLOWED",
  'OD' => "OBJECT_ACCESS_DENIED",
  'OL' => "OBJECT_ALARM",
  'OU' => "OBJECT_AUDIT",
);

my %ghWinxAttributes =
(
  $gsFILE_ATTRIBUTE_READONLY            => "RO",
  $gsFILE_ATTRIBUTE_HIDDEN              => "H",
  $gsFILE_ATTRIBUTE_SYSTEM              => "S",
  $gsFILE_ATTRIBUTE_DIRECTORY           => "D",
  $gsFILE_ATTRIBUTE_ARCHIVE             => "A",
  $gsFILE_ATTRIBUTE_DEVICE              => "DEV",
  $gsFILE_ATTRIBUTE_NORMAL              => "N",
  $gsFILE_ATTRIBUTE_TEMPORARY           => "T",
  $gsFILE_ATTRIBUTE_SPARSE_FILE         => "SF",
  $gsFILE_ATTRIBUTE_REPARSE_POINT       => "RP",
  $gsFILE_ATTRIBUTE_COMPRESSED          => "C",
  $gsFILE_ATTRIBUTE_OFFLINE             => "O",
  $gsFILE_ATTRIBUTE_NOT_CONTENT_INDEXED => "NCI",
  $gsFILE_ATTRIBUTE_ENCRYPTED           => "E",
  $gsFILE_ATTRIBUTE_INTEGRITY_STREAM    => "IS",
  $gsFILE_ATTRIBUTE_VIRTUAL             => "V",
  $gsFILE_ATTRIBUTE_NO_SCRUB_DATA       => "NSD",
);


######################################################################
#
# EadBase32Decode
#
######################################################################

sub EadBase32Decode
{
  my ($sData) = @_;

  ####################################################################
  #
  # Make sure we have some input. Then, chop off everything past the
  # first terminator.
  #
  ####################################################################

  if (!defined($sData))
  {
    return undef;
  }
  $sData =~ s/=.*$//;

  ####################################################################
  #
  # Decode the input.
  #
  ####################################################################

  my $sDecoded = "";
  my $sNLeft = 0;
  my $sValue = 0;
  foreach my $sByte (split(//, $sData))
  {
    if ($gaFromBase32[ord($sByte)] < 0)
    {
      return undef; # Invalid input.
    }
    $sValue = ($sValue << 5) | $gaFromBase32[ord($sByte)];
    $sNLeft += 5;
    while ($sNLeft >= 8)
    {
      $sDecoded .= chr(($sValue >> ($sNLeft - 8)) & 0xff);
      $sNLeft -= 8;
    }
  }

  return $sDecoded;
}


######################################################################
#
# EadBase32Encode
#
######################################################################

sub EadBase32Encode
{
  my ($sData) = @_;

  ####################################################################
  #
  # Make sure we have some input.
  #
  ####################################################################

  if (!defined($sData))
  {
    return undef;
  }
  my $sLength = length($sData);

  ####################################################################
  #
  # Encode the input.
  #
  ####################################################################

  my $sEncoded = "";
  my $sNLeft = 0;
  my $sNFill = 0;
  my $sValue = 0;
  foreach my $sByte (split(//, $sData))
  {
    $sValue = ($sValue << 8) | ord($sByte);
    $sNLeft += 8;
    while ($sNLeft > 5)
    {
      $sEncoded .= $gaBase32[($sValue >> ($sNLeft - 5)) & 0x1f];
      $sNLeft -= 5;
    }
  }
  if ($sNLeft != 0)
  {
    $sEncoded .= $gaBase32[($sValue << (5 - $sNLeft)) & 0x1f];
  }

  my @aPaddings = ("", "======", "====", "===", "=");

  $sEncoded .= $aPaddings[$sLength % 5];

  return $sEncoded;
}


######################################################################
#
# EadBase32ToHex
#
######################################################################

sub EadBase32ToHex
{
  return EadHexEncode(EadBase32Decode(@_));
}


######################################################################
#
# EadBase32ToHexDump
#
######################################################################

sub EadBase32ToHexDump
{
  return EadHexDump(EadBase32Decode(@_));
}


######################################################################
#
# EadBase64Decode
#
######################################################################

sub EadBase64Decode
{
  my ($sData) = @_;

  ####################################################################
  #
  # Make sure we have some input. Then, chop off everything past the
  # first terminator.
  #
  ####################################################################

  if (!defined($sData))
  {
    return undef;
  }
  $sData =~ s/=.*$//;

  ####################################################################
  #
  # Decode the input.
  #
  ####################################################################

  my $sDecoded = "";
  my $sNLeft = 0;
  my $sValue = 0;
  foreach my $sByte (split(//, $sData))
  {
    if ($gaFromBase64[ord($sByte)] < 0)
    {
      return undef; # Invalid input.
    }
    $sValue = ($sValue << 6) | $gaFromBase64[ord($sByte)];
    $sNLeft += 6;
    while ($sNLeft >= 8)
    {
      $sDecoded .= chr(($sValue >> ($sNLeft - 8)) & 0xff);
      $sNLeft -= 8;
    }
  }

  return $sDecoded;
}


######################################################################
#
# EadBase64Encode
#
######################################################################

sub EadBase64Encode
{
  my ($sData) = @_;

  ####################################################################
  #
  # Make sure we have some input.
  #
  ####################################################################

  if (!defined($sData))
  {
    return undef;
  }
  my $sLength = length($sData);

  ####################################################################
  #
  # Encode the input.
  #
  ####################################################################

  my $sEncoded = "";
  my $sNLeft = 0;
  my $sNFill = 0;
  my $sValue = 0;
  foreach my $sByte (split(//, $sData))
  {
    $sValue = ($sValue << 8) | ord($sByte);
    $sNLeft += 8;
    while ($sNLeft > 6)
    {
      $sEncoded .= $gaBase64[($sValue >> ($sNLeft - 6)) & 0x3f];
      $sNLeft -= 6;
    }
  }
  if ($sNLeft != 0)
  {
    $sEncoded .= $gaBase64[($sValue << (6 - $sNLeft)) & 0x3f];
  }
  $sNFill = ($sLength % 3) ? 3 - ($sLength % 3) : 0;
  for (my $i = 0; $i < $sNFill; $i++)
  {
    $sEncoded .= '=';
  }

  return $sEncoded;
}


######################################################################
#
# EadBase64ToHex
#
######################################################################

sub EadBase64ToHex
{
  return EadHexEncode(EadBase64Decode(@_));
}


######################################################################
#
# EadBase64ToHexDump
#
######################################################################

sub EadBase64ToHexDump
{
  return EadHexDump(EadBase64Decode(@_));
}


######################################################################
#
# EadBase64UrlDecode
#
######################################################################

sub EadBase64UrlDecode
{
  my ($sData) = @_;

  ####################################################################
  #
  # Make sure we have some input. Then, chop off everything past the
  # first terminator.
  #
  ####################################################################

  if (!defined($sData))
  {
    return undef;
  }
  $sData =~ s/=.*$//;

  ####################################################################
  #
  # Decode the input.
  #
  ####################################################################

  my $sDecoded = "";
  my $sNLeft = 0;
  my $sValue = 0;
  foreach my $sByte (split(//, $sData))
  {
    if ($gaFromBase64Url[ord($sByte)] < 0)
    {
      return undef; # Invalid input.
    }
    $sValue = ($sValue << 6) | $gaFromBase64Url[ord($sByte)];
    $sNLeft += 6;
    while ($sNLeft >= 8)
    {
      $sDecoded .= chr(($sValue >> ($sNLeft - 8)) & 0xff);
      $sNLeft -= 8;
    }
  }

  return $sDecoded;
}


######################################################################
#
# EadBase64UrlEncode
#
######################################################################

sub EadBase64UrlEncode
{
  my ($sData) = @_;

  ####################################################################
  #
  # Make sure we have some input.
  #
  ####################################################################

  if (!defined($sData))
  {
    return undef;
  }
  my $sLength = length($sData);

  ####################################################################
  #
  # Encode the input.
  #
  ####################################################################

  my $sEncoded = "";
  my $sNLeft = 0;
  my $sNFill = 0;
  my $sValue = 0;
  foreach my $sByte (split(//, $sData))
  {
    $sValue = ($sValue << 8) | ord($sByte);
    $sNLeft += 8;
    while ($sNLeft > 6)
    {
      $sEncoded .= $gaBase64Url[($sValue >> ($sNLeft - 6)) & 0x3f];
      $sNLeft -= 6;
    }
  }
  if ($sNLeft != 0)
  {
    $sEncoded .= $gaBase64Url[($sValue << (6 - $sNLeft)) & 0x3f];
  }
  $sNFill = ($sLength % 3) ? 3 - ($sLength % 3) : 0;
  for (my $i = 0; $i < $sNFill; $i++)
  {
    $sEncoded .= '=';
  }

  return $sEncoded;
}


######################################################################
#
# EadBase64UrlToHex
#
######################################################################

sub EadBase64UrlToHex
{
  return EadHexEncode(EadBase64UrlDecode(@_));
}


######################################################################
#
# EadBase64UrlToHexDump
#
######################################################################

sub EadBase64UrlToHexDump
{
  return EadHexDump(EadBase64UrlDecode(@_));
}


######################################################################
#
# EadBookendHexDecode
#
######################################################################

sub EadBookendHexDecode
{
  my ($sData, $sLBookend, $sRBookend) = @_;

  if (!defined($sLBookend) && !defined($sRBookend)) # Conditionally define bookends.
  {
    $sLBookend //= '[';
    $sRBookend //= ']';
  }

  if # Conditionally perform the operation. Otherwise, return data unmodified.
  (
       $sLBookend eq '(' && $sRBookend eq ')'
    || $sLBookend eq '<' && $sRBookend eq '>'
    || $sLBookend eq '[' && $sRBookend eq ']'
    || $sLBookend eq '{' && $sRBookend eq '}'
  )
  {
    $sData =~ s/[$sLBookend]\\n[$sRBookend]/pack('C', hex("0x0a"))/seg;
    $sData =~ s/[$sLBookend]\\r[$sRBookend]/pack('C', hex("0x0d"))/seg;
    $sData =~ s/[$sLBookend]0x([0-9a-fA-F]{1,2})[$sRBookend]/pack('C', hex($1))/seg;
  }

  return $sData;
}


######################################################################
#
# EadBookendHexEncode
#
######################################################################

sub EadBookendHexEncode
{
  my ($sData, $sLBookend, $sRBookend) = @_;

  if (!defined($sLBookend) && !defined($sRBookend)) # Conditionally define bookends.
  {
    $sLBookend //= '[';
    $sRBookend //= ']';
  }

  if # Conditionally perform the operation. Otherwise, return data unmodified.
  (
       $sLBookend eq '(' && $sRBookend eq ')'
    || $sLBookend eq '<' && $sRBookend eq '>'
    || $sLBookend eq '[' && $sRBookend eq ']'
    || $sLBookend eq '{' && $sRBookend eq '}'
  )
  {
    $sData =~ s/\x0a/$sLBookend."\\n".$sRBookend/seg;
    $sData =~ s/\x0d/$sLBookend."\\r".$sRBookend/seg;
    $sData =~ s/([^\x20-\x7f])/sprintf("%s0x%02x%s", $sLBookend, unpack('C', $1), $sRBookend)/seg;
  }

  return $sData;
}


######################################################################
#
# EadFTimesNssDecode (NSS - Neuter Safe String)
#
######################################################################

sub EadFTimesNssDecode
{
  my ($sData) = @_;
  $sData =~ s/_([0-9a-fA-F]{2})_/pack('C', hex($1))/seg;
  return $sData;
}


######################################################################
#
# EadFTimesNssEncode (NSS - Neuter Safe String)
#
######################################################################

sub EadFTimesNssEncode
{
  my ($sData) = @_;
  $sData =~ s/([^.\/0-9A-Za-z-])/sprintf("_%02x_", unpack('C', $1))/seg;
  return $sData;
}


######################################################################
#
# EadFTimesSssDecode (SSS - Shell Safe String)
#
######################################################################

sub EadFTimesSssDecode
{
  my ($sData) = @_;
  $sData =~ s/\+/ /sg;
  $sData =~ s/%([0-9a-fA-F]{2})/pack('C', hex($1))/seg;
  return $sData;
}


######################################################################
#
# EadFTimesSssEncode (SSS - Shell Safe String)
#
######################################################################

sub EadFTimesSssEncode
{
  my ($sData) = @_;
  $sData =~ s/([\x00-\x1f\x21-\x2b\x3b-\x3f\x5b-\x5e\x60\x7b-\x7e\x7f-\xff])/sprintf("%%%02x", unpack('C',$1))/seg;
  #                         |    |   |    |   |    |   |   |    |
  #              0x21  ! <--+    |   |    |   |    |   |   |    |
  #              0x22  "         |   |    |   |    |   |   |    |
  #              0x23  #         |   |    |   |    |   |   |    |
  #              0x24  $         |   |    |   |    |   |   |    |
  #              0x25  %         |   |    |   |    |   |   |    |
  #              0x26  &         |   |    |   |    |   |   |    |
  #              0x27  '         |   |    |   |    |   |   |    |
  #              0x28  (         |   |    |   |    |   |   |    |
  #              0x29  )         |   |    |   |    |   |   |    |
  #              0x2a  *         |   |    |   |    |   |   |    |
  #              0x2b  + <-------+   |    |   |    |   |   |    |
  #              0x3b  ; <-----------+    |   |    |   |   |    |
  #              0x3c  <                  |   |    |   |   |    |
  #              0x3d  =                  |   |    |   |   |    |
  #              0x3e  >                  |   |    |   |   |    |
  #              0x3f  ? <----------------+   |    |   |   |    |
  #              0x5b  [ <--------------------+    |   |   |    |
  #              0x5c  \                           |   |   |    |
  #              0x5d  ]                           |   |   |    |
  #              0x5e  ^ <-------------------------+   |   |    |
  #              0x60  ` <-----------------------------+   |    |
  #              0x7b  { <---------------------------------+    |
  #              0x7c  |                                        |
  #              0x7d  }                                        |
  #              0x7e  ~ <--------------------------------------+
  $sData =~ s/ /+/sg;
  return $sData;
}


######################################################################
#
# EadFTimesUrlDecode
#
######################################################################

sub EadFTimesUrlDecode
{
  my ($sData) = @_;
  $sData =~ s/\+/ /sg;
  $sData =~ s/%([0-9a-fA-F]{2})/pack('C', hex($1))/seg;
  return $sData;
}


######################################################################
#
# EadFTimesUrlEncode
#
######################################################################

sub EadFTimesUrlEncode
{
  my ($sData) = @_;
  $sData =~ s/([\x00-\x1f\x7f-\xff|"'`%+#])/sprintf("%%%02x", unpack('C',$1))/seg;
  my $sPathSeparatorRegex = ($^O =~ /MSWin(32|64)/i) ? qr{/} : qr{\\};
  $sData =~ s#($sPathSeparatorRegex)#sprintf("%%%02x", unpack('C',$1))#seg;
  $sData =~ s/ /+/sg;
  return $sData;
}


######################################################################
#
# EadGetDecoders
#
######################################################################

sub EadGetDecoders
{
  return \%ghDecoders;
}


######################################################################
#
# EadHexDecode
#
######################################################################

sub EadHexDecode
{
  my ($sData) = @_;
  $sData =~ s/([0-9a-fA-F]{2})/pack('C', hex($1))/seg;
  return $sData;
}


######################################################################
#
# EadHexDecodeArray
#
######################################################################

sub EadHexDecodeArray
{
  my ($sData) = @_;
  $sData =~ s/0x([0-9a-fA-F]{2})(?:,\s*)?/pack('C', hex($1))/seg;
  return $sData;
}



######################################################################
#
# EadHexDecodeCString
#
######################################################################

sub EadHexDecodeCString
{
  my ($sData) = @_;
  $sData =~ s/\\x([0-9a-fA-F]{2})/pack('C', hex($1))/seg;
  return $sData;
}


######################################################################
#
# EadHexDump
#
######################################################################

sub EadHexDump
{
  my ($sData) = @_;

  my @aLines = ();

  my $phRecords = EadHexDumpRecords($sData);
  if (defined($phRecords))
  {
    foreach my $phRecord (@{$phRecords})
    {
      push(@aLines, join("|", @{$phRecord}));
    }
  }

  return \@aLines;
}


######################################################################
#
# EadHexDumpRecords
#
######################################################################

sub EadHexDumpRecords
{
  my ($sData) = @_;

  my @aBytes = split(//, $sData);
  my @aChars = ();
  my @aHexes = ();
  my @aRecords = ();
  my $sIndex = 0;
  my $sNBytesProcessed = 0;

  for ($sIndex = 0; $sIndex < scalar(@aBytes); $sIndex++)
  {
    my $n = $sIndex % 16;
    my $b = $aBytes[$sIndex];
    my $c = chr(unpack('C', $b));
    if ($sIndex && $n == 0)
    {
      push(@aRecords, [ sprintf("0x%08x", $sIndex - $sNBytesProcessed), join(" ", @aHexes), join("", @aChars) ]);
      @aHexes = ();
      @aChars = ();
      $sNBytesProcessed = 0;
    }
    $aHexes[$n] = sprintf("%02x", unpack('C', $b));
    $aChars[$n] = sprintf("%s", ($c =~ /^[[:print:]]$/o) ? $c : ".");
    $sNBytesProcessed++;
  }
  if ($sNBytesProcessed)
  {
    for (my $i = $sNBytesProcessed; $i < 16; $i++)
    {
      $aHexes[$i] = "  ";
    }
    push(@aRecords, [ sprintf("0x%08x", $sIndex - $sNBytesProcessed), join(" ", @aHexes), join("", @aChars) ]);
  }

  return \@aRecords;
}


######################################################################
#
# EadHexEncode
#
######################################################################

sub EadHexEncode
{
  my ($sData) = @_;
  $sData =~ s/([\x00-\xff])/sprintf("%02x", unpack('C',$1))/seg;
  return $sData;
}


######################################################################
#
# EadHexEncodeArray
#
######################################################################

sub EadHexEncodeArray
{
  my ($sData) = @_;
  $sData =~ s/([\x00-\xff])/sprintf(", 0x%02x", unpack('C',$1))/seg;
  $sData =~ s/^, //;
  return $sData;
}


######################################################################
#
# EadHexEncodeCString
#
######################################################################

sub EadHexEncodeCString
{
  my ($sData) = @_;
  $sData =~ s/([\x00-\xff])/sprintf("\\x%02x", unpack('C',$1))/seg;
  return $sData;
}


######################################################################
#
# EadHexToBase32
#
######################################################################

sub EadHexToBase32
{
  return EadBase32Encode(EadHexDecode(@_));
}


######################################################################
#
# EadHexToBase64
#
######################################################################

sub EadHexToBase64
{
  return EadBase64Encode(EadHexDecode(@_));
}


######################################################################
#
# EadHexToBase64Url
#
######################################################################

sub EadHexToBase64Url
{
  return EadBase64UrlEncode(EadHexDecode(@_));
}


######################################################################
#
# EadHexToHexDump
#
######################################################################

sub EadHexToHexDump
{
  return EadHexDump(EadHexDecode(@_));
}


######################################################################
#
# EadNopDecode
#
######################################################################

sub EadNopDecode
{
  return $_[0];
}


######################################################################
#
# EadNopEncode
#
######################################################################

sub EadNopEncode
{
  return $_[0];
}


######################################################################
#
# EadSafeBookendHexDecode
#
######################################################################

sub EadSafeBookendHexDecode
{
  my ($sData, $sLBookend, $sRBookend) = @_;

  if (!defined($sLBookend) && !defined($sRBookend)) # Conditionally define bookends.
  {
    $sLBookend //= '[';
    $sRBookend //= ']';
  }

  return EadBookendHexDecode($sData, $sLBookend, $sRBookend)
}


######################################################################
#
# EadSafeBookendHexEncode
#
######################################################################

sub EadSafeBookendHexEncode
{
  my ($sData, $sLBookend, $sRBookend) = @_;

  if (!defined($sLBookend) && !defined($sRBookend)) # Conditionally define bookends.
  {
    $sLBookend //= '[';
    $sRBookend //= ']';
  }

  if # Conditionally perform the operation. Otherwise, return data unmodified.
  (
       $sLBookend eq '(' && $sRBookend eq ')'
    || $sLBookend eq '<' && $sRBookend eq '>'
    || $sLBookend eq '[' && $sRBookend eq ']'
    || $sLBookend eq '{' && $sRBookend eq '}'
  )
  {
    $sData =~ s/([\x00-\x09\x0b\x0c\x0e-\x1f\x20\x22\x27\x28\x29\x3c\x3e\x5b\x5d\x7b\x7d\x7f-\xff])/sprintf("%s0x%02x%s", $sLBookend, unpack('C', $1), $sRBookend)/seg;
    #             |________________________|   |   |   |   |   |   |   |   |   |   |   ||_______|
    #                         |                |   |   |   |   |   |   |   |   |   |   |    |
    #  controls    <----------+                |   |   |   |   |   |   |   |   |   |   |    |
    #  enc 0x20    <---------------------------+   |   |   |   |   |   |   |   |   |   |    |
    #  enc 0x22 "  <-------------------------------+   |   |   |   |   |   |   |   |   |    |
    #  enc 0x27 '  <-----------------------------------+   |   |   |   |   |   |   |   |    |
    #  enc 0x28 (  <---------------------------------------+   |   |   |   |   |   |   |    |
    #  enc 0x29 )  <-------------------------------------------+   |   |   |   |   |   |    |
    #  enc 0x3c <  <-----------------------------------------------+   |   |   |   |   |    |
    #  enc 0x3e >  <---------------------------------------------------+   |   |   |   |    |
    #  enc 0x5b [  <-------------------------------------------------------+   |   |   |    |
    #  enc 0x5d ]  <-----------------------------------------------------------+   |   |    |
    #  enc 0x7b {  <---------------------------------------------------------------+   |    |
    #  enc 0x7d }  <-------------------------------------------------------------------+    |
    #  extended    <------------------------------------------------------------------------+
    #
    # Note that any character matched by the character set above
    # will be encoded. Since we want safe encodings, we exclude (over
    # and above the original bookend encoder) space, single/double
    # quotes, all braces, and the delete character (i.e., 0x7f).
    #
    ##################################################################

    $sData =~ s/\x0a/$sLBookend."\\n".$sRBookend/seg;
    $sData =~ s/\x0d/$sLBookend."\\r".$sRBookend/seg;
  }

  return $sData;
}


######################################################################
#
# EadUnixModeDecode
#
######################################################################

sub EadUnixModeDecode
{
  my ($sData) = @_;

  ####################################################################
  #
  # If the mode does not pass muster, return question marks. Since
  # this code assumes 32-bit values, make sure the supplied input is
  # in the octal range [00000-37777777777].
  #
  ####################################################################

  my @aData = ();

  if ($sData !~ /^0?([0-7]{5,10}|[0-3][0-7]{5,10})$/)
  {
    return "??????????";
  }
  my $sMode = oct($sData);
  my $sType = $sMode & 0170000;

  ####################################################################
  #
  # Set standard permissions.
  #
  ####################################################################

  for (my $i = 0; $i < 9; $i++)
  {
    push(@aData, ((($sMode & (1 << $i))) ? $ghUnixPermissions{$i} : "-"));
  }

  ####################################################################
  #
  # Set SUID, SGID, and sticky flags.
  #
  ####################################################################

  if ($sMode & 0001000 && $sType == 0040000)
  {
    $aData[0] = ($aData[0] eq "x") ? "t" : "T";
  }
  if ($sMode & 0002000)
  {
    $aData[3] = ($aData[3] eq "x") ? "s" : "S";
  }
  if ($sMode & 0004000)
  {
    $aData[6] = ($aData[6] eq "x") ? "s" : "S";
  }

  ####################################################################
  #
  # Set file type.
  #
  ####################################################################

  if ($sType == 0010000)
  {
    push(@aData, "p");
  }
  elsif ($sType == 0020000)
  {
    push(@aData, "c");
  }
  elsif ($sType == 0040000)
  {
    push(@aData, "d");
  }
  elsif ($sType == 0060000)
  {
    push(@aData, "b");
  }
  elsif ($sType == 0100000)
  {
    push(@aData, "-");
  }
  elsif ($sType == 0120000)
  {
    push(@aData, "l");
  }
  elsif ($sType == 0140000)
  {
    push(@aData, "s");
  }
  elsif ($sType == 0160000)
  {
    push(@aData, "w");
  }
  else
  {
    push(@aData, "?");
  }

  return join("", reverse(@aData));
}


######################################################################
#
# EadUnixGidDecode
#
######################################################################

sub EadUnixGidDecode
{
  my ($sGid, $sGroupFile) = @_;

  if (defined($sGroupFile))
  {
    if (-f $sGroupFile)
    {
      if (!exists($ghUnixGidMap{$sGroupFile}))
      {
        if (open(FH, "< $sGroupFile"))
        {
          while (my $sLine = <FH>)
          {
            $sLine =~ s/[\r\n]+$//;
            my @aFields = split(/:/, $sLine);
            $ghUnixGidMap{$sGroupFile}{$aFields[2]} = $aFields[0] unless (defined($ghUnixGidMap{$sGroupFile}{$aFields[2]})); # Ignore alternae username mappings.
          }
          close(FH);
        }
      }
      return (defined($ghUnixGidMap{$sGroupFile}{$sGid})) ? $ghUnixGidMap{$sGroupFile}{$sGid} : $sGid;
    }
  }
  else
  {
    if (defined($sGid) && $sGid =~ /^\d+$/o)
    {
      my $sGroup = getgrgid($sGid);
      return (defined($sGroup) && length($sGroup)) ? $sGroup : $sGid;
    }
  }

  return "?";
}


######################################################################
#
# EadUnixUidDecode
#
######################################################################

sub EadUnixUidDecode
{
  my ($sUid, $sPasswordFile) = @_;

  if (defined($sPasswordFile))
  {
    if (-f $sPasswordFile)
    {
      if (!exists($ghUnixUidMap{$sPasswordFile}))
      {
        if (open(FH, "< $sPasswordFile"))
        {
          while (my $sLine = <FH>)
          {
            $sLine =~ s/[\r\n]+$//;
            my @aFields = split(/:/, $sLine);
            $ghUnixUidMap{$sPasswordFile}{$aFields[2]} = $aFields[0] unless (defined($ghUnixUidMap{$sPasswordFile}{$aFields[2]})); # Ignore alternae username mappings.
          }
          close(FH);
        }
      }
      return (defined($ghUnixUidMap{$sPasswordFile}{$sUid})) ? $ghUnixUidMap{$sPasswordFile}{$sUid} : $sUid;
    }
  }
  else
  {
    if (defined($sUid) && $sUid =~ /^\d+$/o)
    {
      my $sUser = getpwuid($sUid);
      return (defined($sUser) && length($sUser)) ? $sUser : $sUid;
    }
  }

  return "?";
}


######################################################################
#
# EadUrlDecode
#
######################################################################

sub EadUrlDecode
{
  my ($sData) = @_;
  $sData =~ s/%([0-9a-fA-F]{2})/pack('C', hex($1))/seg;
  return $sData;
}


######################################################################
#
# EadUrlEncode
#
######################################################################

sub EadUrlEncode
{
  my ($sData) = @_;
  $sData =~ s/([\x00-\xff])/sprintf("%%%02x", unpack('C',$1))/seg;
  return $sData;
}


######################################################################
#
# EadWinxAceDecode
#
######################################################################

sub EadWinxAceDecode
{
  my ($sAce, $sObject, $phAce, $psError) = @_;

  ####################################################################
  #
  # Make sure we support the specified object type.
  #
  ####################################################################

  if ($sObject !~ /^(?:directory|file|generic|pipe)$/)
  {
    $$psError = "Object type ($sObject) must be one of \"directory\", \"file\", \"pipe\", or \"generic\".";
    return undef;
  }

  ####################################################################
  #
  # Validate ACE format, and break it down into its components.
  #
  ####################################################################

  my $sTypeRegex            = "A[UL]?|D|O[ADLU]?";
  my $sFlagsRegex           = "(?:CI|FA|I[DO]|NP|OI|SA)*";
  my $sRightsRegex          = "0x[0-9A-Fa-f]{1,8}|(?:C[CR]|D[CT]|F[ARWX]|G[ARWX]|K[ARWX]|L[CO]|R[CP]|S[DW]|W[DOP]){1,}";
  my $sObjectGuidRegex      = "(?:[0-9A-Fa-f]{8}(?:-[0-9A-Fa-f]{4}){3}-[0-9A-Fa-f]{12})?"; # GUID
  my $sInheritedObjectGuidRegex = "(?:[0-9A-Fa-f]{8}(?:-[0-9A-Fa-f]{4}){3}-[0-9A-Fa-f]{12})?"; # GUID
  my $sTrusteeRegex         = "S-[0-9]{1,3}-[0-9]{1,20}-[0-9]{1,10}(?:-[0-9]{1,10}){0,14}|A[NOU]|B[AGOU]|C[AGO]|D[ACDGU]|E[AD]|IU|L[AGSU]|MU|N[OSU]|P[AOSU]|R[CDESU]|S[AOUY]|WD"; # SID/Alias
  my $sAceRegex = "($sTypeRegex);($sFlagsRegex);($sRightsRegex);($sObjectGuidRegex);($sInheritedObjectGuidRegex);($sTrusteeRegex)";
  if ($sAce !~ /^$sAceRegex$/o)
  {
    $$psError = "Ace ($sAce) does not pass muster.";
    return undef;
  }
  my $sType                 = $1; # Must be defined.
  my $sFlags                = (defined($2)) ? $2 : ""; # Can be NULL.
  my $sRights               = $3; # Must be defined.
  my $sObjectGuid           = (defined($4)) ? $4 : ""; # Can be NULL.
  my $sInheritedObjectGuid  = (defined($5)) ? $5 : ""; # Can be NULL.
  my $sTrustee              = $6; # Must be defined.

  ####################################################################
  #
  # Decode ACE type.
  #
  ####################################################################

  if (!exists($ghWinxAceTypes{$sType}))
  {
    $$psError = "Ace ($sAce) contains an invalid or unknown type ($sType).";
    return undef;
  }
  $$phAce{'Type'} = $ghWinxAceTypes{$sType};

  ####################################################################
  #
  # Decode ACE flags.
  #
  ####################################################################

  @{$$phAce{'Flags'}} = ();
  my $sLength = length($sFlags);
  if ($sLength % 2)
  {
    $$psError = "Ace ($sAce) contains flags ($sFlags), but their length is not a multiple of two.";
    return undef;
  }
  for (my $i = 0; $i < $sLength; $i += 2)
  {
    my $sFlag = substr($sFlags, $i, 2);
    if (!exists($ghWinxAceFlags{$sFlag}))
    {
      $$psError = "Ace ($sAce) contains an invalid or unknown flag ($sFlag).";
      return undef;
    }
    push(@{$$phAce{'Flags'}}, $ghWinxAceFlags{$sFlag});
  }

  ####################################################################
  #
  # Decode access rights.
  #
  #  3 3 2 2 2 2 2 2 2 2 2 2 1 1 1 1 1 1 1 1 1 1
  #  1 0 9 8 7 6 5 4 3 2 1 0 9 8 7 6 5 4 3 2 1 0 9 8 7 6 5 4 3 2 1 0
  # +---------------+---------------+-------------------------------+
  # |G|G|G|G|Res'd|A|   Standard    |           Specific            |
  # |R|W|E|A|     |S|               |                               |
  # +-+-------------+---------------+-------------------------------+
  #
  ####################################################################

  my $sHexRights = 0;
  if ($sRights =~ /^0x[0-9A-Fa-f]{1,8}$/)
  {
    $sHexRights = hex($sRights);
    my $sStartBit = 0;
    if ($sObject =~ /^generic$/)
    {
      $sStartBit = 16;
      push(@{$$phAce{'Rights'}}, sprintf("SPECIFIC_0x%08x", $sHexRights & 0xffff));
    }
    for (my $i = $sStartBit; $i < 32; $i++)
    {
      my $sHexRight = $sHexRights & (1 << $i);
      # BEGIN SPECIFIC RIGHTS
      if ($sHexRight == 0x00000001)
      {
        if ($sObject eq "file")
        {
          push(@{$$phAce{'Rights'}}, "FILE_READ_DATA");
        }
        elsif ($sObject eq "directory")
        {
          push(@{$$phAce{'Rights'}}, "FILE_LIST_DIRECTORY");
        }
        elsif ($sObject eq "pipe")
        {
          push(@{$$phAce{'Rights'}}, "FILE_READ_DATA");
        }
        else
        {
          push(@{$$phAce{'Rights'}}, "SPECIFIC_0x00000001");
        }
      }
      elsif ($sHexRight == 0x00000002)
      {
        if ($sObject eq "file")
        {
          push(@{$$phAce{'Rights'}}, "FILE_WRITE_DATA");
        }
        elsif ($sObject eq "directory")
        {
          push(@{$$phAce{'Rights'}}, "FILE_ADD_FILE");
        }
        elsif ($sObject eq "pipe")
        {
          push(@{$$phAce{'Rights'}}, "FILE_WRITE_DATA");
        }
        else
        {
          push(@{$$phAce{'Rights'}}, "SPECIFIC_0x00000002");
        }
      }
      elsif ($sHexRight == 0x00000004)
      {
        if ($sObject eq "file")
        {
          push(@{$$phAce{'Rights'}}, "FILE_APPEND_DATA");
        }
        elsif ($sObject eq "directory")
        {
          push(@{$$phAce{'Rights'}}, "FILE_ADD_SUBDIRECTORY");
        }
        elsif ($sObject eq "pipe")
        {
          push(@{$$phAce{'Rights'}}, "FILE_CREATE_PIPE_INSTANCE");
        }
        else
        {
          push(@{$$phAce{'Rights'}}, "SPECIFIC_0x00000004");
        }
      }
      elsif ($sHexRight == 0x00000008)
      {
        if ($sObject eq "file")
        {
          push(@{$$phAce{'Rights'}}, "FILE_READ_EA");
        }
        elsif ($sObject eq "directory")
        {
          push(@{$$phAce{'Rights'}}, "FILE_READ_EA");
        }
        else
        {
          push(@{$$phAce{'Rights'}}, "SPECIFIC_0x00000008");
        }
      }
      elsif ($sHexRight == 0x00000010)
      {
        if ($sObject eq "file")
        {
          push(@{$$phAce{'Rights'}}, "FILE_WRITE_EA");
        }
        elsif ($sObject eq "directory")
        {
          push(@{$$phAce{'Rights'}}, "FILE_WRITE_EA");
        }
        else
        {
          push(@{$$phAce{'Rights'}}, "SPECIFIC_0x00000010");
        }
      }
      elsif ($sHexRight == 0x00000020)
      {
        if ($sObject eq "file")
        {
          push(@{$$phAce{'Rights'}}, "FILE_EXECUTE");
        }
        elsif ($sObject eq "directory")
        {
          push(@{$$phAce{'Rights'}}, "FILE_TRAVERSE");
        }
        else
        {
          push(@{$$phAce{'Rights'}}, "SPECIFIC_0x00000020");
        }
      }
      elsif ($sHexRight == 0x00000040)
      {
        if ($sObject eq "directory")
        {
          push(@{$$phAce{'Rights'}}, "FILE_DELETE_CHILD");
        }
        else
        {
          push(@{$$phAce{'Rights'}}, "SPECIFIC_0x00000040");
        }
      }
      elsif ($sHexRight == 0x00000080)
      {
        push(@{$$phAce{'Rights'}}, "FILE_READ_ATTRIBUTES");
      }
      elsif ($sHexRight == 0x00000100)
      {
        push(@{$$phAce{'Rights'}}, "FILE_WRITE_ATTRIBUTES");
      }
      elsif ($sHexRight == 0x00000200)
      {
        push(@{$$phAce{'Rights'}}, "SPECIFIC_0x00000200");
      }
      elsif ($sHexRight == 0x00000400)
      {
        push(@{$$phAce{'Rights'}}, "SPECIFIC_0x00000400");
      }
      elsif ($sHexRight == 0x00000800)
      {
        push(@{$$phAce{'Rights'}}, "SPECIFIC_0x00000800");
      }
      elsif ($sHexRight == 0x00001000)
      {
        push(@{$$phAce{'Rights'}}, "SPECIFIC_0x00001000");
      }
      elsif ($sHexRight == 0x00002000)
      {
        push(@{$$phAce{'Rights'}}, "SPECIFIC_0x00002000");
      }
      elsif ($sHexRight == 0x00004000)
      {
        push(@{$$phAce{'Rights'}}, "SPECIFIC_0x00004000");
      }
      elsif ($sHexRight == 0x00008000)
      {
        push(@{$$phAce{'Rights'}}, "SPECIFIC_0x00008000");
      }
      # END SPECIFIC RIGHTS
      # BEGIN STANDARD RIGHTS
      elsif ($sHexRight == 0x00010000)
      {
        push(@{$$phAce{'Rights'}}, "DELETE");
      }
      elsif ($sHexRight == 0x00020000)
      {
        push(@{$$phAce{'Rights'}}, "READ_CONTROL");
      }
      elsif ($sHexRight == 0x00040000)
      {
        push(@{$$phAce{'Rights'}}, "WRITE_DAC");
      }
      elsif ($sHexRight == 0x00080000)
      {
        push(@{$$phAce{'Rights'}}, "WRITE_OWNER");
      }
      elsif ($sHexRight == 0x00100000)
      {
        push(@{$$phAce{'Rights'}}, "SYNCRONIZE");
      }
      elsif ($sHexRight == 0x00200000) # Based on the value of STANDARD_RIGHTS_ALL (0x001f0000), this bit is not used.
      {
        push(@{$$phAce{'Rights'}}, "STANDARD_0x00200000");
      }
      elsif ($sHexRight == 0x00400000) # Based on the value of STANDARD_RIGHTS_ALL (0x001f0000), this bit is not used.
      {
        push(@{$$phAce{'Rights'}}, "STANDARD_0x00400000");
      }
      elsif ($sHexRight == 0x00800000) # Based on the value of STANDARD_RIGHTS_ALL (0x001f0000), this bit is not used.
      {
        push(@{$$phAce{'Rights'}}, "STANDARD_0x00800000");
      }
      # END STANDARD RIGHTS
      elsif ($sHexRight == 0x01000000)
      {
        push(@{$$phAce{'Rights'}}, "ACCESS_SYSTEM_SECURITY");
      }
      # BEGIN RESERVED RIGHTS
      elsif ($sHexRight == 0x02000000)
      {
        push(@{$$phAce{'Rights'}}, "RESERVED_0x02000000");
      }
      elsif ($sHexRight == 0x04000000)
      {
        push(@{$$phAce{'Rights'}}, "RESERVED_0x04000000");
      }
      elsif ($sHexRight == 0x08000000)
      {
        push(@{$$phAce{'Rights'}}, "RESERVED_0x08000000");
      }
      # END RESERVED RIGHTS
      # BEGIN GENERIC RIGHTS
      elsif ($sHexRight == 0x10000000)
      {
        push(@{$$phAce{'Rights'}}, "GENERIC_ALL");
      }
      elsif ($sHexRight == 0x20000000)
      {
        push(@{$$phAce{'Rights'}}, "GENERIC_EXECUTE");
      }
      elsif ($sHexRight == 0x40000000)
      {
        push(@{$$phAce{'Rights'}}, "GENERIC_WRITE");
      }
      elsif ($sHexRight == 0x80000000)
      {
        push(@{$$phAce{'Rights'}}, "GENERIC_READ");
      }
      # END GENERIC RIGHTS
    }
  }
  else
  {
    $sLength = length($sRights);
    for (my $i = 0; $i < $sLength; $i += 2)
    {
      my $sRight = substr($sRights, $i, 2);
      if (!exists($ghWinxAceRights{$sRight}))
      {
        $$psError = "Ace ($sAce) contains an invalid or unknown right ($sRight).";
        return undef;
      }
      push(@{$$phAce{'Rights'}}, $ghWinxAceRights{$sRight});
      $sHexRights |= $ghWinxAceHexRights{$sRight};
    }
  }
  $$phAce{'HexRights'} = sprintf("0x%08x", $sHexRights);

  ####################################################################
  #
  # Carry object GUID over to the ACE hash.
  #
  ####################################################################

  $$phAce{'ObjectGuid'} = $sObjectGuid;

  ####################################################################
  #
  # Carry inherited object GUID over to the ACE hash.
  #
  ####################################################################

  $$phAce{'InheritedObjectGuid'} = $sInheritedObjectGuid;

  ####################################################################
  #
  # Decode the trustee or carry it over to the ACE hash.
  #
  ####################################################################

  if (exists($ghWinxAceTrustees{$sTrustee}))
  {
    $$phAce{'Trustee'} = $ghWinxAceTrustees{$sTrustee};
  }
  else
  {
    $$phAce{'Trustee'} = $sTrustee;
  }

  1;
}


######################################################################
#
# EadWinxAttributesDecode
#
######################################################################

sub EadWinxAttributesDecode
{
  my ($sData) = @_;

  my @aData = ();
  if (defined($sData) && $sData =~ /^\d+$/)
  {
    for (my $sShift = 0; $sShift < 18; $sShift++)
    {
      my $sAttribute = 1 << $sShift;
      next if ($sAttribute == 0x00000008);
      push(@aData, $ghWinxAttributes{$sAttribute}) if ($sData & $sAttribute);
    }
  }

  return join(",", reverse(@aData));
}


######################################################################
#
# EadWinxDaclDecode
#
######################################################################

sub EadWinxDaclDecode
{
  my ($sDacl, $sObject, $phDacl, $psError) = @_;

  ####################################################################
  #
  # Make sure we support the specified object type.
  #
  ####################################################################

  if ($sObject !~ /^(?:directory|file|generic|pipe)$/)
  {
    $$psError = "Object type ($sObject) must be one of \"directory\", \"file\", \"pipe\", or \"generic\".";
    return undef;
  }
  $$phDacl{'Object'} = $sObject;

  ####################################################################
  #
  # Validate DACL format. Note that the ACE list is only partially
  # validated -- stricter checks will be applied later.
  #
  ####################################################################

  if ($sDacl !~ /^D:((?:P|AR|AI)*)((?:[(][0-9A-Za-z;-]+[)])*)$/)
  {
    $$psError = "Dacl ($sDacl) does not pass muster.";
    return undef;
  }
  my $sFlags = $1;
  my $sAces  = $2;

  ####################################################################
  #
  # Decode control flags. According to the man page, these flags can
  # be a concatenation of zero or more of the following: 'P', 'AI',
  # and 'AR'.
  #
  ####################################################################

  if ($sFlags =~ /P/o)
  {
    push(@{$$phDacl{'Flags'}}, "PROTECTED");
  }
  if ($sFlags =~ /AI/o)
  {
    push(@{$$phDacl{'Flags'}}, "AUTO_INHERITED");
  }
  if ($sFlags =~ /AR/o)
  {
    push(@{$$phDacl{'Flags'}}, "AUTO_INHERIT_REQ");
  }

  ####################################################################
  #
  # Remove the leading/trailing parentheses, split the ACE list using
  # ')(' as the delimiter, and decode each ACE. Fill the DACL hash as
  # we go.
  #
  ####################################################################

  $sAces =~ s/^[(]//;
  $sAces =~ s/[)]$//;
  foreach my $sAce (split(/[)][(]/, $sAces))
  {
    my %hAce = ();
    if (!EadWinxAceDecode($sAce, $sObject, \%hAce, $psError))
    {
      return undef;
    }
    %{$$phDacl{'Aces'}{$sAce}} = %hAce;
  }

  1;
}


######################################################################
#
# EadWrapInQuotes
#
######################################################################

sub EadWrapInQuotes
{
  my ($sData, $sQChar, $sEChar) = @_;

  if (!defined($sQChar) || length($sQChar) != 1)
  {
    $sQChar = chr(0x22); # This is '"'.
  }
  if (!defined($sEChar) || length($sEChar) != 1)
  {
    $sEChar = chr(0x5c); # This is '\'.
  }
  my $sEExpr = ($sEChar eq '\\') ? qr([\\]) : qr([$sEChar]);
  my $sQExpr = ($sQChar eq '\\') ? qr([\\]) : qr([$sQChar]);
  $sData .= "";
  $sData =~ s/$sEExpr/$sEChar.$sEChar/seg;
  $sData =~ s/$sQExpr/$sEChar.$sQChar/seg;

  return $sQChar . $sData . $sQChar;
}


######################################################################
#
# EadXformViaAnd
#
######################################################################

sub EadXformViaAnd
{
  my ($sData, $sKey) = @_;

  my @aKeyBytes = split(//, (defined($sKey) && length($sKey) > 0) ? $sKey : "\xff");
  my $sKeyCount = scalar(@aKeyBytes);
  my @aDataBytes = split(//, defined($sData) ? $sData : "");
  my $sDataCount = scalar(@aDataBytes);
  my @aAndBytes = ();
  for (my $sIndex = 0; $sIndex < $sDataCount; $sIndex++)
  {
    my $sAndByte = $aDataBytes[$sIndex] & $aKeyBytes[$sIndex % $sKeyCount];
    push(@aAndBytes, $sAndByte);
  }

  return join("", @aAndBytes);
}


######################################################################
#
# EadXformViaNop
#
######################################################################

sub EadXformViaNop
{
  return $_[0];
}


######################################################################
#
# EadXformViaNot
#
######################################################################

sub EadXformViaNot
{
  my ($sData) = @_;

  my @aDataBytes = split(//, defined($sData) ? $sData : "");
  my $sDataCount = scalar(@aDataBytes);
  my @aNotBytes = ();
  for (my $sIndex = 0; $sIndex < $sDataCount; $sIndex++)
  {
    push(@aNotBytes, ~$aDataBytes[$sIndex]);
  }

  return join("", @aNotBytes);
}


######################################################################
#
# EadXformViaRot13
#
######################################################################

sub EadXformViaRot13
{
  my ($sData) = @_;
  $sData =~ tr/A-Za-z/N-ZA-Mn-za-m/;
  return $sData;
}


######################################################################
#
# EadXformViaRot47
#
######################################################################

sub EadXformViaRot47
{
  my ($sData) = @_;
  $sData =~ tr/!-~/P-~!-O/;
  return $sData;
}


######################################################################
#
# EadXformViaXor
#
######################################################################

sub EadXformViaXor
{
  my ($sData, $sKey, $sPadding) = @_;

  my @aKeyBytes = split(//, (defined($sKey) && length($sKey) > 0) ? $sKey : "\x00");
  my $sKeyCount = scalar(@aKeyBytes);
  my $sRemainder = length($sData) % $sKeyCount;
  if ($sRemainder && defined($sPadding))
  {
    my @aPadBytes = split(//, $sPadding);
    my $sPadCount = scalar(@aPadBytes);
    for (my $sIndex = 0; $sIndex < $sKeyCount - $sRemainder; $sIndex++)
    {
      $sData .= $aPadBytes[$sIndex % $sPadCount];
    }
  }
  my @aDataBytes = split(//, defined($sData) ? $sData : "");
  my $sDataCount = scalar(@aDataBytes);
  my @aXorBytes = ();
  for (my $sIndex = 0; $sIndex < $sDataCount; $sIndex++)
  {
    my $sXorByte = $aDataBytes[$sIndex] ^ $aKeyBytes[$sIndex % $sKeyCount];
    push(@aXorBytes, $sXorByte);
  }

  return join("", @aXorBytes);
}

1;

__END__

=pod

=head1 NAME

FTimes::EadRoutines - Home for various encoder and decoder routines

=head1 SYNOPSIS

    use FTimes::EadRoutines;

=head1 DESCRIPTION

This module is a collection of various encoder and decoder routines
designed to support various FTimes utilities.  As such, minimal effort
was put into supporting this code for general consumption.  In other
words, use at your own risk and don't expect the interface to remain
the same or backwards compatible from release to release.  This module
does not provide an OO interface, nor will it do so anytime soon.

=head1 AUTHOR

Klayton Monroe

=head1 LICENSE

All documentation and code are distributed under same terms and
conditions as B<FTimes>.

=cut
