unit ufrmExtents;

interface

uses
  Windows, Messages, SysUtils,  Classes,  Controls, Forms,
    ComCtrls, JvDialogs, StdCtrls, Dialogs,math;

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
    sectors:ULONG;
  end;
  TExtents_=array of TExtent_;

  RETRIEVAL_POINTERS_BUFFER = record
    ExtentCount: DWORD;
    StartingVcn: LARGE_INTEGER;
    Extents: array[0..0] of Extent;
  end;
  PRETRIEVAL_POINTERS_BUFFER = ^RETRIEVAL_POINTERS_BUFFER;

type
  TfrmExtents = class(TForm)
    Memo: TMemo;
    btnOpen: TButton;
    txtfilename: TEdit;
    Label1: TLabel;
    btnDump: TButton;
    SaveDialog1: TSaveDialog;
    ProgressBar: TProgressBar;
    JvOpenDialog1: TJvOpenDialog;
    procedure btnOpenClick(Sender: TObject);
    procedure btnDumpClick(Sender: TObject);
    procedure JvOpenDialog1ShareViolation(Sender: TObject;
      var CanClose: Boolean);
    procedure FormCreate(Sender: TObject);
    procedure MemoDblClick(Sender: TObject);
  private
    { Private declarations }
    procedure get_details(filename:string);
    procedure backup(source,destination:string);
  public
    { Public declarations }
  end;



var
  frmExtents: TfrmExtents;
  console:boolean;

implementation

{$R *.dfm}

procedure dolog(msg:string);
begin
if console=true
 then writeln(msg)
 else frmExtents.Memo.Lines.Add(msg);
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
      extents_ [0].NextVcn.quadpart :=0;
      while (r < OutBuf^.ExtentCount) do
      begin
        Lcn := OutBuf^.Extents[r].Lcn;
        CnCount := ULONG(OutBuf^.Extents[r].NextVcn.QuadPart - PrevVCN.QuadPart);

        sectors:=0;
        while (CnCount > 0) do
        begin
          Clusters[Cls] := Lcn.QuadPart;
          Dec(CnCount);
          Inc(Cls);inc(sectors);
          Inc(Lcn.QuadPart);
        end;

        extents_ [r].sectors :=sectors*ClusterSize div 512;

        if r<OutBuf^.ExtentCount -1 then
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

procedure TfrmExtents.get_details(filename:string);
var
lpSrcName:pchar;
Clusters: TClusters;
Extents_: TExtents_;
FileSize, ClusterSize:int64;
ClCount,i,sector: ULONG;
Name: array[0..6] of Char;
SecPerCl, BtPerSec, FreeClusters, NumOfClusters: DWORD;
lba:int64;
FSName,VolName:array[0..255] of char;
FSSysFlags,maxCmp   : DWord;
begin

lpSrcName:=pchar(filename);
//lets get the cluster size
Name[0] := lpSrcName[0];
  Name[1] := ':';
  Name[2] := Char(0);
  FreeClusters := 0;
  NumOfClusters := 0;
  GetDiskFreeSpace(Name, SecPerCl, BtPerSec, FreeClusters, NumOfClusters);
  ClusterSize := SecPerCl * BtPerSec;
//
try
Clusters := GetFileClusters(lpSrcName, ClusterSize, @ClCount, FileSize,extents_);
except
on e:exception do dolog(e.Message );
end;
//
  dolog('***************************');
  dolog('Bytes Per Sector:'+inttostr(BtPerSec));
  dolog('Sectors per Cluster:'+inttostr(SecPerCl));
  dolog('Cluster size :'+inttostr(SecPerCl * BtPerSec));
//
if high(clusters)<=0 then
  begin
  dolog('');
  dolog('no clusters found...');
  exit;
  end;
if GetVolumeInformation(PChar(copy(lpSrcName,1,3)), @VolName[0], MAX_PATH, nil,
                       maxCmp, FSSysFlags, @FSName[0], MAX_PATH)=true then
begin
lba:=0;
dolog('Filesystem :'+strpas(FSName));
//Send the first extent's LCN to translation to physical offset from the beginning of the disk
//if FSName='NTFS' then lba:=TranslateLogicalToPhysical(lpSrcName,clusters[0] * (SecPerCl * BtPerSec));
end;
//
  dolog('***************************');
  dolog('Filename:'+filename );
  dolog('File Cluster count :'+inttostr(clcount)+' -> in bytes: '+inttostr(clcount*SecPerCl * BtPerSec));
  dolog('File size in bytes :'+inttostr(FileSize));
  dolog('File cluster first :'+inttostr(clusters[low(clusters)]));
  dolog('File cluster last  :'+inttostr(clusters[high(clusters)]));
  //if length(extents_)=1 then dolog('Sectors  :'+inttohex(SecPerCl*clcount,8));
  dolog('');
  //*************
  if 1=1 then
  begin
  sector:=0;lba:=0;
  for i:=low(extents_) to high(extents_)  do
  begin
  if FSName='NTFS' then lba:=TranslateLogicalToPhysical(lpSrcName,clusters[sector div 8] * (SecPerCl * BtPerSec));
  sector:=sector+extents_[i].sectors ;//add the number of sectors for each extent - cluster = sectors div 8
  dolog('extents_['+inttostr(i)+'] : 0x'+inttohex(extents_[i].NextVcn.lowPart ,4)+inttohex(extents_[i].NextVcn.highPart ,4)
    +' Sectors : 0x'+inttohex(extents_[i].sectors ,8)
    +' Lba : 0x'+inttohex(lba div BtPerSec,8));
  end;
  end;
  //**********
  if 1=2 then
  begin
  for i:=1 to clcount  do
  begin
  dolog('cluster['+inttostr(i)+'] = '+inttostr(clusters[i-1]));
  end;
  dolog('***************************');
  end;
