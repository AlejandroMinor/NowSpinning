# A window the size of the screen, all magenta, that writes down every
# click it gets: what's behind the widget, for desktop.ps1 to look and click
# through to. Runs until closed.
param([Parameter(Mandatory)] [string] $Clicks)

Add-Type -AssemblyName System.Windows.Forms, System.Drawing
Add-Type -Namespace Win32 -Name Dpi -MemberDefinition '[DllImport("user32.dll")] public static extern bool SetProcessDPIAware();'
[void][Win32.Dpi]::SetProcessDPIAware()

$form = New-Object System.Windows.Forms.Form
$form.Text = "NowSpinning backdrop"
$form.FormBorderStyle = "None"
$form.StartPosition = "Manual"
$form.Bounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
$form.BackColor = [System.Drawing.Color]::FromArgb(255, 0, 255)
$form.ShowInTaskbar = $false
$form.Add_MouseDown({ param($sender, $e) Add-Content -Path $Clicks -Value "$($e.X),$($e.Y)" })
[System.Windows.Forms.Application]::Run($form)
