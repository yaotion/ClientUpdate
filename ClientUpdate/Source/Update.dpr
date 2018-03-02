program Update;

uses
  Forms,
  SysUtils,
  Windows,
  uFrmUpdate in '���ܴ���\�ͻ�������\uFrmUpdate.pas' {FrmUpdate},
  uAutoUpdate in '..\..\Souce\������Ԫ\uAutoUpdate.pas',
  uLogs in '..\..\Souce\������Ԫ\��־\uLogs.pas';

{$R *.res}
var
  HMutex : DWord;
begin
  HMutex := CreateMutex(nil, True, 'TF_Update'); //����Mutex���
  {-----���Mutex�����Ƿ���ڣ�������ڣ��˳�����------------}
  if (GetLastError = ERROR_ALREADY_EXISTS) then
  begin
    ReleaseMutex(hMutex); //�ͷ�Mutex����
    Exit;
  end;
  TimeSeparator := ':';
  DateSeparator := '-';
  ShortDateFormat := 'yyyy-mm-dd';
  ShortTimeFormat := 'hh:nn:ss';
  //ReportMemoryLeaksOnShutdown := DebugHook <> 0;
  Application.Initialize;
  Application.Title := '�ͻ�������';
  begin
    try
      TFrmUpdate.ShowForm;
    except on e : exception do
    end;
  end;
  Application.Run;
  Application.Terminate;
end.