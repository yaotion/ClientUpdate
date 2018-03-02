program PatchMaker;

uses
  Forms,
  SysUtils,
  Windows,
  uFrmPatchMaker in '���ܴ���\����������\uFrmPatchMaker.pas' {FrmPatchMaker},
  uAutoUpdate in '..\..\Souce\������Ԫ\uAutoUpdate.pas';

{$R *.res}
var
  HMutex : DWord;
begin
  HMutex := CreateMutex(nil, True, 'TF_PatchMaker'); //����Mutex���
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
  Application.Title := '����������';
  begin
    try
      TFrmPatchMaker.ShowForm;
    except on e : exception do
    end;
  end;
  Application.Run;
  Application.Terminate;
end.