end;

procedure TfrmExtents.btnOpenClick(Sender: TObject);
begin
Memo.Lines.Clear ;
txtfilename.Clear ;
if txtfilename.Text ='' then
  begin
  //if OpenDialog1.Execute=false then exit;
  //edit1.Text :=OpenDialog1.Filename ;
  if JvOpenDialog1.Execute =false then exit;
  txtfilename.Text :=JvOpenDialog1.FileName ;
  end;
get_details(txtfilename.Text) ;
end;



procedure TfrmExtents.backup(source,destination:string);
var
lpDstName,lpSrcName:pchar;
Clusters: TClusters;
Extents_: TExtents_;
FileSize, ClusterSize,FullSize,BlockSize, CopyedSize:int64;
 r,ClCount,i: ULONG;
Name: array[0..6] of Char;
Progress,SecPerCl, BtPerSec, FreeClusters, NumOfClusters: DWORD;
hDrive, hFile: THandle;
 Buff: PByte;
Offset: LARGE_INTEGER;
Bytes: ULONG; 
begin

lpSrcName :=pchar(source );

lpDstName :=pchar(destination );;
{$i-}deletefile(lpDstName );{$i+}
//lets get the cluster size
Name[0] := lpSrcName[0];
  Name[1] := ':';
  Name[2] := Char(0);
  FreeClusters := 0;
  NumOfClusters := 0;
  GetDiskFreeSpace(Name, SecPerCl, BtPerSec, FreeClusters, NumOfClusters);
  ClusterSize := SecPerCl * BtPerSec;
//
Clusters := GetFileClusters(lpSrcName, ClusterSize, @ClCount, FileSize,extents_);
//
FullSize := FileSize;

  if (Clusters <> nil) then
  begin
    Name[0] := '\';
    Name[1] := '\';
    Name[2] := '.';
    Name[3] := '\';
    Name[4] := lpSrcName[0];
    Name[5] := ':';
    Name[6] := Char(0);

    hDrive := CreateFile(Name, GENERIC_READ, FILE_SHARE_READ or FILE_SHARE_WRITE, nil, OPEN_EXISTING, 0, 0);

    if (hDrive <> INVALID_HANDLE_VALUE) then
    begin
      hFile := CreateFile(lpDstName, GENERIC_WRITE, 0, nil, CREATE_NEW, 0, 0);

      if (hFile <> INVALID_HANDLE_VALUE) then
      begin
        GetMem(Buff, ClusterSize);

        r := 0;
        CopyedSize := 0;
        while (r < ClCount) do
        begin
          Application.ProcessMessages;
          
          Offset.QuadPart := ClusterSize * Clusters[r];

          SetFilePointer(hDrive, Offset.LowPart, @Offset.HighPart, FILE_BEGIN);

          ReadFile(hDrive, Buff^, ClusterSize, Bytes, nil);

          BlockSize := Min(FileSize, ClusterSize);

          WriteFile(hFile, Buff^, BlockSize, Bytes, nil);

          CopyedSize := CopyedSize + BlockSize;
          FileSize := FileSize - BlockSize;
          if FullSize <> 0 then
            Progress :=  Round (CopyedSize*100 / FullSize) 
          else
            Progress := 100 ;
          Inc(r);
          ProgressBar.Position :=Progress ;
        end;
        FreeMem(Buff);
        CloseHandle(hFile);
        Progress := 100 ;
        //Result := True;
        dolog('copy completed, '+inttostr(fullsize)+' bytes copied');
      end;
      CloseHandle(hDrive);
    end;
    Clusters := nil;
  end;
//    
end;

procedure TfrmExtents.btnDumpClick(Sender: TObject);
begin
//memo1.Lines.Clear ;
//edit1.Clear ;
if txtfilename.Text ='' then
  begin
  if jvOpenDialog1.Execute=false then exit;
  txtfilename.Text :=jvOpenDialog1.filename;
  end;
if SaveDialog1.Execute =false then exit;
backup(txtfilename.Text,SaveDialog1.FileName );
end;

procedure TfrmExtents.JvOpenDialog1ShareViolation(Sender: TObject;
  var CanClose: Boolean);
begin
canclose:=true;
end;

procedure TfrmExtents.FormCreate(Sender: TObject);
type
    AConsoleFunc = function(dwProcessId: Longint): boolean; stdcall;
var
 AttachConsole: AConsoleFunc;
 handle:thandle;
begin
handle:=thandle(-1);
Handle := LoadLibrary('KERNEL32.DLL');
if Handle <> thandle(-1) then
begin
@AttachConsole := GetProcAddress(Handle, 'AttachConsole');
if @AttachConsole <> nil then
begin
if AttachConsole(-1) then
  begin
  console:=true;
  self.WindowState:=wsMinimized ;
  writeln('');
  if paramcount=0 then
  begin
  //writeln('console mode');
  writeln('Extents by Erwan L.');
  writeln('Extents -details filename');
  writeln('Extents -backup source destination');
  writeln('');
  end; //if paramcount=0 then
  //halt(0);
  end;
end; //if @AttachConsole <> nil then
freelibrary(handle);
end;//if Handle <> 0 then

if paramcount>0 then
begin

if (paramstr(1)='-details') and (paramcount=2) then
  begin
  get_details(paramstr(2));
  end;

if (paramstr(1)='-backup') and (paramcount=3) then
  begin
  backup (paramstr(2),paramstr(3)); 
  end;

if console=true then
    begin
    writeln('Done');
    FreeConsole;
    end;
  //self.Close ;
  application.Terminate ;

end;//if paramcount>0 then

end;

procedure TfrmExtents.MemoDblClick(Sender: TObject);
begin
memo.Clear ;
end;

end.
