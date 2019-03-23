unit utils;

interface

uses windows,sysutils;

const
  FILE_READ_ATTRIBUTES = $80;
  FSCTL_GET_RETRIEVAL_POINTERS = 589939; //(($00000009) shr 16) or ((28) shr 14) or ((3) shr 2) or (0);
  IOCTL_VOLUME_LOGICAL_TO_PHYSICAL = $00560020;

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

function GetFileClusters(lpFileName: PChar; ClusterSize: Int64; ClCount: PInt64; var FileSize: Int64;var extents_:TExtents_): TClusters;  
function TranslateLogicalToPhysical(filename:string;LogicalOffset_:LONGLONG):int64;

implementation

function TranslateLogicalToPhysical(filename:string;LogicalOffset_:LONGLONG):int64;
var
logicalOffset:VOLUME_LOGICAL_OFFSET;
physicalOffsets:VOLUME_PHYSICAL_OFFSETS;
bytesReturned:dword;
volumeHandle:thandle;
begin

		logicalOffset.LogicalOffset := LogicalOffset_; //inLcn.QuadPart * clusterSizeInBytes;

    volumeHandle:=thandle(-1);
    volumeHandle := CreateFile(
		pchar('\\.\'+copy(filename,1,2)),
		GENERIC_READ or GENERIC_WRITE,
		FILE_SHARE_READ or FILE_SHARE_WRITE,
		nil,
		OPEN_EXISTING,
		FILE_ATTRIBUTE_NORMAL,
		0);

    if volumeHandle=thandle(-1) then exit;

		if DeviceIoControl(
			volumeHandle,
			IOCTL_VOLUME_LOGICAL_TO_PHYSICAL,
			@logicalOffset,
			sizeof(VOLUME_LOGICAL_OFFSET),
			@physicalOffsets,
			sizeof(VOLUME_PHYSICAL_OFFSETS),
			bytesReturned,
			nil) then
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

function GetFileClusters(lpFileName: PChar; ClusterSize: Int64; ClCount: PInt64; var FileSize: Int64;var extents_:TExtents_): TClusters;
var
  hFile: THandle;
  OutSize: ULONG;
  Bytes, Cls, CnCount, r,sectors: ULONG;
  Clusters: TClusters;
  PrevVCN, lcn: LARGE_INTEGER;
  InBuf: STARTING_VCN_INPUT_BUFFER;
  OutBuf: PRETRIEVAL_POINTERS_BUFFER;
begin
  Clusters := nil;

  hFile := CreateFile(lpFileName, generic_read,
    FILE_SHARE_READ ,
    nil, OPEN_EXISTING, FILE_FLAG_NO_BUFFERING, 0);

    if( hFile = INVALID_HANDLE_VALUE ) then
    // try again wit other flags
    hFile := CreateFile(lpFileName,
        FILE_READ_ATTRIBUTES,
        FILE_SHARE_READ,
        nil, OPEN_EXISTING,
        FILE_FLAG_NO_BUFFERING, 0);


    if( hFile = INVALID_HANDLE_VALUE ) then
    // try again as directory
    hFile := CreateFile(lpFileName,
            GENERIC_READ,
            FILE_SHARE_READ,
            nil, OPEN_EXISTING,
            FILE_FLAG_BACKUP_SEMANTICS, 0);

  if (hFile <> INVALID_HANDLE_VALUE) then
  begin
    FileSize := GetFileSize(hFile, nil);

    OutSize := SizeOf(RETRIEVAL_POINTERS_BUFFER) + (FileSize div ClusterSize) * SizeOf(OutBuf^.Extents);

    GetMem(OutBuf, OutSize);

    InBuf.StartingVcn.QuadPart := 0;

    if (DeviceIoControl(hFile, FSCTL_GET_RETRIEVAL_POINTERS, @InBuf,
      SizeOf(InBuf), OutBuf, OutSize, Bytes, nil)) then
    begin
      ClCount^ := (FileSize + ClusterSize - 1) div ClusterSize;

      SetLength(Clusters, ClCount^);
      SetLength(Extents_, OutBuf^.ExtentCount);

      PrevVCN := OutBuf^.StartingVcn;
      //dolog('ExtentCount:'+inttostr(OutBuf^.ExtentCount));
      //dolog('StartingVcn:'+inttohex(OutBuf^.StartingVcn.QuadPart ,8));
      Cls := 0;
      r := 0;
      extents_ [r].NextVcn.quadpart :=0;
      while (r < OutBuf^.ExtentCount) do
      begin
        Lcn := OutBuf^.Extents[r].Lcn;
        CnCount := ULONG(OutBuf^.Extents[r].NextVcn.QuadPart - PrevVCN.QuadPart);

        sectors:=0;
        while (CnCount > 0) do
        begin
          if extents_ [r].LCN.QuadPart =0 then extents_ [r].LCN:=Lcn;
          Clusters[Cls] := Lcn.QuadPart;
          Dec(CnCount);
          Inc(Cls);inc(sectors);
          Inc(Lcn.QuadPart);
        end;

        extents_ [r].sectors :=sectors*ClusterSize div 512;

        //if r<OutBuf^.ExtentCount -1 then
        begin
        //dolog('NextVcn:'+inttohex(OutBuf^.Extents[r].NextVcn.lowpart  ,4)+inttohex(OutBuf^.Extents[r].NextVcn.highpart  ,4));
        extents_ [r+1].NextVcn :=OutBuf^.Extents[r].NextVcn;
        end;

        PrevVCN := OutBuf^.Extents[r].NextVcn;

        Inc(r);
      end;
    end;
    FreeMem(OutBuf);
    CloseHandle(hFile);
  end else raise exception.Create('invalid handle, '+inttostr(getlasterror));
  Result := Clusters;
end;

end.
