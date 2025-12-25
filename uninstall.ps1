# PowerShell 卸载脚本：删除 ~/.claude/skills/ 下指向本项目的软链接
# 适用于 Windows 系统

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$SkillsDir = Join-Path $ScriptDir "skills"
$TargetDir = Join-Path $env:USERPROFILE ".claude\skills"

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Uninstalling Claude Skills..." -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Source: $SkillsDir"
Write-Host "Target: $TargetDir"
Write-Host ""

# 检查目标目录是否存在
if (-not (Test-Path $TargetDir)) {
    Write-Host "Target directory does not exist: $TargetDir" -ForegroundColor Yellow
    Write-Host "Nothing to uninstall."
    exit 0
}

# 检查 skills 目录是否存在
if (-not (Test-Path $SkillsDir)) {
    Write-Host "Error: Skills directory not found: $SkillsDir" -ForegroundColor Red
    exit 1
}

# 计数器
$removed = 0
$skipped = 0

# 遍历 skills 目录
Get-ChildItem -Path $SkillsDir -Directory | ForEach-Object {
    $skillName = $_.Name
    $skillPath = $_.FullName
    $targetLink = Join-Path $TargetDir $skillName

    try {
        # 检查目标是否存在
        if (Test-Path $targetLink) {
            $item = Get-Item $targetLink -Force

            if ($item.LinkType -eq "SymbolicLink" -or $item.LinkType -eq "Junction") {
                # 是符号链接或目录联接，检查是否指向本项目
                $existingTarget = $item.Target
                if ($existingTarget -eq $skillPath) {
                    Remove-Item $targetLink -Force
                    Write-Host "✓ $skillName (removed)" -ForegroundColor Green
                    $removed++
                } else {
                    Write-Host "⚠ $skillName (skipped, points to: $existingTarget)" -ForegroundColor Yellow
                    $skipped++
                }
            } else {
                # 存在但不是符号链接
                Write-Host "⚠ $skillName (skipped, not a symlink)" -ForegroundColor Yellow
                $skipped++
            }
        } else {
            # 不存在
            Write-Host "- $skillName (not installed)" -ForegroundColor Gray
        }
    } catch {
        Write-Host "✗ $skillName (error: $($_.Exception.Message))" -ForegroundColor Red
        $skipped++
    }
}

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Uninstallation Summary" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Removed: $removed"
Write-Host "Skipped: $skipped"
Write-Host ""
Write-Host "✓ Uninstallation completed" -ForegroundColor Green
