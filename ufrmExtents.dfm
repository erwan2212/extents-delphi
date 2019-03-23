object frmExtents: TfrmExtents
  Left = 307
  Top = 201
  Width = 583
  Height = 454
  Caption = 'Dump Extents by Erwan2212@gmail.com'
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  OldCreateOrder = False
  OnCreate = FormCreate
  PixelsPerInch = 96
  TextHeight = 13
  object Label1: TLabel
    Left = 24
    Top = 336
    Width = 42
    Height = 13
    Caption = 'Filename'
  end
  object Memo: TMemo
    Left = 24
    Top = 8
    Width = 537
    Height = 321
    Lines.Strings = (
      '')
    ScrollBars = ssVertical
    TabOrder = 0
    OnDblClick = MemoDblClick
  end
  object btnOpen: TButton
    Left = 488
    Top = 352
    Width = 75
    Height = 25
    Caption = 'Open'
    TabOrder = 1
    OnClick = btnOpenClick
  end
  object txtfilename: TEdit
    Left = 24
    Top = 356
    Width = 457
    Height = 21
    ReadOnly = True
    TabOrder = 2
  end
  object btnDump: TButton
    Left = 488
    Top = 384
    Width = 75
    Height = 25
    Caption = 'Dump'
    TabOrder = 3
    OnClick = btnDumpClick
  end
  object ProgressBar: TProgressBar
    Left = 24
    Top = 392
    Width = 457
    Height = 17
    TabOrder = 4
  end
  object SaveDialog1: TSaveDialog
    Left = 136
    Top = 184
  end
  object JvOpenDialog1: TJvOpenDialog
    Height = 0
    Width = 0
    OnShareViolation = JvOpenDialog1ShareViolation
    Left = 216
    Top = 120
  end
end
