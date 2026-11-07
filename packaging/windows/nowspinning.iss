; The installer: iscc /DAppVersion=1.2.3 packaging\windows\nowspinning.iss, after build.ps1.
; It installs for this user alone, so it asks for no administrator.
#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif

[Setup]
AppId={{3F6E2A9B-8C1D-4E57-A0B4-5D7C19E2F864}
AppName=NowSpinning
AppVersion={#AppVersion}
AppPublisher=Alejandro Minor
AppPublisherURL=https://github.com/AlejandroMinor/NowSpinning
DefaultDirName={autopf}\NowSpinning
DisableProgramGroupPage=yes
DisableDirPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
; Windows 10 1809: the first with the media controls it reads the players from.
MinVersion=10.0.17763
OutputDir=..\..\dist
OutputBaseFilename=NowSpinning-{#AppVersion}-setup
SetupIconFile=nowspinning.ico
UninstallDisplayIcon={app}\nowspinning.exe
DisableReadyPage=yes
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
CloseApplications=yes

[Tasks]
Name: "startup"; Description: "Start NowSpinning with Windows"
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "..\..\dist\NowSpinning\*"; DestDir: "{app}"; Flags: recursesubdirs ignoreversion

[Icons]
Name: "{autoprograms}\NowSpinning"; Filename: "{app}\nowspinning.exe"; AppUserModelID: "AlejandroMinor.NowSpinning"
Name: "{autodesktop}\NowSpinning"; Filename: "{app}\nowspinning.exe"; AppUserModelID: "AlejandroMinor.NowSpinning"; Tasks: desktopicon
Name: "{userstartup}\NowSpinning"; Filename: "{app}\nowspinning.exe"; Tasks: startup

[Run]
Filename: "{app}\nowspinning.exe"; Description: "{cm:LaunchProgram,NowSpinning}"; Flags: nowait postinstall skipifsilent

[UninstallRun]
Filename: "{app}\nowspinning.exe"; Parameters: "--quit"; Flags: runhidden waituntilterminated; RunOnceId: "QuitNowSpinning"

[UninstallDelete]
Type: filesandordirs; Name: "{app}\nowspinning"
Type: filesandordirs; Name: "{app}\qml"

[Code]
// A widget already running is closed before its files are replaced.
function PrepareToInstall(var NeedsRestart: Boolean): String;
var
  Code: Integer;
begin
  if FileExists(ExpandConstant('{app}\nowspinning.exe')) then
    Exec(ExpandConstant('{app}\nowspinning.exe'), '--quit', '', SW_HIDE, ewWaitUntilTerminated, Code);
  Result := '';
end;
