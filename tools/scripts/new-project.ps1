<#
.SYNOPSIS
  이 템플릿으로 새 프로젝트 폴더를 만든다.
.EXAMPLE
  powershell -File new-project.ps1 -Name MyApp -Path D:\Projects
#>
param(
  [Parameter(Mandatory)] [string] $Name,
  [string] $Path = (Get-Location).Path
)

$ErrorActionPreference = 'Stop'
$template = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$target = Join-Path $Path $Name

if (Test-Path $target) { throw "이미 존재하는 경로: $target" }

# .git, 템플릿 전용 경로(.template-only — 목록의 유일한 원본), 훅 캐시·실행 기록은 복사하지 않는다
$listFile = Join-Path $template '.template-only'
if (-not (Test-Path $listFile)) { throw "템플릿 전용 목록이 없습니다: $listFile" }
$entries = Get-Content $listFile -Encoding UTF8 | ForEach-Object { $_.Trim() } | Where-Object { $_ -and -not $_.StartsWith('#') }
# @( )로 감싸 원소가 하나여도 배열로 유지한다 (문자열이면 @splat이 한 글자씩 넘김)
$templateOnlyDirs  = @($entries | Where-Object { $_.EndsWith('/') } | ForEach-Object { Join-Path $template $_.TrimEnd('/').Replace('/', '\') })
$templateOnlyFiles = @($entries | Where-Object { -not $_.EndsWith('/') } | ForEach-Object { Join-Path $template $_.Replace('/', '\') })
$runtimeDirs = @(Join-Path $template '.claude\metrics')
robocopy $template $target /E /XD .git @templateOnlyDirs @runtimeDirs /XF .last-pass .last-fail .template-check .template-version @templateOnlyFiles /NFL /NDL /NJH /NJS | Out-Null
if ($LASTEXITCODE -ge 8) { throw "복사 실패 (robocopy $LASTEXITCODE)" }

# 적용한 템플릿 버전 기록 (.claude/process/template-update.md)
$sha = (git -C $template rev-parse HEAD).Trim()
if (git -C $template status --porcelain) { Write-Warning "템플릿 폴더에 커밋되지 않은 변경이 있습니다. 기록되는 버전($sha)과 실제 복사된 내용이 다를 수 있습니다." }
$ver = "repo=huny4daniel/huny4daniels-TEMPLATE`ncommit=$sha`ndate=$(Get-Date -Format yyyy-MM-dd)`n"
[IO.File]::WriteAllText((Join-Path $target '.template-version'), $ver, (New-Object Text.UTF8Encoding $false))

# 프로젝트 이름 자리표시자 치환
Get-ChildItem $target -Recurse -File -Include *.md | ForEach-Object {
  $text = [IO.File]::ReadAllText($_.FullName)
  if ($text -match '\{\{PROJECT_NAME\}\}|\{\{제품 이름\}\}') {
    $text = $text -replace '\{\{PROJECT_NAME\}\}', $Name -replace '\{\{제품 이름\}\}', $Name
    [IO.File]::WriteAllText($_.FullName, $text, (New-Object Text.UTF8Encoding $false))
  }
}

Push-Location $target
try {
  git init -b main | Out-Null
  git add -A
  git commit -q -m "프로젝트 초기 구조 생성" -m "- 표준 모노레포 폴더 구조와 문서 템플릿 추가"
} finally { Pop-Location }

Write-Host "생성 완료: $target"
Write-Host "다음 단계: Claude Code에서 /kickoff 실행"
