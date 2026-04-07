# Link Arkari Pass Plugin DLL
$ErrorActionPreference = "Continue"

# Get script directory
$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$LOG = Join-Path $SCRIPT_DIR "link_log.txt"

function Log($msg) {
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "[$ts] $msg" | Out-File -Append -FilePath $LOG
}

"" | Out-File -FilePath $LOG
Log "LINK STARTED"

# Setup MSVC
Import-Module "C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\Tools\Microsoft.VisualStudio.DevShell.dll"
Enter-VsDevShell -VsInstallPath "C:\Program Files\Microsoft Visual Studio\2022\Community" -DevCmdArguments "-arch=x64 -host_arch=x64" -SkipAutomaticLocation *>> $LOG
Log "MSVC setup done"

$BUILD = Join-Path $SCRIPT_DIR "build"
if (!(Test-Path $BUILD)) { New-Item -ItemType Directory -Path $BUILD | Out-Null }
$SRC = Join-Path $SCRIPT_DIR "llvm"
$PLUGIN_SRC = Join-Path $SCRIPT_DIR "src\ArkariRegistration.cpp"
$OUT = Join-Path (Split-Path $SCRIPT_DIR -Parent) "LLVMObfuscator.dll"

# Clean products before link (DLL, LIB, OBJ)
$OUT_LIB = Join-Path $BUILD "LLVMObfuscator.lib"
$OBJ = Join-Path $BUILD "ArkariRegistration.obj"
Log "Cleaning link products..."
@($OUT, $OUT_LIB, $OBJ) | ForEach-Object {
    if (Test-Path $_) {
        Remove-Item -Force $_
        if (Test-Path $_) {
            Log "Failed to delete $_"
        } else {
            Log "Deleted $_ successfully"
        }
    }
}

# Collect all LLVM static libs
$libs = Get-ChildItem "$BUILD\lib" -Filter "LLVM*.lib" | ForEach-Object { $_.FullName }
$libArgs = $libs -join ' '

Log "Found $($libs.Count) LLVM libs"
Log "Compiling and linking..."

# Compile + link in one step
$clArgs = @(
    "/nologo", "/utf-8", "/EHsc", "/std:c++17", "/O2", "/MD",
    "/I$SRC\include",
    "/I$BUILD\include",
    "/I$BUILD\include\llvm",
    "/Fo$OBJ",
    "/LD",
    $PLUGIN_SRC
)
$clArgs += $libs
$clArgs += "/link"
$clArgs += "/DLL"
$clArgs += "/OUT:$OUT"
$clArgs += "/IMPLIB:$OUT_LIB"
$clArgs += "Advapi32.lib"
$clArgs += "Shell32.lib"
$clArgs += "Ole32.lib"
$clArgs += "ntdll.lib"

Log "Running cl.exe..."
& cl @clArgs *>> $LOG 2>&1
Log "cl.exe exit code: $LASTEXITCODE"

if (Test-Path $OUT) {
    $size = (Get-Item $OUT).Length
    Log "SUCCESS: $OUT created ($size bytes)"
}
else {
    Log "ERROR: DLL not created"
}

Log "LINK COMPLETE"
