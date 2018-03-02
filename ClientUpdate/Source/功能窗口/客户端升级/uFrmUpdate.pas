unit uFrmUpdate;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, Buttons, PngCustomButton, ExtCtrls, RzPanel, RzPrgres,
  IdBaseComponent, IdComponent, IdTCPConnection, IdTCPClient, IdHTTP, RzEdit,
  XPMan, IniFiles, VCLUnZip, VCLZip, superobject, uAutoUpdate, uTFSystem;

type
  TFrmUpdate = class(TForm)
    RzPanel1: TRzPanel;
    Label1: TLabel;
    RzPanel2: TRzPanel;
    PngCustomButton1: TPngCustomButton;
    lblHeadInfo: TLabel;
    prgMain: TRzProgressBar;
    lblProgress: TLabel;
    memInfo: TRzMemo;
    XPManifest1: TXPManifest;
    UpdateTimer: TTimer;
    VCLZip: TVCLZip;
    procedure FormShow(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure IdHTTPWork(ASender: TObject; AWorkMode: TWorkMode; AWorkCount: Integer);
    procedure IdHTTPWorkBegin(ASender: TObject; AWorkMode: TWorkMode; AWorkCountMax: Integer);
    procedure UpdateTimerTimer(Sender: TObject);
    procedure VCLZipTotalPercentDone(Sender: TObject; Percent: Integer);
  private
    { Private declarations }
    //更新配置信息
    m_UpdateConfig : RRsUpdateConfig;
    //升级信息
    m_UpdateInfo: RRsUpdateInfo;
    //开始升级
    function BeginUpdate(var strPatchFile: string): boolean;
    //下载文件，返回下载文件路径
    function DownloadFile(strUrl: string): string;
    //解压文件，返回解压文件路径
    function UnzipFileToDir(strZipFile: string): string;
    //打开主程序
    procedure ExecuteMainFile();
    //打开升级程序
    function ExecutePatchFile(strPatchFile: string): boolean;
    //清空指定目录下的文件
    function EmptyDir(strPath: string; bDelDir: boolean=false): boolean;
  public
    { Public declarations }  
    class procedure ShowForm;
  end;

var
  FrmUpdate: TFrmUpdate;

implementation

{$R *.dfm}
       
class procedure TFrmUpdate.ShowForm;
begin
  if FrmUpdate = nil then Application.CreateForm(TFrmUpdate, FrmUpdate);
  FrmUpdate.Show;
end;

procedure TFrmUpdate.FormCreate(Sender: TObject);
begin
  DoubleBuffered := true;
end;

procedure TFrmUpdate.FormShow(Sender: TObject);
begin
  TAutoUpdateUtils.GetUpdateConfig(ExtractFilePath(Application.ExeName) + 'Update.ini',m_UpdateConfig);
  memInfo.Clear;
  memInfo.Lines.Add('当前在用的软件，详情如下：');
  memInfo.Lines.Add(Format('升级地址：%s', [m_UpdateConfig.APIUrl]));
  memInfo.Lines.Add(Format('项 目 ID：%s', [m_UpdateConfig.ProjectID]));
  memInfo.Lines.Add(Format('版 本 号：%s', [m_UpdateConfig.ProjectVersion]));
  memInfo.Lines.Add(Format('程 序 名：%s', [m_UpdateConfig.MainExeName]));
  memInfo.Lines.Add('');
  memInfo.Lines.Add('正在查找服务器是否存在可升级包，请稍候……');

  UpdateTimer.Enabled := true;
end;
         
procedure TFrmUpdate.UpdateTimerTimer(Sender: TObject);
var
  strPatchFile: string;
  bUpdate: boolean;
begin
  UpdateTimer.Enabled := false;
                  
  strPatchFile := '';
  bUpdate := False;
  try
    if not TAutoUpdateUtils.GetUpdateInfo(m_UpdateConfig.APIUrl,m_UpdateConfig.ProjectID,
      m_UpdateConfig.ProjectVersion,m_UpdateInfo) then
    begin
      memInfo.Lines.Add('获取更新信息失败');
      exit;
    end;
    if not  m_UpdateInfo.bNeedUpdate then
    begin
      memInfo.Lines.Add('系统没有找到新版的升级包');
      exit;
    end;
    //查询服务器是否有升级包
    memInfo.Lines.Add('服务器存在可升级包，详情如下：');
    memInfo.Lines.Add(Format('版本号：%s', [m_UpdateInfo.strProjectVersion]));
    memInfo.Lines.Add(Format('描  述：%s', [m_UpdateInfo.strUpdateBrief]));
    memInfo.Lines.Add(Format('升级包：%s', [m_UpdateInfo.strPackageUrl])); //===后期删除
    memInfo.Lines.Add(Format('程序名：%s', [m_UpdateInfo.strMainExeName])); //===后期删除
    Application.ProcessMessages;

    if m_UpdateInfo.strProjectVersion = '' then
    begin
      Box('升级包的版本号不能为空，请检查后重试');
      Exit;
    end;
    if m_UpdateInfo.strMainExeName = '' then
    begin
      Box('升级包的程序名不能为空，请检查后重试');
      Exit;
    end;
    if m_UpdateInfo.strPackageUrl = '' then
    begin
      Box('升级包的下载地址不能为空，请检查后重试');
      Exit;
    end;      
    bUpdate := BeginUpdate(strPatchFile);
  finally
    if bUpdate then bUpdate := ExecutePatchFile(strPatchFile);
    if not bUpdate then ExecuteMainFile;
  end;
end;

procedure TFrmUpdate.VCLZipTotalPercentDone(Sender: TObject; Percent: Integer);
begin
  prgMain.PartsComplete := Percent * prgMain.TotalParts div 100;
  Application.ProcessMessages;
end;

procedure TFrmUpdate.IdHTTPWork(ASender: TObject; AWorkMode: TWorkMode; AWorkCount: Integer);
begin
  prgMain.PartsComplete := AWorkCount;
end;

procedure TFrmUpdate.IdHTTPWorkBegin(ASender: TObject; AWorkMode: TWorkMode; AWorkCountMax: Integer);
begin
  prgMain.TotalParts := AWorkCountMax;
  prgMain.PartsComplete := 0;
end;

function TFrmUpdate.BeginUpdate(var strPatchFile: string): boolean;
var
  strUpdateFile, strUnzipPath: string;
begin
  result := False;
  
  if m_UpdateInfo.bNeedUpdate then
  begin
    strUpdateFile := DownloadFile(m_UpdateInfo.strPackageUrl);
    if strUpdateFile <> '' then
    begin
      strUnzipPath := UnzipFileToDir(strUpdateFile);
      if strUnzipPath <> '' then
      begin
        strPatchFile := strUnzipPath + 'Patch.exe';
        result := True;
      end;
    end;
  end;
end;

function TFrmUpdate.DownloadFile(strUrl: string): string;
var
  IdHTTP: TIdHTTP;
  Stream: TMemoryStream;
  strUpdateFile: string;
begin
  result := '';
  strUpdateFile := ExtractFilePath(Application.ExeName) + 'Update.rar';
  if FileExists(strUpdateFile) then if not DeleteFile(strUpdateFile) then exit;
                        
  lblProgress.Caption := '下载进度：';
  memInfo.Lines.Add('');
  memInfo.Lines.Add('开始下载文件……');
  Application.ProcessMessages;
  try
    Stream := TMemoryStream.Create;
    IdHTTP := TIdHTTP.Create(nil);
    try
      //下载升级包
      IdHTTP.OnWork := IdHTTPWork;
      IdHTTP.OnWorkBegin := IdHTTPWorkBegin;
      IdHTTP.ReadTimeout := 3000;
      IdHTTP.ConnectTimeout := 3000;
      IdHTTP.Get(strUrl, Stream);
      Stream.SaveToFile(strUpdateFile);

      result := strUpdateFile;     
      memInfo.Lines.Add('下载文件成功'); 
      Application.ProcessMessages;
    finally           
      Stream.Free;
      IdHTTP.Disconnect;
      IdHTTP.Free;
    end;
  except on e : exception do
    Box('下载文件异常，请检查后重试！'#13#10#13#10'下载地址：'+strUrl+#13#10#13#10+e.Message);
  end;
end;

function TFrmUpdate.UnzipFileToDir(strZipFile: string): string;
var
  strUnzipPath: string;
  nFileCount: integer;
begin
  result := '';
  if not FileExists(strZipFile) then exit;
  strUnzipPath := ExtractFilePath(Application.ExeName) + '_tf_update\';
  if not DirectoryExists(strUnzipPath) then CreateDir(strUnzipPath);
  if not EmptyDir(strUnzipPath) then exit;

  lblProgress.Caption := '解压进度：';
  memInfo.Lines.Add('');
  memInfo.Lines.Add('解压开始，请稍候……');
  Application.ProcessMessages;
  try
    VCLZip.OverwriteMode:=Always; //总是覆盖模式
    VCLZip.Recurse := True; //包含下级目录中的文件
    VCLZip.RelativePaths := True; //是否保持目录结构
    VCLZip.StorePaths := True; //不保存目录信息
    VCLZip.RecreateDirs := True; //创建目录
    VCLZip.Password := '';

    VCLZip.FilesList.Clear;
    VCLZip.FilesList.Add('*.*');

    VCLZip.DestDir := strUnzipPath;
    VCLZip.ZipName := strZipFile;
    nFileCount := VCLZip.UnZip;

    result := strUnzipPath;
    memInfo.Lines.Add(Format('解压完毕，共有%d个文件', [nFileCount]));
  except on e : exception do
    Box('解压升级包异常，请检查后重试！'#13#10#13#10'异常信息：'+e.Message);
  end;
  Application.ProcessMessages;
end;

procedure TFrmUpdate.ExecuteMainFile();
var
  strPath, strMainExeName: string;
begin
  strMainExeName := m_UpdateConfig.MainExeName;
  if Pos('.', strMainExeName) = 0 then strMainExeName := strMainExeName + '.exe';
  
  //判断本地是否存在可执行程序
  strPath := ExtractFilePath(Application.ExeName);
  if FileExists(strPath + strMainExeName) then
  begin
    WinExec(PChar(strPath + strMainExeName+ ' ' + paramstr(1)) , SW_SHOW);
  end; 
  Close; //打开主程序，关闭程升级序
end;

function TFrmUpdate.ExecutePatchFile(strPatchFile: string): boolean;
var
  strProjectVersion, strMainExeName, strSetupPath: string;
  strParam: string;
begin
  result := False;
  try
    if not FileExists(strPatchFile) then Exit;
                                      
    strSetupPath := ExtractFilePath(Application.ExeName);
    strProjectVersion := m_UpdateInfo.strProjectVersion;
    strMainExeName := m_UpdateInfo.strMainExeName;
    if strMainExeName = '' then strMainExeName := m_UpdateConfig.MainExeName;
    if strMainExeName <> '' then
    begin
      if Pos('.', strMainExeName) = 0 then strMainExeName := strMainExeName + '.exe';
    end;

    strParam := Format(' %s %s %s', [strProjectVersion, strMainExeName, strSetupPath]);
    WinExec(PChar(strPatchFile + strParam), SW_SHOW); 
    result := True;
  finally
    Close; //打开升级程序，关闭程升级序
  end;
end;


function TFrmUpdate.EmptyDir(strPath: string; bDelDir: boolean): boolean;
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

end.
