# PowerShell 安装脚本：将项目 skills 目录下的所有 skill 软链接到 ~/.claude/skills/
# 适用于 Windows 系统

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$SkillsDir = Join-Path $ScriptDir "skills"
$TargetDir = Join-Path $env:USERPROFILE ".claude\skills"

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Installing Claude Skills..." -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Source: $SkillsDir"
Write-Host "Target: $TargetDir"
Write-Host ""

# 检查是否以管理员权限运行（Windows 创建符号链接需要管理员权限或开发者模式）
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "Warning: Creating symbolic links on Windows may require:" -ForegroundColor Yellow
    Write-Host "  1. Administrator privileges, OR" -ForegroundColor Yellow
    Write-Host "  2. Developer Mode enabled in Windows Settings" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "If this script fails, please:" -ForegroundColor Yellow
    Write-Host "  - Run PowerShell as Administrator, OR" -ForegroundColor Yellow
    Write-Host "  - Enable Developer Mode: Settings > Update & Security > For developers" -ForegroundColor Yellow
    Write-Host ""
    $response = Read-Host "Continue anyway? (y/n)"
    if ($response -ne 'y' -and $response -ne 'Y') {
        Write-Host "Installation cancelled." -ForegroundColor Yellow
        exit 0
    }
    Write-Host ""
}

# 确保目标目录存在
if (-not (Test-Path $TargetDir)) {
    Write-Host "Creating target directory: $TargetDir"
    New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null
}

# 检查 skills 目录是否存在
if (-not (Test-Path $SkillsDir)) {
    Write-Host "Error: Skills directory not found: $SkillsDir" -ForegroundColor Red
    exit 1
}

# 计数器
$installed = 0
$skipped = 0
$errors = 0

# 遍历 skills 目录
Get-ChildItem -Path $SkillsDir -Directory | ForEach-Object {
    $skillName = $_.Name
    $skillPath = $_.FullName
    $targetLink = Join-Path $TargetDir $skillName

    try {
        # 检查目标是否已存在
        if (Test-Path $targetLink) {
            $item = Get-Item $targetLink -Force

            if ($item.LinkType -eq "SymbolicLink" -or $item.LinkType -eq "Junction") {
                # 已存在符号链接或目录联接
                $existingTarget = $item.Target
                if ($existingTarget -eq $skillPath) {
                    Write-Host "✓ $skillName (already installed)" -ForegroundColor Green
                    $skipped++
                } else {
                    Write-Host "⚠ $skillName (exists, pointing to: $existingTarget)" -ForegroundColor Yellow
                    Write-Host "  Run uninstall.ps1 first to remove existing links" -ForegroundColor Yellow
                    $errors++
                }
            } else {
                # 存在但不是符号链接
                Write-Host "⚠ $skillName (exists as regular file/directory)" -ForegroundColor Yellow
                Write-Host "  Please remove manually: $targetLink" -ForegroundColor Yellow
                $errors++
            }
        } else {
            # 创建新符号链接
            New-Item -ItemType SymbolicLink -Path $targetLink -Target $skillPath -Force | Out-Null
            Write-Host "✓ $skillName (installed)" -ForegroundColor Green
            $installed++
        }
    } catch {
        Write-Host "✗ $skillName (error: $($_.Exception.Message))" -ForegroundColor Red
        $errors++
    }
}

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Installation Summary" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Installed: $installed"
Write-Host "Skipped:   $skipped"
Write-Host "Errors:    $errors"
Write-Host ""

if ($errors -gt 0) {
    Write-Host "⚠ Installation completed with errors" -ForegroundColor Yellow
    exit 1
} elseif ($installed -eq 0 -and $skipped -gt 0) {
    Write-Host "✓ All skills already installed" -ForegroundColor Green
} else {
    Write-Host "✓ Installation completed successfully" -ForegroundColor Green
}
