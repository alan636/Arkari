# Build Arkari LLVM Obfuscation library from source
# Uses VS 2022 DevShell for MSVC environment
$ErrorActionPreference = "Continue"

# Get script directory
$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path

# Config
$LOG = Join-Path $SCRIPT_DIR "build_log.txt"
$SRC = Join-Path $SCRIPT_DIR "llvm"
$BUILD = Join-Path $SCRIPT_DIR "build"
$PYTHON_EXEC = Join-Path (Split-Path $SCRIPT_DIR -Parent) ".conda\python.exe"

function Log($msg) {
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "[$ts] $msg" | Out-File -Append -FilePath $LOG
}

"" | Out-File -FilePath $LOG
Log "BUILD STARTED"

# Setup MSVC environment via VS DevShell
Log "Setting up VS DevShell..."
try {
    Import-Module "C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\Tools\Microsoft.VisualStudio.DevShell.dll"
    Enter-VsDevShell -VsInstallPath "C:\Program Files\Microsoft Visual Studio\2022\Community" -DevCmdArguments "-arch=x64 -host_arch=x64" -SkipAutomaticLocation *>> $LOG
    Log "VS DevShell initialized"
}
catch {
    Log "ERROR setting up VS DevShell: $_"
    exit 1
}

# Verify tools
Log "cmake: $(Get-Command cmake -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source)"
Log "ninja: $(Get-Command ninja -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source)"
Log "cl: $(Get-Command cl -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source)"

# Clean and create build directory
Log "Cleaning build directory: $BUILD"
if (Test-Path $BUILD) {
    Remove-Item -Recurse -Force $BUILD
    if (Test-Path $BUILD) {
        Log "Failed to delete build directory"
    } else {
        Log "Build directory deleted successfully"
    }
}
New-Item -ItemType Directory -Path $BUILD -Force | Out-Null

# CMake Configure
Log "Starting CMake configure..."
$cmakeArgs = @(
    "-S", $SRC,
    "-B", $BUILD,
    "-G", "Ninja",
    "-DCMAKE_BUILD_TYPE=Release",
    "-DCMAKE_CXX_FLAGS=/utf-8 /EHsc",
    "-DCMAKE_C_FLAGS=/utf-8",
    "-DLLVM_TARGETS_TO_BUILD=X86",
    "-DLLVM_BUILD_TOOLS=OFF",
    "-DLLVM_INCLUDE_TESTS=OFF",
    "-DLLVM_INCLUDE_EXAMPLES=OFF",
    "-DLLVM_INCLUDE_BENCHMARKS=OFF",
    "-DLLVM_INCLUDE_DOCS=OFF",
    "-DLLVM_ENABLE_ASSERTIONS=OFF",
    "-DPython3_EXECUTABLE=$PYTHON_EXEC"
)

& cmake @cmakeArgs *>> $LOG 2>&1
Log "CMake exit code: $LASTEXITCODE"

if (-not (Test-Path "$BUILD\build.ninja")) {
    Log "ERROR: build.ninja not found - cmake failed"
    exit 1
}
Log "CMake configure succeeded"

# Build required generated headers first
Log "Building required generated headers..."
$genVTPath = Join-Path $BUILD "include\llvm\CodeGen\GenVT.inc"
& ninja -C $BUILD $genVTPath *>> $LOG 2>&1
Log "GenVT.inc generation exit code: $LASTEXITCODE"

if (-not (Test-Path $genVTPath)) {
    Log "WARNING: GenVT.inc not found, but continuing..."
}

# Build LLVMObfuscation
Log "Building LLVMObfuscation target..."
& ninja -C $BUILD LLVMObfuscation *>> $LOG 2>&1
Log "Ninja exit code: $LASTEXITCODE"

if (Test-Path "$BUILD\lib\LLVMObfuscation.lib") {
    Log "SUCCESS: LLVMObfuscation.lib built"
}
else {
    Log "ERROR: LLVMObfuscation.lib not found"
}

Log "BUILD SCRIPT COMPLETE"
