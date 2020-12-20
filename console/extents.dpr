program extents;

{$APPTYPE CONSOLE}

uses
  windows,SysUtils,math,
  utils in '..\utils.pas';

function GetVolumePathName(lpszFileName:LPCTSTR; lpszVolumePathName:LPTSTR; cchBufferLength:DWORD): BOOL; stdcall external Kernel32 name 'GetVolumePathNameA';
function GetVolumePathNamesForVolumeName(lpszVolumeName: LPCTSTR;lpszVolumePathNames: LPTSTR;cchBufferLength: DWORD;lpcchReturnLength:PDWORD):BOOL; stdcall external Kernel32 name 'GetVolumePathNamesForVolumeNameA';

var
i64:int64;

procedure dolog(msg:string);
begin
try
writeln(msg)
except
on e:exception do writeln(e.message);
end;
end;


procedure backup(source,destination:string);
var
Clusters: TClusters;
Extents_: TExtents_;
FileSize, ClusterSize,FullSize,BlockSize, CopyedSize:int64;
 r,ClCount,i: ULONG;
Name: array[0..2] of ansiChar;
Progress,SecPerCl, BtPerSec, FreeClusters, NumOfClusters: DWORD;
hDrive, hFile: THandle;
 Buff: PByte;
Offset: LARGE_INTEGER;
Bytes: ULONG; 
begin

{$i-}deletefile(destination );{$i+}
//lets get the cluster size
Name[0] := source[1];
  Name[1] := ':';
  Name[2] := Char(0);
  FreeClusters := 0;
  NumOfClusters := 0;
  GetDiskFreeSpace(Name, SecPerCl, BtPerSec, FreeClusters, NumOfClusters);
  ClusterSize := SecPerCl * BtPerSec;
