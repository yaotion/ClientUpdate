unit uLogs;

interface

uses
  Classes,SysUtils,DateUtils,Windows,Forms;

type
  TLog = class
  public
    class procedure SaveLog(LogDate : TDateTime; logContent:string);
  end;
var
  LogCriticalSection : TRTLCriticalSection;
implementation

{ TLog }

class procedure TLog.SaveLog(LogDate: TDateTime; logContent: string);
var
  logPath,fileName : string;
  fs:TFileStream;
  sp : array[0..1] of char;
  strTemp : string;
begin
  EnterCriticalSection(LogCriticalSection);
  try
    strTemp := '<' + FormatDateTime('yyyy-mm-dd HH:nn:ss',logDate) +'>' + logContent;
    logPath := ExtractFilePath(Application.ExeName);
    logPath := logPath + 'logs\';
    if not DirectoryExists(logPath) then
    begin
      ForceDirectories(logPath);
    end;
    fileName := logPath + FormatDateTime('yyyymmdd',logDate) + '.txt';
    if not FileExists(fileName) then
    begin
      fs := TFileStream.Create(fileName,fmCreate)
    end
    else begin
      fs := TFileStream.Create(fileName,fmOpenWrite);
    end;
    try
      sp[0] :=  #13;
      sp[1] :=  #10;
      fs.Seek(fs.Size,0)  ;
      fs.Write(sp,length(sp));


      fs.Seek(fs.Size,0)  ;
      fs.Write(strTemp[1],length(strTemp));
    finally
      if Assigned(fs) then
        fs.Free;
    end;
  finally
    LeaveCriticalSection(LogCriticalSection);
  end;
end;


initialization
  InitializeCriticalSection(LogCriticalSection);
finalization
  DeleteCriticalSection(LogCriticalSection);
end.
