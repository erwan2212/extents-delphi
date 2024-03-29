unit ufrmExtents;

interface

uses
  Windows, Messages, SysUtils,  Classes,  Controls, Forms,
    ComCtrls, JvDialogs, StdCtrls, Dialogs,math,utils;



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
    Button1: TButton;
    procedure btnOpenClick(Sender: TObject);
    procedure btnDumpClick(Sender: TObject);
    procedure JvOpenDialog1ShareViolation(Sender: TObject;
      var CanClose: Boolean);
    procedure FormCreate(Sender: TObject);
    procedure MemoDblClick(Sender: TObject);
    procedure Button1Click(Sender: TObject);
  private
    { Private declarations }
    procedure get_details(filename:string);
    procedure backup(source,destination:string;const altclusters:tclusters=(0));
  public
    { Public declarations }
  end;

const
emptyclusters:tclusters=(0);

var
  frmExtents: TfrmExtents;
  console:boolean;

implementation

{$R *.dfm}

procedure dolog(msg:string);
begin
if console=true
 then {$i-}writeln(msg){$i+}
 else frmExtents.Memo.Lines.Add(msg);
end;

function getfilesize2(filename:string):int64;
var
fad:WIN32_FILE_ATTRIBUTE_DATA;
filesize:int64;
fd:TWin32FindData;
hfile:thandle;
begin
result:=0;
hFile := FindFirstFile(pchar(filename) , fd);
if hfile<>thandle(-1) then
  begin
      filesize := fd.nFileSizeHigh;
      filesize := filesize shl 32;
      filesize := filesize + fd.nFileSizeLow;
      result:=filesize;
      try windows.findclose(hfile);except end;
  end;
end;



procedure TfrmExtents.get_details(filename:string);
var
Clusters: TClusters;
Extents_: TExtents_;
FileSize, ClusterSize:int64;
ClCount,i,sector: ULONG;
Name: array[0..2] of ansiChar;
SecPerCl, BtPerSec, FreeClusters, NumOfClusters: DWORD;
lba,delta:int64;
FSName,VolName:array[0..255] of ansichar;
FSSysFlags,maxCmp   : DWord;
//
hdevice:thandle;
info:PARTITION_INFORMATION_EX;
ret:boolean;
buffer:pointer;
bytesread:cardinal;
bs:tboot_sequence;                
begin


//lets get the cluster size
Name[0] := filename[1];
  Name[1] := ':';
  Name[2] := Char(0);
  FreeClusters := 0;
  NumOfClusters := 0;
  GetDiskFreeSpaceA(Name, SecPerCl, BtPerSec, FreeClusters, NumOfClusters);
  ClusterSize := SecPerCl * BtPerSec;
