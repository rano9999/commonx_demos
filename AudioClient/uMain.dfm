object Form1: TForm1
  Left = 0
  Top = 0
  Caption = 'Form1'
  ClientHeight = 274
  ClientWidth = 920
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  PixelsPerInch = 96
  TextHeight = 13
  object Label1: TLabel
    Left = 744
    Top = 13
    Width = 67
    Height = 13
    Caption = 'Audio Servers'
  end
  object lblStatus: TLabel
    Left = 30
    Top = 84
    Width = 83
    Height = 13
    Caption = 'Device Status: nil'
  end
  object ListBox1: TListBox
    Left = 744
    Top = 32
    Width = 161
    Height = 217
    ItemHeight = 13
    TabOrder = 0
  end
  object Button1: TButton
    Left = 30
    Top = 144
    Width = 75
    Height = 25
    Caption = 'sine wave'
    TabOrder = 1
    OnClick = Button1Click
  end
  object RadioGroup1: TRadioGroup
    Left = 24
    Top = 13
    Width = 345
    Height = 65
    Caption = 'API'
    Items.Strings = (
      'Windows Multimedia (no special requirements, higher latency)'
      
        'Port Audio (abstraction layer, low latency, requires PortAudio d' +
        'lls)')
    TabOrder = 2
    OnClick = RadioGroup1Click
  end
  object lbDevices: TListBox
    Left = 375
    Top = 8
    Width = 298
    Height = 236
    ItemHeight = 13
    TabOrder = 3
    OnClick = lbDevicesClick
  end
  object tmLookForAudio: TTimer
    Left = 88
    Top = 200
  end
end
