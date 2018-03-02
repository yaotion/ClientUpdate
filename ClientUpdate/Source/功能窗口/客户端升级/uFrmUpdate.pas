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
    //����������Ϣ
    m_UpdateConfig : RRsUpdateConfig;
    //������Ϣ
    m_UpdateInfo: RRsUpdateInfo;
    //��ʼ����
    function BeginUpdate(var strPatchFile: string): boolean;
    //�����ļ������������ļ�·��
    function DownloadFile(strUrl: string): string;
    //��ѹ�ļ������ؽ�ѹ�ļ�·��
    function UnzipFileToDir(strZipFile: string): string;
    //��������
    procedure ExecuteMainFile();
    //����������
    function ExecutePatchFile(strPatchFile: string): boolean;
    //���ָ��Ŀ¼�µ��ļ�
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
  memInfo.Lines.Add('��ǰ���õ�������������£�');
  memInfo.Lines.Add(Format('������ַ��%s', [m_UpdateConfig.APIUrl]));
  memInfo.Lines.Add(Format('�� Ŀ ID��%s', [m_UpdateConfig.ProjectID]));
  memInfo.Lines.Add(Format('�� �� �ţ�%s', [m_UpdateConfig.ProjectVersion]));
  memInfo.Lines.Add(Format('�� �� ����%s', [m_UpdateConfig.MainExeName]));
  memInfo.Lines.Add('');
  memInfo.Lines.Add('���ڲ��ҷ������Ƿ���ڿ������������Ժ򡭡�');

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
      memInfo.Lines.Add('��ȡ������Ϣʧ��');
      exit;
    end;
    if not  m_UpdateInfo.bNeedUpdate then
    begin
      memInfo.Lines.Add('ϵͳû���ҵ��°��������');
      exit;
    end;
    //��ѯ�������Ƿ���������
    memInfo.Lines.Add('���������ڿ����������������£�');
    memInfo.Lines.Add(Format('�汾�ţ�%s', [m_UpdateInfo.strProjectVersion]));
    memInfo.Lines.Add(Format('��  ����%s', [m_UpdateInfo.strUpdateBrief]));
    memInfo.Lines.Add(Format('��������%s', [m_UpdateInfo.strPackageUrl])); //===����ɾ��
    memInfo.Lines.Add(Format('��������%s', [m_UpdateInfo.strMainExeName])); //===����ɾ��
    Application.ProcessMessages;

    if m_UpdateInfo.strProjectVersion = '' then
    begin
      Box('�������İ汾�Ų���Ϊ�գ����������');
      Exit;
    end;
    if m_UpdateInfo.strMainExeName = '' then
    begin
      Box('�������ĳ���������Ϊ�գ����������');
      Exit;
    end;
    if m_UpdateInfo.strPackageUrl = '' then
    begin
      Box('�����������ص�ַ����Ϊ�գ����������');
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
                        
  lblProgress.Caption := '���ؽ��ȣ�';
  memInfo.Lines.Add('');
  memInfo.Lines.Add('��ʼ�����ļ�����');
  Application.ProcessMessages;
  try
    Stream := TMemoryStream.Create;
    IdHTTP := TIdHTTP.Create(nil);
    try
      //����������
      IdHTTP.OnWork := IdHTTPWork;
      IdHTTP.OnWorkBegin := IdHTTPWorkBegin;
      IdHTTP.ReadTimeout := 3000;
      IdHTTP.ConnectTimeout := 3000;
      IdHTTP.Get(strUrl, Stream);
      Stream.SaveToFile(strUpdateFile);

      result := strUpdateFile;     
      memInfo.Lines.Add('�����ļ��ɹ�'); 
      Application.ProcessMessages;
    finally           
      Stream.Free;
      IdHTTP.Disconnect;
      IdHTTP.Free;
    end;
  except on e : exception do
    Box('�����ļ��쳣����������ԣ�'#13#10#13#10'���ص�ַ��'+strUrl+#13#10#13#10+e.Message);
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

  lblProgress.Caption := '��ѹ���ȣ�';
  memInfo.Lines.Add('');
  memInfo.Lines.Add('��ѹ��ʼ�����Ժ򡭡�');
  Application.ProcessMessages;
  try
    VCLZip.OverwriteMode:=Always; //���Ǹ���ģʽ
    VCLZip.Recurse := True; //�����¼�Ŀ¼�е��ļ�
    VCLZip.RelativePaths := True; //�Ƿ񱣳�Ŀ¼�ṹ
    VCLZip.StorePaths := True; //������Ŀ¼��Ϣ
    VCLZip.RecreateDirs := True; //����Ŀ¼
    VCLZip.Password := '';

    VCLZip.FilesList.Clear;
    VCLZip.FilesList.Add('*.*');

    VCLZip.DestDir := strUnzipPath;
    VCLZip.ZipName := strZipFile;
    nFileCount := VCLZip.UnZip;

    result := strUnzipPath;
    memInfo.Lines.Add(Format('��ѹ��ϣ�����%d���ļ�', [nFileCount]));
  except on e : exception do
    Box('��ѹ�������쳣����������ԣ�'#13#10#13#10'�쳣��Ϣ��'+e.Message);
  end;
  Application.ProcessMessages;
end;

procedure TFrmUpdate.ExecuteMainFile();
var
  strPath, strMainExeName: string;
begin
  strMainExeName := m_UpdateConfig.MainExeName;
  if Pos('.', strMainExeName) = 0 then strMainExeName := strMainExeName + '.exe';
  
  //�жϱ����Ƿ���ڿ�ִ�г���
  strPath := ExtractFilePath(Application.ExeName);
  if FileExists(strPath + strMainExeName) then
  begin
    WinExec(PChar(strPath + strMainExeName+ ' ' + paramstr(1)) , SW_SHOW);
  end; 
  Close; //�������򣬹رճ�������
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
    Close; //���������򣬹رճ�������
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
