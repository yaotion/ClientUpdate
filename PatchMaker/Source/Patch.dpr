program Patch;

uses
  Forms,
  SysUtils,
  Windows,
  uFrmPatch in '功能窗口\升级包安装\uFrmPatch.pas' {FrmPatch},
  uAutoUpdate in '..\..\Souce\公共单元\uAutoUpdate.pas',
  uLogs in '..\..\Souce\公共单元\日志\uLogs.pas';

{$R *.res}
var
  HMutex : DWord;
begin
  HMutex := CreateMutex(nil, True, 'TF_Patch'); //创建Mutex句柄
  {-----检测Mutex对象是否存在，如果存在，退出程序------------}
  if (GetLastError = ERROR_ALREADY_EXISTS) then
  begin
    ReleaseMutex(hMutex); //释放Mutex对象
    Exit;
  end;
  TimeSeparator := ':';
  DateSeparator := '-';
  ShortDateFormat := 'yyyy-mm-dd';
  ShortTimeFormat := 'hh:nn:ss';
  //ReportMemoryLeaksOnShutdown := DebugHook <> 0;x
  Application.Initialize;
  Application.Title := '升级包安装';
  begin
    try
      TFrmPatch.ShowForm();
    except on e : exception do
    end;
  end;
  Application.Run;
  Application.Terminate;
end.