//
hdevice:=thandle(-1);
hDevice := CreateFile( pchar('\\.\'+copy(filename,1,2)), GENERIC_READ, FILE_SHARE_READ or FILE_SHARE_WRITE,nil, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, 0);
  if GetPartitionInfo(hDevice ,info)=true then
   begin
   dolog('PartitionNumber: '+inttostr(info.PartitionNumber ));
   dolog('StartingOffset: '+inttostr(info.StartingOffset.QuadPart));
   end;

if FSName <>'NTFS' then
    begin
    buffer:=allocmem(512);
    bytesread:=0;
    fillchar(bs,sizeof(bs),0);
    ret:=ReadFile (hdevice, buffer^, 512, bytesread, nil);
    delta:=0;
    if bytesread>0 then
      begin
      copymemory(@bs,buffer,512);
      delta:=(bs.wSectorsReservedAtBegin*bs.wBytesPerSector)+(bs.NumberOfFATs *bs.BigSectorsPerFAT*bs.wBytesPerSector);
      //writeln(delta);
      end;
    freemem(buffer);
    end;
if hdevice>0 then closehandle(hdevice);
//
try
Clusters := GetFileClusters(filename, ClusterSize,BtPerSec, @ClCount, FileSize,extents_);
except
on e:exception do begin dolog('GetFileClusters:'+e.Message );exit;end;
end;
//
  dolog('***************************');
  dolog('Bytes Per Sector:'+inttostr(BtPerSec));
  dolog('Sectors per Cluster:'+inttostr(SecPerCl));
  dolog('Cluster size :'+inttostr(SecPerCl * BtPerSec));
//
if length(clusters)<=0 then
  begin
  dolog('');
  dolog('no clusters found...');
  exit;
  end;
if GetVolumeInformation(PChar(copy(filename,1,3)), @VolName[0], MAX_PATH, nil,
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
  dolog('File Cluster count :'+inttostr(clcount)+' -> in bytes: '+inttostr(int64(clcount)*SecPerCl * BtPerSec));
  dolog('File size in bytes :'+inttostr(FileSize));
  dolog('File cluster first :'+inttostr(clusters[low(clusters)]));
  dolog('Extents count :'+inttostr(length(extents_)));
  //dolog('File cluster last  :'+inttostr(clusters[high(clusters)]));
  //if length(extents_)=1 then dolog('Sectors  :'+inttohex(SecPerCl*clcount,8));
  dolog('');
  //*************
  //https://flatcap.org/linux-ntfs/ntfs/concepts/clusters.html
  if 1=1 then
  begin
  sector:=0;lba:=0;
  i:=0;
  for i:=low(extents_) to high(extents_)  do
  //if 1=1 then
  begin
  if strpas(FSName)='NTFS' then lba:=TranslateLogicalToPhysical(filename,clusters[sector div 8] * (SecPerCl * BtPerSec));
  if FSName<>'NTFS' then lba:=delta + (extents_[i].LCN.QuadPart * int64(SecPerCl * BtPerSec)) + int64(info.StartingOffset.QuadPart);
  sector:=sector+extents_[i].sectors ;//add the number of sectors for each extent - cluster = sectors div 8

  dolog('extents_['+inttostr(i)+'] - '
    //+' VCN : 0x'+inttohex(extents_[i].NextVcn.lowPart ,4)+inttohex(extents_[i].NextVcn.highPart ,4)
    +' VCN : '+inttostr(extents_[i].NextVcn.QuadPart )
    +' LCN : '+inttostr(extents_[i].LCN.QuadPart )
    +' Size(Sectors) : '+inttostr(extents_[i].sectors )
    +' Lba : '+inttostr(lba div BtPerSec));
  
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



procedure TfrmExtents.backup(source,destination:string;const altclusters:tclusters=(0));
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
try
lpSrcName :=pchar(source );

lpDstName :=pchar(destination );;
{$i-}deletefile(strpas(lpDstName) );{$i+}
//lets get the cluster size
Name[0] := lpSrcName[0];
  Name[1] := ':';
  Name[2] := Char(0);
  FreeClusters := 0;
  NumOfClusters := 0;
  GetDiskFreeSpace(Name, SecPerCl, BtPerSec, FreeClusters, NumOfClusters);
  ClusterSize := SecPerCl * BtPerSec;
//
if length(altclusters)>0 then
begin
  clcount:=length(altclusters );
  filesize:=getfilesize2(source);
  clusters:=altclusters ; 
end
else
  begin
  try
  Clusters := GetFileClusters(strpas(lpSrcName), ClusterSize,BtPerSec, @ClCount, FileSize,extents_);
  except
  on e:exception do dolog(e.Message );
  end;
end;
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
        //GetMem(Buff, ClusterSize); //allocmem would create a zerofilled buffer
        buff:=allocmem(ClusterSize );
        r := 0;
        CopyedSize := 0;
        while (r < ClCount) do
        begin
          Application.ProcessMessages;
          
          Offset.QuadPart := ClusterSize * Clusters[r];

          SetFilePointer(hDrive, Offset.LowPart, @Offset.HighPart, FILE_BEGIN);

          if not ReadFile(hDrive, Buff^, ClusterSize, Bytes, nil) then break;

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
    //Clusters := nil;
  end;
//
except
on e:exception do showmessage(e.Message );
end;

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


//little experiment to read a file locked by the system
procedure TfrmExtents.Button1Click(Sender: TObject);
var
clcount,filesize,ClusterSize:int64;
i:ulong;
hfile:thandle;
clusters:tclusters;
SecPerCl, BtPerSec, FreeClusters, NumOfClusters: DWORD;
fad:WIN32_FILE_ATTRIBUTE_DATA;
size:LARGE_INTEGER ;
fd:TWin32FindData;
begin
hfile:=thandle(-1);
clcount:=0;
//
GetDiskFreeSpaceA(pchar('c:\'), SecPerCl, BtPerSec, FreeClusters, NumOfClusters);
ClusterSize := SecPerCl * BtPerSec;
//
{
if GetFileAttributesEx(pchar('c:\swapfile.sys'),GetFileExInfoStandard,@fad) then
  begin
  size.LowPart :=fad.nFileSizeLow ;
  size.HighPart :=fad.nFileSizeHigh ;
  filesize :=size.QuadPart ;
  end;
}
{
hFile := CreateFile(pchar('c:\swapfile.sys'), 0, 0, nil, OPEN_EXISTING, 0, 0);
if hfile<>thandle(-1) then
  begin
  Int64Rec(FileSize).Lo := GetFileSize(hFile, @Int64Rec(FileSize).Hi);
  closehandle(hfile);
  end;
}
//the below retrieves filesize from the mft - no need for createfile...
Filesize := getfilesize2(pchar('c:\swapfile.sys'));
//
//particular case here :
//datarun gave us one cluster only (0x10000) i.e file is contiguous
//therefore we will fill the cluster array ourself
ClCount := (FileSize + ClusterSize - 1) div ClusterSize;
SetLength(Clusters, ClCount);
clusters[0]:=$10000;
for i:=1 to clcount -1 do clusters[i]:=clusters[i-1]+ClusterSize ;
//
backup('c:\swapfile.sys','c:\test.dmp',clusters);
end;

end.
