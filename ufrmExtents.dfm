object frmExtents: TfrmExtents
  Left = 307
  Top = 201
  Width = 727
  Height = 576
  Caption = 'Dump Extents by Erwan2212@gmail.com'
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -14
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  OldCreateOrder = False
  OnCreate = FormCreate
  PixelsPerInch = 120
  TextHeight = 16
  object Label1: TLabel
    Left = 30
    Top = 414
    Width = 56
    Height = 16
    Caption = 'Filename'
  end
  object Memo: TMemo
    Left = 30
    Top = 10
    Width = 660
    Height = 395
    Lines.Strings = (
      '')
    ScrollBars = ssVertical
    TabOrder = 0
    OnDblClick = MemoDblClick
  end
  object btnOpen: TButton
    Left = 601
    Top = 433
    Width = 92
    Height = 31
    Caption = 'Open'
    TabOrder = 1
    OnClick = btnOpenClick
  end
  object txtfilename: TEdit
    Left = 30
    Top = 438
    Width = 562
    Height = 24
    ReadOnly = True
    TabOrder = 2
  end
  object btnDump: TButton
    Left = 601
    Top = 473
    Width = 92
    Height = 30
    Caption = 'Dump'
    TabOrder = 3
    OnClick = btnDumpClick
  end
  object ProgressBar: TProgressBar
    Left = 30
    Top = 482
    Width = 562
    Height = 21
    TabOrder = 4
  end
  object Button1: TButton
    Left = 600
    Top = 512
    Width = 75
    Height = 25
    Caption = 'TEST'
    TabOrder = 5
    Visible = False
    OnClick = Button1Click
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
