# Opens a media session the way a player does, with a made-up track, and
# keeps it open for -Seconds: for checking on a machine with no player that
# nowspinning.exe sees the players Windows knows. Windows PowerShell 5.1
# (powershell.exe), which can reach Windows' own media types; pwsh can't.
param(
    [string] $Title = "Smoke Test",
    [string] $Artist = "NowSpinning",
    [int] $Seconds = 60
)

$ErrorActionPreference = "Stop"
$null = [Windows.Media.Playback.MediaPlayer, Windows.Media, ContentType = WindowsRuntime]
$null = [Windows.Media.MediaPlaybackStatus, Windows.Media, ContentType = WindowsRuntime]
$null = [Windows.Media.MediaPlaybackType, Windows.Media, ContentType = WindowsRuntime]

$player = New-Object Windows.Media.Playback.MediaPlayer
# Its controls are set by hand here, with nothing actually playing.
$player.CommandManager.IsEnabled = $false
$controls = $player.SystemMediaTransportControls
$controls.IsEnabled = $true
$controls.IsPlayEnabled = $true
$controls.IsPauseEnabled = $true
$controls.IsNextEnabled = $true
$controls.PlaybackStatus = [Windows.Media.MediaPlaybackStatus]::Playing
$display = $controls.DisplayUpdater
$display.Type = [Windows.Media.MediaPlaybackType]::Music
$display.MusicProperties.Title = $Title
$display.MusicProperties.Artist = $Artist
$display.Update()

Write-Host "Session open: $Title by $Artist"
Start-Sleep -Seconds $Seconds
$player.Dispose()
