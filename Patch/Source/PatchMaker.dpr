program PatchMaker;

uses
  Forms,
  SysUtils,
  Windows,
  uFrmPatchMaker in '功能窗口\生成升级包\uFrmPatchMaker.pas' {FrmPatchMaker},
  uAutoUpdate in '..\..\Souce\公共单元\uAutoUpdate.pas';

{$R *.res}
var
  HMutex : DWord;
begin
  HMutex := CreateMutex(nil, True, 'TF_PatchMaker'); //创建Mutex句柄
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
  //ReportMemoryLeaksOnShutdown := DebugHook <> 0;
  Application.Initialize;
  Application.Title := '生成升级包';
  begin
    try
      TFrmPatchMaker.ShowForm;
    except on e : exception do
    end;
  end;
  Application.Run;
  Application.Terminate;
end.
