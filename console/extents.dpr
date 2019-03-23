program extents;

{$APPTYPE CONSOLE}

uses
  windows,SysUtils,math,
  utils in '..\utils.pas';

procedure dolog(msg:string);
begin
writeln(msg)
end;

procedure backup(source,destination:string);
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
          //Application.ProcessMessages;

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
          //ProgressBar.Position :=Progress ;
          write('.');
        end;
        FreeMem(Buff);
        CloseHandle(hFile);
        Progress := 100 ;
        //Result := True;
        dolog('');
        dolog('copy completed, '+inttostr(fullsize)+' bytes copied');
      end;
      CloseHandle(hDrive);
    end;
    Clusters := nil;
  end;
//    
end;

procedure get_details(filename:string);
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
  dolog('File Cluster count :'+inttostr(clcount)+' ('+inttostr(clcount*SecPerCl * BtPerSec)+' bytes)');
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
  for i:=low(extents_) to high(extents_)  do
  begin
  if FSName='NTFS' then lba:=TranslateLogicalToPhysical(lpSrcName,clusters[sector div 8] * (SecPerCl * BtPerSec));
  sector:=sector+extents_[i].sectors ;//add the number of sectors for each extent - cluster = sectors div 8
  dolog('extents_['+inttostr(i)+'] - '
    //+' VCN : 0x'+inttohex(extents_[i].NextVcn.lowPart ,4)+inttohex(extents_[i].NextVcn.highPart ,4)
    +' VCN : '+inttostr(extents_[i].NextVcn.QuadPart )
    +' LCN : '+inttostr(extents_[i].LCN.QuadPart )
    //+' Lba : 0x'+inttohex(lba div BtPerSec,8)
    +' Lba : '+inttostr(lba div BtPerSec)
    +' Sectors : '+inttostr(extents_[i].sectors ));
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

begin
  { TODO -oUser -cConsole Main : Insert code here }
  writeln('extents 1.0 by erwan2212@gmail.com');
  if paramcount=0 then
    begin
    writeln('extents filename');
    writeln('extents source destination');
    exit;
    end;
  if paramcount=1 then get_details(paramstr(1)) ;
  if paramcount=2 then backup(paramstr(1),paramstr(2));
end.
