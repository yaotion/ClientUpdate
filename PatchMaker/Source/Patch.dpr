program Patch;

uses
  Forms,
  SysUtils,
  Windows,
  uFrmPatch in '���ܴ���\��������װ\uFrmPatch.pas' {FrmPatch},
  uAutoUpdate in '..\..\Souce\������Ԫ\uAutoUpdate.pas',
  uLogs in '..\..\Souce\������Ԫ\��־\uLogs.pas';

{$R *.res}
var
  HMutex : DWord;
begin
  HMutex := CreateMutex(nil, True, 'TF_Patch'); //����Mutex���
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
  //ReportMemoryLeaksOnShutdown := DebugHook <> 0;x
  Application.Initialize;
  Application.Title := '��������װ';
  begin
    try
      TFrmPatch.ShowForm();
    except on e : exception do
    end;
  end;
  Application.Run;
  Application.Terminate;
end.
