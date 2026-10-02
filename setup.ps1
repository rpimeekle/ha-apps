<#
  One-time setup for Windows: fills in your GitHub details.

  From a VS Code PowerShell terminal, in this folder:
    .\setup.ps1 -User <github-user> [-Repo ha-apps] [-Maintainer "Your Name <you@example.com>"]

  If Windows blocks the script ("running scripts is disabled"):
    powershell -ExecutionPolicy Bypass -File .\setup.ps1 -User <github-user>
#>
param(
    [Parameter(Mandatory = $true)][string]$User,
    [string]$Repo = "ha-apps",
    [string]$Maintainer = ""
)
$ErrorActionPreference = "Stop"

if (-not $Maintainer) { $Maintainer = $User }
$UserLc  = $User.ToLower()
$Year    = (Get-Date).Year.ToString()
$Root    = $PSScriptRoot
$Utf8    = New-Object System.Text.UTF8Encoding($false)   # no BOM, keeps files Linux-friendly
$Pattern = '__GH_USER(_LC)?__|__GH_REPO__|__MAINTAINER__|__YEAR__'
$Skip    = @('setup.sh', 'setup.ps1')
$Count   = 0

Get-ChildItem -Path $Root -Recurse -File -Force |
    Where-Object {
        $_.FullName -notmatch '[\\/]\.git[\\/]' -and
        $Skip -notcontains $_.Name -and
        $_.Extension -ne '.png'
    } |
    ForEach-Object {
        $text = [System.IO.File]::ReadAllText($_.FullName)
        if ($text -match $Pattern) {
            $new = $text.Replace('__GH_USER_LC__', $UserLc).
                         Replace('__GH_USER__', $User).
                         Replace('__GH_REPO__', $Repo).
                         Replace('__MAINTAINER__', $Maintainer).
                         Replace('__YEAR__', $Year)
            [System.IO.File]::WriteAllText($_.FullName, $new, $Utf8)   # line endings untouched
            Write-Host "updated $($_.FullName.Substring($Root.Length + 1))"
            $Count++
        }
    }

if ($Count -eq 0) {
    Write-Warning "No placeholders found - this folder looks already configured."
} else {
    Write-Host ""
    Write-Host "Done ($Count files). Repository URL: https://github.com/$User/$Repo" -ForegroundColor Green
}
