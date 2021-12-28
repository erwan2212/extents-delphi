unit utils;

interface

uses windows,sysutils;

const
  FILE_READ_ATTRIBUTES = $80;
  FSCTL_GET_RETRIEVAL_POINTERS = 589939; //(($00000009) shr 16) or ((28) shr 14) or ((3) shr 2) or (0);
  IOCTL_VOLUME_LOGICAL_TO_PHYSICAL = $00560020;
  IOCTL_VOLUME_PHYSICAL_TO_LOGICAL = $00560024;
  IOCTL_STORAGE_GET_DEVICE_NUMBER =  $002D1080;
  IOCTL_DISK_GET_PARTITION_INFO_EX = $0070048;
  NT_STATUS_SUCCESS =0;

  {$ifndef fpc}
  type
  PPARTITION_INFORMATION_GPT = ^PARTITION_INFORMATION_GPT;
  {$EXTERNALSYM PPARTITION_INFORMATION_GPT}
  _PARTITION_INFORMATION_GPT = record
    PartitionType: tGUID; // Partition type. See table 16-3.
    PartitionId: tGUID; // Unique GUID for this partition.
    Attributes: int64; // See table 16-4.
    Name: array [0..35] of WCHAR; // Partition Name in Unicode.
  end;
  {$EXTERNALSYM _PARTITION_INFORMATION_GPT}
  PARTITION_INFORMATION_GPT = _PARTITION_INFORMATION_GPT;
  {$EXTERNALSYM PARTITION_INFORMATION_GPT}
  TPartitionInformationGpt = PARTITION_INFORMATION_GPT;
  PPartitionInformationGpt = PPARTITION_INFORMATION_GPT;
  
  PPARTITION_INFORMATION_MBR = ^PARTITION_INFORMATION_MBR;
  {$EXTERNALSYM PPARTITION_INFORMATION_MBR}
  _PARTITION_INFORMATION_MBR = record
    PartitionType: BYTE;
    BootIndicator: BOOLEAN;
    RecognizedPartition: BOOLEAN;
    HiddenSectors: DWORD;
  end;
  {$EXTERNALSYM _PARTITION_INFORMATION_MBR}
  PARTITION_INFORMATION_MBR = _PARTITION_INFORMATION_MBR;
  {$EXTERNALSYM PARTITION_INFORMATION_MBR}
  TPartitionInformationMbr = PARTITION_INFORMATION_MBR;
  PPartitionInformationMbr = PPARTITION_INFORMATION_MBR;
  
    _PARTITION_STYLE = (
    PARTITION_STYLE_MBR,
    PARTITION_STYLE_GPT,
    PARTITION_STYLE_RAW);
  {$EXTERNALSYM _PARTITION_STYLE}
  PARTITION_STYLE = _PARTITION_STYLE;
  {$EXTERNALSYM PARTITION_STYLE}
  TPartitionStyle = PARTITION_STYLE;

    PPARTITION_INFORMATION_EX = ^PARTITION_INFORMATION_EX;
  {$EXTERNALSYM PPARTITION_INFORMATION_EX}
  _PARTITION_INFORMATION_EX = record
    PartitionStyle: PARTITION_STYLE;
    StartingOffset: LARGE_INTEGER;
    PartitionLength: LARGE_INTEGER;
    PartitionNumber: DWORD;
    RewritePartition: BOOLEAN;
    case Integer of
      0: (Mbr: PARTITION_INFORMATION_MBR);
      1: (Gpt: PARTITION_INFORMATION_GPT);
  end;
  {$EXTERNALSYM _PARTITION_INFORMATION_EX}
  PARTITION_INFORMATION_EX = _PARTITION_INFORMATION_EX;
  {$EXTERNALSYM PARTITION_INFORMATION_EX}
  TPartitionInformationEx = PARTITION_INFORMATION_EX;
  PPartitionInformationEx = PPARTITION_INFORMATION_EX;
  {$endif}

type
  ULONGLONG = ULONG;
  PULONGLONG = ^ULONGLONG;
  TClusters = array of LONGLONG;



  VOLUME_LOGICAL_OFFSET =record
   LogicalOffset:LONGLONG;
