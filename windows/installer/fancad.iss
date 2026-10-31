; Inno Setup script for FanCAD Windows installer.
; AppId must stay stable across releases so upgrades overwrite the same install.
; CI passes /DMyAppVersion=x.y.z
;
; Install mode:
;   Setup runs as the invoking user (no elevation). The mode page offers
;   "for all users" (elevates, {autopf} = Program Files) and "for me only"
;   ({autopf} = %LOCALAPPDATA%\Programs). The updater passes /ALLUSERS when the
;   running copy was installed for all users, so an update replaces that copy
;   instead of creating a per-user one next to it.

#ifndef MyAppVersion
  #define MyAppVersion "0.1.0"
#endif

#define MyAppName "FanCAD"
#define MyAppPublisher "FanCAD"
#define MyAppExeName "fancad.exe"
#define MyAppId "{{857DE2DA-80D5-4A20-8C05-FA3DA844B344}}"

[Setup]
AppId={#MyAppId}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
OutputDir=..\..\dist
OutputBaseFilename=fancad-windows-setup-{#MyAppVersion}
SetupIconFile=..\runner\resources\app_icon.ico
Compression=lzma
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=commandline dialog
UninstallDisplayIcon={app}\{#MyAppExeName}

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "..\..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
; runasoriginaluser keeps FanCAD running as the desktop user when Setup was
; elevated for an all-users install.
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#MyAppName}}"; Flags: nowait postinstall skipifsilent runasoriginaluser
