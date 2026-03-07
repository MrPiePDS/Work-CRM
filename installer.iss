; ─────────────────────────────────────────────────────────────────────────────
; Client Manager CRM — Inno Setup Script
; Build with: ISCC.exe installer.iss
; Output: dist\ClientManager_Setup.exe
; ─────────────────────────────────────────────────────────────────────────────

#define AppName      "Client Manager"
#define AppVersion   "1.2.2"
#define AppPublisher "Mr.Pie"
#define AppExeName   "crm_flutter.exe"
#define AppBuildDir  "build\windows\x64\runner\Release"

[Setup]
AppId={{6A3F2B1C-4D8E-4F9A-B2C3-1A2B3C4D5E6F}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
AppPublisherURL=https://github.com/MrPiePDS/Work-CRM
AppSupportURL=https://github.com/MrPiePDS/Work-CRM/issues
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
OutputDir=dist
OutputBaseFilename=ClientManager_Setup
SetupIconFile=windows\runner\resources\app_icon.ico
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
; No admin rights required — installs per-user by default
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
; Minimum Windows 10
MinVersion=10.0

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a &desktop shortcut"; GroupDescription: "Additional icons:"; Flags: unchecked

[Files]
; Copy the entire Release folder contents
Source: "{#AppBuildDir}\{#AppExeName}";          DestDir: "{app}"; Flags: ignoreversion
Source: "{#AppBuildDir}\flutter_windows.dll";     DestDir: "{app}"; Flags: ignoreversion
Source: "{#AppBuildDir}\sqlite3.dll";             DestDir: "{app}"; Flags: ignoreversion
Source: "{#AppBuildDir}\pdfium.dll";              DestDir: "{app}"; Flags: ignoreversion
Source: "{#AppBuildDir}\printing_plugin.dll";     DestDir: "{app}"; Flags: ignoreversion
Source: "{#AppBuildDir}\screen_retriever_windows_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#AppBuildDir}\window_manager_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#AppBuildDir}\file_picker_windows.dll"; DestDir: "{app}"; Flags: ignoreversion skipifsourcedoesntexist
; Flutter assets (fonts, shaders, etc.)
Source: "{#AppBuildDir}\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
; Start Menu shortcut
Name: "{group}\{#AppName}";         Filename: "{app}\{#AppExeName}"; IconFilename: "{app}\{#AppExeName}"
Name: "{group}\Uninstall {#AppName}"; Filename: "{uninstallexe}"
; Desktop shortcut (optional, user must tick the checkbox)
Name: "{autodesktop}\{#AppName}";   Filename: "{app}\{#AppExeName}"; IconFilename: "{app}\{#AppExeName}"; Tasks: desktopicon

[Run]
; Offer to launch the app immediately after install
Filename: "{app}\{#AppExeName}"; Description: "Launch {#AppName}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
; Remove any leftover files on uninstall
Type: filesandordirs; Name: "{app}"