end;
 PVOLUME_LOGICAL_OFFSET=^VOLUME_LOGICAL_OFFSET;

 VOLUME_PHYSICAL_OFFSET =record
      DiskNumber:ULONG;
   Offset:LONGLONG;
end;
PVOLUME_PHYSICAL_OFFSET=^VOLUME_PHYSICAL_OFFSET;

 VOLUME_PHYSICAL_OFFSETS =record
   NumberOfPhysicalOffsets:ULONG;
   PhysicalOffset:array [0..0] of VOLUME_PHYSICAL_OFFSET;
end;
PVOLUME_PHYSICAL_OFFSETS=VOLUME_PHYSICAL_OFFSETS;

  STARTING_VCN_INPUT_BUFFER = record
    StartingVcn: LARGE_INTEGER;
  end;
  PSTARTING_VCN_INPUT_BUFFER = ^STARTING_VCN_INPUT_BUFFER;

  Extent = record
    NextVcn: LARGE_INTEGER;
    Lcn: LARGE_INTEGER;
  end;

  TExtent_ = record
    StartingVcn: LARGE_INTEGER;
    NextVcn: LARGE_INTEGER;
    LCN:LARGE_INTEGER;
    sectors:ULONG;
  end;
  TExtents_=array of TExtent_;

  RETRIEVAL_POINTERS_BUFFER = record
    ExtentCount: DWORD;
    StartingVcn: LARGE_INTEGER;
    Extents: array[0..0] of Extent;
  end;
  PRETRIEVAL_POINTERS_BUFFER = ^RETRIEVAL_POINTERS_BUFFER;
  RETRIEVAL_POINTERS_BUFFERS=array of RETRIEVAL_POINTERS_BUFFER;

type
  _STORAGE_DEVICE_NUMBER = record
    DeviceType: DWORD; //DEVICE_TYPE;
    //
    // The number of this device
    //
    DeviceNumber: DWORD;
    //
    // If the device is partitionable, the partition number of the device.
    // Otherwise -1
    //
    PartitionNumber: DWORD;
  end;

  TBOOT_SEQUENCE = packed record
     _jmpcode : array[1..3] of Byte; //0
        cOEMID: array[1..8] of ansiChar; //3
        //BPB = bios parameter block (25 bytes)
        wBytesPerSector: Word;       //11
        bSectorsPerCluster: Byte;    //13
        wSectorsReservedAtBegin: Word;  //14   reserved sectors
      	NumberOfFATs:byte;     //16            numbers of fats
       	RootEntries:word;     //17
       	NumberOfSectors:word; //19
        bMediaDescriptor: Byte; //21
        SectorsPerFAT: Word;  //22
        wSectorsPerTrack: Word;      //24  as in chS
        wHeads: Word;                //26  as in cHs
        HiddenSectors: DWord; //28  sectors before
        BigNumberOfSectors: DWord;//32
        //end of BPB / start of extended BPB (48 bytes)
        BigSectorsPerFAT: DWord;//36          sectors per fat
        TotalSectors: Int64; //40
        MftStartLcn: Int64; //48 Logical Cluster Number
        Mft2StartLcn: Int64;//56
        ClustersPerFileRecord: DWord; //64
        ClustersPerIndexBlock: DWord; //68
        VolumeSerialNumber: Int64;    //72
        checksum:dword; //80
        //end of extended BPB
        _loadercode: array[1..426] of Byte; //426
        wSignature: Word;                   //2
   end;


function GetFileClusters(lpFileName: string; ClusterSize: Int64;BtPerSec:dword; ClCount: PInt64; var FileSize: Int64;var extents_:TExtents_): TClusters;
function TranslateLogicalToPhysical(filename:string;LogicalOffset_:LONGLONG):int64;
function TranslatePhysicalToLogical(filename:string;PhysicalOffset_:LONGLONG):int64;
Function GetPartitionInfo(hfile:thandle;var info:PARTITION_INFORMATION_EX):boolean ;

implementation


Function GetPartitionInfo(hfile:thandle;var info:PARTITION_INFORMATION_EX):boolean ;
var
dwread:dword;
begin
result:=false;
dwread:=0;
if DeviceIoControl(hFile, IOCTL_DISK_GET_PARTITION_INFO_EX, nil, 0, @info, sizeof(PARTITION_INFORMATION_EX), dwread,nil)=true
  then result:=true   ;