//
Clusters := GetFileClusters(pchar(source), ClusterSize,BtPerSec, @ClCount, FileSize,extents_);
//
FullSize := FileSize;

  if (Clusters <> nil) then
  begin
    Name[0] := '\';
    Name[1] := '\';
    Name[2] := '.';
    Name[3] := '\';
    Name[4] := source[1];
    Name[5] := ':';
    Name[6] := Char(0);

    hDrive := CreateFile(Name, GENERIC_READ, FILE_SHARE_READ or FILE_SHARE_WRITE, nil, OPEN_EXISTING, 0, 0);

    if (hDrive <> INVALID_HANDLE_VALUE) then
    begin
      hFile := CreateFile(pchar(destination), GENERIC_WRITE, 0, nil, CREATE_NEW, 0, 0);

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

          windows.ReadFile(hDrive, Buff^, ClusterSize, Bytes, nil);

          BlockSize := Min(FileSize, ClusterSize);

          windows.WriteFile(hFile, Buff^, BlockSize, Bytes, nil);

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
Clusters: TClusters;
Extents_: TExtents_;
FileSize, ClusterSize:int64;
ClCount,i,sector: ULONG;
Name: array[0..2] of ansiChar;
returned,SecPerCl, BtPerSec, FreeClusters, NumOfClusters: DWORD;
lba:int64;
FSName,VolName:array[0..255] of ansichar;
FSSysFlags,maxCmp   : DWord;
volumepathname:lptstr;
vol:string;
begin
//in case full path name is not provided and file is in current dir
if (pos(':',filename)=0) and (pos('?',filename)=0) then filename:=GetCurrentDir +'\'+ filename;
//in case user provide a volume path
if pos('?',filename)>0 then
   begin
     try
     getmem(volumepathname ,MAX_PATH );
     //if GetVolumePathName(pchar(filename),volumepathname,MAX_PATH) then writeln(volumepathname ) else dolog('GetVolumePathNameA failed');
     //above works but lets do it the old way...
     vol:=copy(filename,1,pos('}\',filename)+1);
     delete(filename,1,pos('}\',filename)+1);
     //dolog(vol);dolog(filename);
     if GetVolumePathNamesForVolumeName(pchar(vol),volumepathname,MAX_PATH ,@returned) then filename:=volumepathname+filename;
     finally
     freemem(volumepathname ,MAX_PATH );
     end;
   end;
if not FileExists (filename) then begin dolog('file cannot be found');exit;end;
//lets get the cluster size
  Name[0] := filename[1];
  Name[1] := ':';
  Name[2] := Char(0);
  FreeClusters := 0;
  NumOfClusters := 0;
  SecPerCl:=0; BtPerSec:=0;
  ClusterSize:=0;
  if GetDiskFreeSpaceA(Name, SecPerCl, BtPerSec, FreeClusters, NumOfClusters)=false then begin dolog('GetDiskFreeSpace failed');exit;end;
  ClusterSize := SecPerCl * BtPerSec;
//
dolog('***************************');
dolog('Bytes Per Sector:'+inttostr(BtPerSec));
dolog('Sectors per Cluster:'+inttostr(SecPerCl));
dolog('Cluster size :'+inttostr(SecPerCl * BtPerSec));
//
try
FileSize:=0;ClCount:=0;
SetLength(Clusters ,0);
SetLength(extents_ ,0);
Clusters := GetFileClusters(filename, ClusterSize,BtPerSec, @ClCount, FileSize,extents_);
except
on e:exception do dolog('GetFileClusters:'+e.Message );
end;
//
if length(clusters)<=0 then
  begin
  dolog('');
  dolog('no clusters found...');
  exit;
  end;
//fillchar(fsname,MAX_PATH ,0);
//fillchar(VolName,MAX_PATH ,0);
if GetVolumeInformationA(PansiChar(copy(filename,1,3)), @VolName[0], MAX_PATH, nil,
                       maxCmp, FSSysFlags, @FSName[0], MAX_PATH)=true then
begin
lba:=0;
dolog('Filesystem :'+string(strpas(@FSName[0])));
//Send the first extent's LCN to translation to physical offset from the beginning of the disk
//if FSName='NTFS' then lba:=TranslateLogicalToPhysical(lpSrcName,clusters[0] * (SecPerCl * BtPerSec));
end;
//
  dolog('***************************');
  dolog('Filename:'+filename );
  dolog('File Cluster count :'+inttostr(clcount)+' ('+inttostr(int64(clcount)*SecPerCl * BtPerSec)+' bytes)');
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
  if FSName='NTFS' then lba:=TranslateLogicalToPhysical(filename,clusters[sector div 8] * (SecPerCl * BtPerSec));
  sector:=sector+extents_[i].sectors ;//add the number of sectors for each extent - cluster = sectors div 8
  dolog('#:'+inttostr(i)+#9
    //+' VCN : 0x'+inttohex(extents_[i].NextVcn.lowPart ,4)+inttohex(extents_[i].NextVcn.highPart ,4)
    +'VCN:'+inttostr(extents_[i].NextVcn.QuadPart )+#9
    +'LCN:'+inttostr(extents_[i].LCN.QuadPart )+#9
    //+' Lba : 0x'+inttohex(lba div BtPerSec,8)
    +'Lba:'+inttostr(lba div BtPerSec)+#9
    +'Clusters:'+inttostr(extents_[i].sectors div SecPerCl));
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
  writeln('extents 1.4 by erwan2212@gmail.com');
  if paramcount=0 then
    begin
    writeln('extents path_to_filename');
    writeln('extents path_to_source path_to_destination');
    writeln('extents translatelog x: logical_pos_in_bytes');
    writeln('extents translatephy x: phy_pos_in_bytes');
    exit;
    end;
  if paramcount=1 then get_details(paramstr(1)) ;
  if paramcount=2 then backup(paramstr(1),paramstr(2));
  if paramstr(1)='translatelog' then
     begin
     i64:= TranslateLogicalToPhysical(paramstr(2),strtoint64(paramstr(3)));
     writeln('logical : '+paramstr(3) );
     writeln('Physical : '+inttostr(i64)+' bytes - '+inttostr(i64 div 512)+' sectors' );
     writeln('Sectors-Before : '+inttostr(i64-strtoint64(paramstr(3))));
     end;
  if paramstr(1)='translatephy' then
     begin
     i64:= TranslatePhysicalToLogical(paramstr(2),strtoint64(paramstr(3)));
     writeln('physical : '+paramstr(3) );
     writeln('logical : '+inttostr(i64)+' bytes - '+inttostr(i64 div 512)+' sectors' );
     writeln('Sectors-Before : '+inttostr(strtoint64(paramstr(3))-i64));
     end;

end.
