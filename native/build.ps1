# 构建 speex 编码 DLL（Windows x64）
#
# 需要 Visual Studio 2022/2026 Build Tools 的 C++ 编译器（cl.exe）。
# 在 "Developer PowerShell for VS" 中运行：
#   pwsh -File native/build.ps1
#
# 产物：assets/native/ets_speex.dll
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$spx = Join-Path $PSScriptRoot 'speex'
$outDir = Join-Path $root 'assets/native'
$objDir = Join-Path $root 'build/native'
New-Item -ItemType Directory -Force -Path $outDir, $objDir | Out-Null

if (-not (Get-Command cl.exe -ErrorAction SilentlyContinue)) {
    throw '找不到 cl.exe，请在 "Developer PowerShell for VS" 中运行本脚本'
}

$sources = Get-ChildItem (Join-Path $spx 'libspeex') -Filter *.c | ForEach-Object { $_.FullName }
$args = @(
    '/nologo', '/LD', '/O2', '/D_CRT_SECURE_NO_WARNINGS', '/DHAVE_CONFIG_H', '/utf-8',
    '/I', (Join-Path $spx 'include'),
    '/I', (Join-Path $spx 'libspeex'),
    (Join-Path $PSScriptRoot 'ets_speex.cpp')
) + $sources + @(
    "/Fe:$outDir\ets_speex.dll",
    "/Fo:$objDir\"
)
Push-Location $objDir
try {
    & cl.exe @args
    if ($LASTEXITCODE -ne 0) { throw "cl.exe 失败：exit=$LASTEXITCODE" }
} finally {
    Pop-Location
}
Write-Host "已生成 $outDir\ets_speex.dll" -ForegroundColor Green

