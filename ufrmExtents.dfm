object frmExtents: TfrmExtents
  Left = 307
  Top = 201
  Width = 465
  Height = 375
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
    Top = 256
    Width = 42
    Height = 13
    Caption = 'Filename'
  end
  object Memo: TMemo
    Left = 24
    Top = 32
    Width = 409
    Height = 217
    Lines.Strings = (
      '')
    ScrollBars = ssVertical
    TabOrder = 0
  end
  object btnOpen: TButton
    Left = 360
    Top = 272
    Width = 75
    Height = 25
    Caption = 'Open'
    TabOrder = 1
    OnClick = btnOpenClick
  end
  object txtfilename: TEdit
    Left = 24
    Top = 276
    Width = 329
    Height = 21
    ReadOnly = True
    TabOrder = 2
  end
  object btnDump: TButton
    Left = 360
    Top = 304
    Width = 75
    Height = 25
    Caption = 'Dump'
    TabOrder = 3
    OnClick = btnDumpClick
  end
  object ProgressBar: TProgressBar
    Left = 24
    Top = 312
    Width = 329
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