end;

function TranslatePhysicalToLogical(filename:string;PhysicalOffset_:LONGLONG):int64;
var
physicalOffset:VOLUME_PHYSICAL_OFFSET;
logicalOffset:VOLUME_LOGICAL_OFFSET;
bytesReturned:dword;
volumeHandle:thandle;
sdn:_STORAGE_DEVICE_NUMBER;
begin

    volumeHandle:=thandle(-1);
    volumeHandle := CreateFile(pchar('\\.\'+copy(filename,1,2)), 0 {GENERIC_READ or GENERIC_WRITE},
  	                                FILE_SHARE_READ or FILE_SHARE_WRITE, nil,	OPEN_EXISTING,
                                    FILE_ATTRIBUTE_NORMAL, 0);

    if volumeHandle=thandle(-1) then exit;

   //
  if DeviceIoControl(volumeHandle,IOCTL_STORAGE_GET_DEVICE_NUMBER,nil, 0, @sdn, sizeof(sdn),bytesReturned, nil)=true
     then physicalOffset.DiskNumber:=sdn.DeviceNumber
     else exit;
  //
   physicalOffset.Offset   := PhysicalOffset_; //inLcn.QuadPart * clusterSizeInBytes;


		if DeviceIoControl(volumeHandle, IOCTL_VOLUME_PHYSICAL_TO_LOGICAL, @physicalOffset,
                       sizeof(VOLUME_PHYSICAL_OFFSET), @logicalOffset, sizeof(logicalOffset),
                       bytesReturned,	nil) then
    begin
    result:=logicalOffset.LogicalOffset;
    //div 512 (BytesPerSector) = lba
    end
    else
		begin
  	result:=0;
		end;
 CloseHandle(volumeHandle);
end;

//offset is in sector
function TranslateLogicalToPhysical(filename:string;LogicalOffset_:LONGLONG):int64;
var
logicalOffset:VOLUME_LOGICAL_OFFSET;
physicalOffsets:VOLUME_PHYSICAL_OFFSETS;
bytesReturned:dword;
volumeHandle:thandle;
begin

   logicalOffset.LogicalOffset := LogicalOffset_; //inLcn.QuadPart * clusterSizeInBytes;

    volumeHandle:=thandle(-1);
    volumeHandle :=
    CreateFile(pchar('\\.\'+copy(filename,1,2)),0 {GENERIC_READ or GENERIC_WRITE},
               FILE_SHARE_READ or FILE_SHARE_WRITE, nil, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, 0);

    if volumeHandle=thandle(-1) then exit;

		if DeviceIoControl(volumeHandle, IOCTL_VOLUME_LOGICAL_TO_PHYSICAL, @logicalOffset,
                      sizeof(VOLUME_LOGICAL_OFFSET), @physicalOffsets, sizeof(VOLUME_PHYSICAL_OFFSETS),
                      bytesReturned, nil) then
    begin
    result:=physicalOffsets.PhysicalOffset[0].Offset  ;
    //div 512 (BytesPerSector) = lba
    end
    else
		begin
  	result:=0;
		end;
 CloseHandle(volumeHandle);
end;

//A cluster is a group of disk sectors that are allocated as a unit
//An extent means a contiguous range of clusters somewhere on the disk,
//described by a starting cluster number and a length (how many clusters after the starting one)

function GetFileClusters(lpFileName: string; ClusterSize: Int64;BtPerSec:dword; ClCount: PInt64; var FileSize: Int64;var extents_:textents_ ): TClusters;
var
  hFile: THandle;
  Bytes, sectors: ULONG;
  Cls, CnCount, r:int64;
  Clusters: TClusters;
  lcn: LARGE_INTEGER;
  InBuf: STARTING_VCN_INPUT_BUFFER;
  OutBuf: PRETRIEVAL_POINTERS_BUFFER;
  x,errcode :longint;
  ret:boolean;
begin
 //writeln('ok1');
  hFile := CreateFile(pchar(lpFileName), generic_read, FILE_SHARE_READ, nil, OPEN_EXISTING, FILE_FLAG_NO_BUFFERING, 0);

  // try again wit other flags
  if( hFile = INVALID_HANDLE_VALUE )
  then hFile := CreateFile(pchar(lpFileName), FILE_READ_ATTRIBUTES, FILE_SHARE_READ, nil, OPEN_EXISTING, FILE_FLAG_NO_BUFFERING, 0);

  // try again as directory
  if( hFile = INVALID_HANDLE_VALUE )
  then hFile := CreateFile(pchar(lpFileName), GENERIC_READ, FILE_SHARE_READ, nil, OPEN_EXISTING, FILE_FLAG_BACKUP_SEMANTICS, 0);

  if (hFile <> INVALID_HANDLE_VALUE) then
  begin
    //FileSize := GetFileSize(hFile, nil);

    Int64Rec(FileSize).Lo := GetFileSize(hFile, @Int64Rec(FileSize).Hi);

    outbuf:=AllocMem(sizeof(RETRIEVAL_POINTERS_BUFFER));

    bytes:=0;

    InBuf.StartingVcn.QuadPart := 0;
    //writeln('ok2');
    //lets get the extents
    repeat
    ret:=DeviceIoControl(hFile, FSCTL_GET_RETRIEVAL_POINTERS, @InBuf, SizeOf(InBuf), OutBuf, sizeof(RETRIEVAL_POINTERS_BUFFER), Bytes, nil);
    errcode := GetLastError;
    //writeln('DeviceIoControl:'+booltostr(ret));
    //writeln('errcode:'+inttostr(errcode));
    //writeln('OutBuf^.ExtentCount:'+inttostr(OutBuf^.ExtentCount));
    if (ERROR<>nt_status_success) or (errcode<>ERROR_MORE_DATA) then break ;
              x := 0;
              while x < OutBuf^.ExtentCount do
                begin
                  //inc(total);
                  inc(x);
                  //writeln('ok3:'+inttostr(x));
                  setlength(extents_ ,length(extents_ )+1);
                  extents_ [high(extents_ )].StartingVcn:=OutBuf^.StartingVcn ;
                  extents_ [high(extents_ )].NextVcn :=OutBuf^.Extents[X-1].NextVCN;
                  extents_ [high(extents_ )].LCN :=OutBuf^.Extents[X-1].LCN;
                  //writeln('LCN:'+inttostr(extents_ [high(extents_ )].LCN.QuadPart ));
                end;
    InBuf.StartingVCN.QuadPart := OutBuf^.Extents[X-1].NextVCN.QuadPart;
    until errcode <> ERROR_MORE_DATA;
    //writeln('length(extents_ ):'+inttostr(length(extents_ )));
    //readln;
    //writeln('ok4');
    FreeMem(OutBuf);
    CloseHandle(hFile);
    //writeln('ok41');
    ClCount^ := (FileSize + ClusterSize - 1) div ClusterSize;
    //writeln('clcount:'+inttostr(ClCount^));
    SetLength(Clusters, ClCount^);
      //dolog('ExtentCount:'+inttostr(OutBuf^.ExtentCount));
      //dolog('StartingVcn:'+inttohex(OutBuf^.StartingVcn.QuadPart ,8));
      Cls := 0;
      r := 0;
      //lets go thru extents
      //writeln('ok5');
      while (r < length(extents_ )) do
      begin
        //writeln('ok6:'+inttostr(r));
        //This value minus either StartingVcn (for the first Extents array member)
        //or the NextVcn of the previous member of the array (for all other Extents array members)
        //is the length, in clusters, of the current extent
        CnCount := ULONG(Extents_[r].NextVcn.QuadPart - Extents_[r].StartingVcn.QuadPart  );
        //writeln('CnCount:'+inttostr(CnCount));
        //readln;
        Lcn.QuadPart:=extents_ [r].lcn.QuadPart;
        sectors:=0;
        //lets populate clusters
        while (CnCount > 0) do
        begin
          //writeln('ok6.1:'+inttostr(cls));
          Clusters[Cls] := lcn.QuadPart;
          Dec(CnCount);
          Inc(Cls);
          inc(sectors);
          Inc(Lcn.QuadPart);
        end;//while
        //writeln('ok7');
        Extents_[r].sectors :=sectors*ClusterSize div BtPerSec;
        Inc(r);

      end;//while
  //writeln('ok99');
  end else raise exception.Create('invalid handle, '+inttostr(getlasterror));
  Result := Clusters;
end;

end.
