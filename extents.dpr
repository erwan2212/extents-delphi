program extents;

uses
  madExcept,
  madLinkDisAsm,
  madListModules,
  Forms,
  ufrmExtents in 'ufrmExtents.pas' {frmExtents},
  utils in 'utils.pas';

{$R *.res}
{$R uac.res}

begin
  Application.Initialize;
  Application.CreateForm(TfrmExtents, frmExtents);
  Application.Run;
end.
