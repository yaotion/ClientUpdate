unit uFrmPatch;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, Buttons, PngCustomButton, ExtCtrls, RzPanel, RzPrgres,
  RzEdit, XPMan, IniFiles, StrUtils, uAutoUpdate, uMD5, uTFSystem,uProcedureControl;

type
  TFrmPatch = class(TForm)
    RzPanel1: TRzPanel;
    Label1: TLabel;
    RzPanel2: TRzPanel;
    PngCustomButton1: TPngCustomButton;
    lblHeadInfo: TLabel;
    RzPanel3: TRzPanel;
    btnUpdate: TButton;
    btnCancel: TButton;
    prgMain: TRzProgressBar;
    Label2: TLabel;
    memInfo: TRzMemo;
    XPManifest1: TXPManifest;
    UpdateTimer: TTimer;
    lblInfo: TLabel;
    procedure FormShow(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure btnUpdateClick(Sender: TObject);
    procedure btnCancelClick(Sender: TObject);
    procedure UpdateTimerTimer(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
  private
    { Private declarations }
    //传入参数-项目版本
    m_strProjectVersion: string;
    //传入参数-可执行程序名
    m_strMainExeName: string;
    //传入参数-安装路径
    m_strSetupPath: string;

    //读写配置文件
    function ReadConfigFile(strFile, strSection, strKey: string; strDefault: string=''): string;
    procedure WriteConfigFile(strFile, strSection, strKey, strValue: string); 
    //安装升级包
    function SetupPatch(strPatchPath, strSetupPath: string): boolean;
    //从配置文件中得到要安装的文件信息
    function GetFileInfoArray(strPatchPath: string; out FileInfoArray: TRsFileInfoArray): integer;
    //将源目录下的文件复制到指定目录下
    function CopyFiles(FileInfoArray: TRsFileInfoArray; strSrcPath, strDesPath, strBakPath: string): integer;
    //
    function DeleteFiles(FileInfoArray: TRsFileInfoArray; strSrcPath: string): boolean;
    //清空指定目录下的文件
    function EmptyDir(strPath: string; bDelDir: boolean=False): boolean;    
    function EmptyDirEx(strPath: string; bDelDir: boolean=False): boolean;
    //复制文件，如果目标路径不存在，则创建
    function CopyFileWithDir(strSrcFile, strDesFile: string; bFailIfExists: boolean=True): boolean;
    procedure DeleteSelf;
  public
    { Public declarations }  
    class procedure ShowForm();
  end;

var
  FrmPatch: TFrmPatch;

implementation

{$R *.dfm}

class procedure TFrmPatch.ShowForm();
var
  strProjectVersion, strMainExeName, strSetupPath: string;
begin
  if ParamCount < 3 then Exit;
  strProjectVersion := Trim(ParamStr(1));
  strMainExeName := Trim(ParamStr(2));
  strSetupPath := Trim(ParamStr(3));
  if (strProjectVersion = '') or (strMainExeName = '') or (strSetupPath = '') then Exit;

  if FrmPatch = nil then Application.CreateForm(TFrmPatch, FrmPatch);
  FrmPatch.m_strProjectVersion := strProjectVersion;
  FrmPatch.m_strMainExeName := strMainExeName;
  FrmPatch.m_strSetupPath := strSetupPath;
  FrmPatch.Show;
end;

procedure TFrmPatch.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  //DeleteSelf; //勿用，不保险
end;

procedure TFrmPatch.FormCreate(Sender: TObject);
begin
  DoubleBuffered := true;
end;

procedure TFrmPatch.FormShow(Sender: TObject);
begin
  lblInfo.Caption := Format('版本号:%s  主程序:%s', [m_strProjectVersion, m_strMainExeName]);
  memInfo.Clear;
  UpdateTimer.Enabled := true;
end;
         
procedure TFrmPatch.UpdateTimerTimer(Sender: TObject);
begin
  UpdateTimer.Enabled := false;
  btnUpdate.Click;
end;

procedure TFrmPatch.btnUpdateClick(Sender: TObject);
var
  strPatchPath, strSetupPath: string;
  strIniFile: string;
begin
  strPatchPath := ExtractFilePath(Application.ExeName);
  strSetupPath := m_strSetupPath;
  if strPatchPath[Length(strPatchPath)] <> '\' then strPatchPath := strPatchPath + '\';
  if strSetupPath[Length(strSetupPath)] <> '\' then strSetupPath := strSetupPath + '\';
  if not DirectoryExists(strSetupPath) then CreateDir(strSetupPath);

  memInfo.Lines.Add('正在安装升级包，请稍候……');
  memInfo.Lines.Add(Format('安装路径：%s', [strSetupPath]));
  memInfo.Lines.Add('');
  memInfo.Lines.Add('即将关闭主程序进程，请稍候……');
  //强制关闭主程序进程
  CloseAllProcedure(strSetupPath + m_strMainExeName);
  Sleep(1000);

  if SetupPatch(strPatchPath, strSetupPath) then
  begin        
    memInfo.Lines.Add('更新文件完毕！');
    strIniFile := strSetupPath + 'Update.ini';
    WriteConfigFile(strIniFile, 'SysConfig', 'ProjectVersion', m_strProjectVersion);
    WriteConfigFile(strIniFile, 'SysConfig', 'MainExeName', m_strMainExeName);
  end
  else
  begin
    memInfo.Lines.Add('更新文件失败，请检查后重试！');
  end;

  //打开主程序，关闭程升级序
  if FileExists(strSetupPath + m_strMainExeName) then
  begin
    WinExec(PChar(strSetupPath + m_strMainExeName), SW_SHOW);
    Close;
  end
  else
  begin
    memInfo.Lines.Add('');
    memInfo.Lines.Add('系统没有找到可执行的主程序！！！');
  end;
end;

procedure TFrmPatch.btnCancelClick(Sender: TObject);
begin
  Close;
end;

//==============================================================================
  
function TFrmPatch.ReadConfigFile(strFile, strSection, strKey, strDefault: string): string;
var
  Ini:TIniFile;
begin
  result := strDefault;
  Ini := TIniFile.Create(strFile);
  try
    result := Ini.ReadString(strSection, strKey, strDefault);
  finally
    Ini.Free();
  end;
end;

procedure TFrmPatch.WriteConfigFile(strFile, strSection, strKey, strValue: string);
var
  Ini:TIniFile;
begin
  Ini := TIniFile.Create(strFile);
  try
    Ini.WriteString(strSection, strKey, strValue);
  finally
    Ini.Free();
  end;
end;

function TFrmPatch.SetupPatch(strPatchPath, strSetupPath: string): boolean;
var
  FileInfoArray: TRsFileInfoArray;
  strBakupPath: string;
  i, nRet: integer;
begin
  result := false;
  if strPatchPath[Length(strPatchPath)] <> '\' then strPatchPath := strPatchPath + '\';
  if strSetupPath[Length(strSetupPath)] <> '\' then strSetupPath := strSetupPath + '\';
  if not DirectoryExists(strSetupPath) then CreateDir(strSetupPath);

  if GetFileInfoArray(strPatchPath, FileInfoArray) = 0 then
  begin
    Box('没有要升级的文件，请检查后重试！');
    Exit;
  end;
  
  for i := 0 to Length(FileInfoArray) - 1 do
  begin
    if not FileExists(strPatchPath + FileInfoArray[i].strFileName) then
    begin
      Box('升级包内文件不完整，请检查后重试！');
      Exit;
    end;
  end;

  memInfo.Lines.Add('');
  memInfo.Lines.Add('开始更新文件，请稍候……');
  prgMain.TotalParts := Length(FileInfoArray);
  prgMain.PartsComplete := 0;
  Application.ProcessMessages;

  strBakupPath := strSetupPath + '_tf_bak\';
  if DirectoryExists(strBakupPath) then EmptyDir(strBakupPath, True);
  if not DirectoryExists(strBakupPath) then CreateDir(strBakupPath);
  try
    nRet := CopyFiles(FileInfoArray, strPatchPath, strSetupPath, strBakupPath);
    result := nRet=mrOk;
    if nRet = mrNone then Box('更新文件失败，请检查后重试！');
  finally
    if DirectoryExists(strBakupPath) then EmptyDir(strBakupPath, True);
    if LowerCase(RightStr(strPatchPath, 12)) = '\_tf_update\' then EmptyDirEx(strPatchPath);
  end;
end;

function TFrmPatch.GetFileInfoArray(strPatchPath: string; out FileInfoArray: TRsFileInfoArray): integer;
var
  Ini: TIniFile;
  strFile, strName, strType, strMD5: string;
  i, nLen, nFileCount: integer;
begin
  result := 0;
  strFile := strPatchPath + 'Patch.ini';
  OutputDebugString(PChar('更新配置文件地址:' + strFile));
  if not FileExists(strFile) then exit;
  Ini := TIniFile.Create(strFile);
  try
    nFileCount := Ini.ReadInteger('FileInfo', 'FileCount', 0);
    OutputDebugString(PChar('获取可更新的文件数:' + inttostr(nFileCount)));
    for i := 1 to nFileCount do
    begin
      strName := Trim(Ini.ReadString('FileName'+IntToStr(i), 'Name', ''));
      strType := Trim(Ini.ReadString('FileName'+IntToStr(i), 'Type', ''));
      strMD5 := Trim(Ini.ReadString('FileName'+IntToStr(i), 'MD5', ''));
      OutputDebugString(PChar(Format('判断可更新文件:名称=%s;类型=%s;MD5=%s',[strName,strType,strMD5]) ));
      if (strName = '') or (strType = '') or (strMD5 = '') then Continue;

      nLen := Length(FileInfoArray);
      SetLength(FileInfoArray, nLen + 1);
      FileInfoArray[nLen].strFileName := strName;
      FileInfoArray[nLen].FileType := FileTypeNameToType(strType);
      FileInfoArray[nLen].strFileMD5 := strMD5;
      FileInfoArray[nLen].bBackup := False;     
      FileInfoArray[nLen].bUpdate := False;
    end;
    result := Length(FileInfoArray);
  finally
    Ini.Free();
  end;
end;

function TFrmPatch.CopyFiles(FileInfoArray: TRsFileInfoArray; strSrcPath, strDesPath, strBakPath: string): integer;
var
  strSrcFile, strDesFile, strBakFile: string;
  strMD5, strTemp: string;
  i, n: integer;
  bNextStep: boolean;
Label
  RetryCopy, AbortCopy;
begin
  result := mrNone;

  try
    n := 0;
    for i := 0 to Length(FileInfoArray) - 1 do
    begin
      n := i;
      prgMain.PartsComplete := i;
      Application.ProcessMessages;

      strSrcFile := strSrcPath + FileInfoArray[i].strFileName;
      strDesFile := strDesPath + FileInfoArray[i].strFileName;
      strBakFile := strBakPath + FileInfoArray[i].strFileName;
      if not FileExists(strSrcFile) then Continue;
      if FileExists(strDesFile) then
      begin
        if FileInfoArray[i].FileType = ftDBFile then Continue;
        strMD5 := RivestFile(strDesFile);
        if FileInfoArray[i].strFileMD5 = strMD5 then Continue;
        FileInfoArray[i].bBackup := CopyFileWithDir(PChar(strDesFile), PChar(strBakFile), false);
      end;

RetryCopy:
      if FileExists(strDesFile) then FileSetAttr(strDesFile, 0);
      if not CopyFileWithDir(PChar(strSrcFile), PChar(strDesFile), false) then
      begin
        strTemp := '更新文件失败，请检查目标文件是否占用，是否继续操作？'#13#10#13#10+Format('目标文件：%s', [strDesFile]);
        case Application.MessageBox(PChar(strTemp), '询问', MB_ABORTRETRYIGNORE + MB_ICONQUESTION) of
          mrAbort: goto AbortCopy; //撤消安装
          mrRetry: goto RetryCopy; //重试
          mrIgnore: Continue;
        end;
      end;
      FileInfoArray[i].bUpdate := True;
      memInfo.Lines.Add(Format('更新文件：%s', [strDesFile]));
    end;
    prgMain.PartsComplete := i; 
    Application.ProcessMessages;
    result := mrOk;
    Exit;

AbortCopy:
    result := mrAbort;
    for i := n downto 0 do
    begin
      prgMain.PartsComplete := i;
      Application.ProcessMessages;
      bNextStep := FileInfoArray[i].bUpdate and FileInfoArray[i].bBackup;
      FileInfoArray[i].bUpdate := False;
      FileInfoArray[i].bBackup := False;
      if not bNextStep then Continue;
      
      strDesFile := strDesPath + FileInfoArray[i].strFileName;
      strBakFile := strBakPath + FileInfoArray[i].strFileName;
      if not FileExists(strBakFile) then Continue;
      if FileExists(strDesFile) then FileSetAttr(strDesFile, 0);
      CopyFile(PChar(strBakFile), PChar(strDesFile), false);
    end;
    prgMain.PartsComplete := i; 
    Application.ProcessMessages;
  except
  end;
end;
      
function TFrmPatch.DeleteFiles(FileInfoArray: TRsFileInfoArray; strSrcPath: string): boolean;
var
  strSrcFile: string;
  i: integer;
begin
  result := True;
  try
    for i := 0 to Length(FileInfoArray) - 1 do
    begin
      strSrcFile := strSrcPath + FileInfoArray[i].strFileName;
      if not FileExists(strSrcFile) then Continue;
      if LowerCase(strSrcFile) = LowerCase(Application.ExeName) then Continue;
      FileSetAttr(strSrcFile, 0);
      result := result and DeleteFile(strSrcFile);
    end;
  except
  end;
end;

function TFrmPatch.EmptyDir(strPath: string; bDelDir: boolean): boolean;
var
  SearchRec: TSearchRec;
  strFile: string;
begin
  result := true;
  if strPath[Length(strPath)] <> '\' then strPath := strPath + '\';

  try
    if FindFirst(strPath+'*.*', faAnyFile, SearchRec) = 0 then
    begin
      repeat
        if SearchRec.Name = '.' then continue;
        if SearchRec.Name = '..' then continue;
        
        strFile := strPath + SearchRec.Name;
        if (SearchRec.Attr and faDirectory) = faDirectory then
        begin
          EmptyDir(strFile, true);
        end
        else
        begin
          FileSetAttr(strFile, 0);
          result := result and DeleteFile(strFile);
        end;
      until FindNext(SearchRec) <> 0;
    end;
    FindClose(SearchRec);
    if bDelDir then result := result and RemoveDir(strPath);
  except
    result := false;
  end;
end;
        
function TFrmPatch.EmptyDirEx(strPath: string; bDelDir: boolean): boolean;
var
  SearchRec: TSearchRec;
  strFile: string;
begin
  result := true;
  if strPath[Length(strPath)] <> '\' then strPath := strPath + '\';

  try
    if FindFirst(strPath+'*.*', faAnyFile, SearchRec) = 0 then
    begin
      repeat
        if SearchRec.Name = '.' then continue;
        if SearchRec.Name = '..' then continue;
        
        strFile := strPath + SearchRec.Name;
        if (SearchRec.Attr and faDirectory) = faDirectory then
        begin
          EmptyDir(strFile, true);
        end
        else
        begin
          if LowerCase(strFile) = LowerCase(Application.ExeName) then Continue;
          FileSetAttr(strFile, 0);
          result := result and DeleteFile(strFile);
        end;
      until FindNext(SearchRec) <> 0;
    end;
    FindClose(SearchRec);
    if bDelDir then result := result and RemoveDir(strPath);
  except
    result := false;
  end;
end;

function TFrmPatch.CopyFileWithDir(strSrcFile, strDesFile: string; bFailIfExists: boolean=True): boolean;
var
  strPath: string;
begin
  strPath := ExtractFilePath(strDesFile);
  if not DirectoryExists(strPath) then ForceDirectories(strPath);
  result := CopyFile(PChar(strSrcFile), PChar(strDesFile), bFailIfExists);
end;

procedure TFrmPatch.DeleteSelf;
var
  BatFile: TextFile;
  strBatFile: string;
  ProcessInfo: TProcessInformation;
  StartUpInfo: TStartupInfo;
begin
  strBatFile := ChangeFileExt(Paramstr(0), '.bat');
  AssignFile(BatFile, strBatFile);
  Rewrite(BatFile);
  //生成批处理命令
  Writeln(BatFile, ':try');
  Writeln(BatFile, Format('del "%s"', [ParamStr(0)]));
  Writeln(BatFile, Format('if exist "%s" goto try', [ParamStr(0)]));
  Writeln(BatFile, 'del %0');
  CloseFile(BatFile);

  FillChar(StartUpInfo, SizeOf(StartUpInfo), $00);
  StartUpInfo.dwFlags := STARTF_USESHOWWINDOW;
  StartUpInfo.wShowWindow := SW_HIDE;
  // create hidden process
  if CreateProcess(nil,PChar(strBatFile),nil,nil,False,IDLE_PRIORITY_CLASS,nil,nil,StartUpInfo,ProcessInfo) then
  begin
   CloseHandle(ProcessInfo.hThread);
   CloseHandle(ProcessInfo.hProcess);
  end;
end;

end.
