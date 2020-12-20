unit utils;

interface

uses windows,sysutils;

const
  FILE_READ_ATTRIBUTES = $80;
  FSCTL_GET_RETRIEVAL_POINTERS = 589939; //(($00000009) shr 16) or ((28) shr 14) or ((3) shr 2) or (0);
  IOCTL_VOLUME_LOGICAL_TO_PHYSICAL = $00560020;
  IOCTL_VOLUME_PHYSICAL_TO_LOGICAL = $00560024;
  IOCTL_STORAGE_GET_DEVICE_NUMBER =  $002D1080;

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

function GetFileClusters(lpFileName: string; ClusterSize: Int64;BtPerSec:dword; ClCount: PInt64; var FileSize: Int64;var extents_:TExtents_): TClusters;
function TranslateLogicalToPhysical(filename:string;LogicalOffset_:LONGLONG):int64;
function TranslatePhysicalToLogical(filename:string;PhysicalOffset_:LONGLONG):int64;

implementation

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
  Bytes, Cls, CnCount, r,sectors: ULONG;
  Clusters: TClusters;
  lcn: LARGE_INTEGER;
  InBuf: STARTING_VCN_INPUT_BUFFER;
  OutBuf: PRETRIEVAL_POINTERS_BUFFER;
  x,errcode :longint;
begin
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

    //lets get the extents
    repeat
    DeviceIoControl(hFile, FSCTL_GET_RETRIEVAL_POINTERS, @InBuf, SizeOf(InBuf), OutBuf, sizeof(RETRIEVAL_POINTERS_BUFFER), Bytes, nil);
    errcode := GetLastError;
              x := 0;
              while x < OutBuf^.ExtentCount do
                begin
                  //inc(total);
                  inc(x);
                  setlength(extents_ ,length(extents_ )+1);
                  extents_ [high(extents_ )].StartingVcn:=OutBuf^.StartingVcn ;
                  extents_ [high(extents_ )].NextVcn :=OutBuf^.Extents[X-1].NextVCN;
                  extents_ [high(extents_ )].LCN :=OutBuf^.Extents[X-1].LCN;
                end;
    InBuf.StartingVCN.QuadPart := OutBuf^.Extents[X-1].NextVCN.QuadPart;
    until errcode <> ERROR_MORE_DATA;

    FreeMem(OutBuf);
    CloseHandle(hFile);

    ClCount^ := (FileSize + ClusterSize - 1) div ClusterSize;
    SetLength(Clusters, ClCount^);
      //dolog('ExtentCount:'+inttostr(OutBuf^.ExtentCount));
      //dolog('StartingVcn:'+inttohex(OutBuf^.StartingVcn.QuadPart ,8));
      Cls := 0;
      r := 0;
      //lets go thru extents
      while (r < length(extents_ )) do
      begin
        //This value minus either StartingVcn (for the first Extents array member)
        //or the NextVcn of the previous member of the array (for all other Extents array members)
        //is the length, in clusters, of the current extent
        CnCount := ULONG(Extents_[r].NextVcn.QuadPart - Extents_[r].StartingVcn.QuadPart  );

        Lcn.QuadPart:=extents_ [r].lcn.QuadPart;
        sectors:=0;
        //lets populate clusters
        while (CnCount > 0) do
        begin

          Clusters[Cls] := lcn.QuadPart;
          Dec(CnCount);
          Inc(Cls);inc(sectors);
          Inc(Lcn.QuadPart);
        end;//while
        Extents_[r].sectors :=sectors*ClusterSize div BtPerSec;
        Inc(r);
      end;//while

  end else raise exception.Create('invalid handle, '+inttostr(getlasterror));
  Result := Clusters;
end;

end.
