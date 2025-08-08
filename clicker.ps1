function Write-Colored {
    param(
        [string]$Text,
        [string]$Color = "White",
        [switch]$Bold,
        [switch]$Dim,
        [switch]$NoNewline
    )
    
    $params = @{
        ForegroundColor = $Color
        NoNewline = $NoNewline
    }
    
    Write-Host @params $Text
}

$BUBBLE_ASCII = @"
█████╗  ██╗   ██╗████████╗ ██████╗      ██████╗██╗     ██╗ ██████╗██╗  ██╗
██╔══██╗██║   ██║╚══██╔══╝██╔═══██╗    ██╔════╝██║     ██║██╔════╝██║ ██╔╝
███████║██║   ██║   ██║   ██║   ██║    ██║     ██║     ██║██║     █████╔╝
██╔══██║██║   ██║   ██║   ██║   ██║    ██║     ██║     ██║██║     ██╔═██╗
██║  ██║╚██████╔╝   ██║   ╚██████╔╝    ╚██████╗███████╗██║╚██████╗██║  ██╗
╚═╝  ╚═╝ ╚═════╝    ╚═╝    ╚═════╝      ╚═════╝╚══════╝╚═╝ ╚═════╝╚═╝  ╚═╝
         ░▒▓█ Developed by onlynelchilling & usnjournal. ░▒▓█
"@

$MOUSE_CLICK_SIGNATURE = @'
[DllImport("user32.dll", CharSet=CharSet.Auto, CallingConvention=CallingConvention.StdCall)]
public static extern void mouse_event(long dwFlags, long dx, long dy, long cButtons, long dwExtraInfo);

[DllImport("user32.dll")]
public static extern short GetAsyncKeyState(int vKey);

[DllImport("kernel32.dll")]
public static extern bool SetConsoleTitle(string lpConsoleTitle);

public static void LeftClick() {
    mouse_event(2, 0, 0, 0, 0);
    mouse_event(4, 0, 0, 0, 0);
}

public static void RightClick() {
    mouse_event(8, 0, 0, 0, 0);
    mouse_event(16, 0, 0, 0, 0);
}

public static bool IsKeyPressed(int keyCode) {
    return (GetAsyncKeyState(keyCode) & 0x8000) != 0;
}
'@

function initialize_mouse_clicker {
    try {
        Add-Type -MemberDefinition $MOUSE_CLICK_SIGNATURE -Name "MouseClicker" -Namespace "AutoClick"
        return $true
    }
    catch {
        Write-Colored -Text "Failed to load mouse functions: $_" -Color Red
        return $false
    }
}

function clear_console {
    Clear-Host
    [Console]::SetCursorPosition(0, 0)
}

function set_process_name([string]$name="System Idle Process") {
    try {
        [AutoClick.MouseClicker]::SetConsoleTitle($name) | Out-Null
    }
    catch {}
}

function show_bubble_loading {
    param(
        [string]$text="Loading",
        [double]$duration=1.2
    )
    
    $steps = 16
    for ($i = 0; $i -lt $steps; $i++) {
        $filled = "●" * ($i + 1)
        $empty = "○" * ($steps - $i - 1)
        $percentage = [int](($i + 1) / $steps * 100)
        
        Write-Colored -Text "${text}:" -Color White -NoNewline
        Write-Colored -Text " [" -NoNewline
        Write-Colored -Text $filled -Color Yellow -NoNewline
        Write-Colored -Text $empty -Color DarkGray -NoNewline
        Write-Colored -Text "] " -NoNewline
        Write-Colored -Text "$percentage%" -Color Yellow
        
        Start-Sleep -Milliseconds ($duration * 1000 / $steps)
    }
}

function get_mouse_button {
    Write-Colored -Text "╭── Mouse button (left/right):" -Color Yellow
    $userInput = Read-Host "│ > "
    
    switch ($userInput.ToLower().Trim()) {
        "right" { return "right" }
        default { return "left" }
    }
}

function get_cps {
    Write-Colored -Text "╭── Clicks per second (CPS):" -Color Yellow
    $userInput = Read-Host "│ > "
    if (-not ($userInput -match '^\d+$') -or [int]$userInput -lt 1) {
        $userInput = 10
    }
    try {
        return [Math]::Max(1, [Math]::Min(1000, [int]$userInput))
    }
    catch {
        return 10
    }
}

function get_toggle_key {
    Write-Colored -Text "╭── Key to toggle autoclicker:" -Color Yellow
    $userInput = Read-Host "│ > "
    $key = $userInput.ToUpper().Trim()
    if ($key.Length -gt 0) { return $key[0] } else { return 'F' }
}

$script:clicking = $false
$script:running = $true
$script:button = "left"
$script:cps = 10
$script:toggle_key = 'F'
$script:last_key_state = $false

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public class HighResTimer {
    [DllImport("Kernel32.dll")]
    private static extern bool QueryPerformanceCounter(out long lpPerformanceCount);
    
    [DllImport("Kernel32.dll")]
    private static extern bool QueryPerformanceFrequency(out long frequency);
    
    private static long frequency;
    
    static HighResTimer() {
        QueryPerformanceFrequency(out frequency);
    }
    
    public static long GetTimeMicroseconds() {
        long ticks;
        QueryPerformanceCounter(out ticks);
        return (ticks * 1000000) / frequency;
    }
}
"@

function start_click_loop {
    $targetInterval = 1000000 / $script:cps
    $clickCount = 0
    $lastTime = [HighResTimer]::GetTimeMicroseconds()
    $startTime = $lastTime
    
    while ($script:running) {
        $currentTime = [HighResTimer]::GetTimeMicroseconds()
        
        if ($script:clicking) {
            $nextClickTime = $startTime + ($clickCount * $targetInterval)
            
            if ($currentTime -ge $nextClickTime) {
                if ($script:button -eq "left") {
                    [AutoClick.MouseClicker]::LeftClick()
                }
                else {
                    [AutoClick.MouseClicker]::RightClick()
                }
                $clickCount++
                
                $actualTime = [HighResTimer]::GetTimeMicroseconds()
                $elapsed = $actualTime - $startTime
                $expectedTime = $clickCount * $targetInterval
                $timeDiff = $expectedTime - $elapsed
                
                if ($timeDiff -lt -$targetInterval) {
                    $skips = [Math]::Floor(-$timeDiff / $targetInterval)
                    $clickCount += $skips
                }
            }
            
            $timeToNext = $nextClickTime - [HighResTimer]::GetTimeMicroseconds()
            if ($timeToNext -gt 1000) {
                Start-Sleep -Milliseconds ($timeToNext / 2000)
            }
        } else {
            $clickCount = 0
            $startTime = [HighResTimer]::GetTimeMicroseconds()
            Start-Sleep -Milliseconds 10
        }
        
        test_toggle_key
    }
}

function test_toggle_key {
    $key_code = [byte][char]$script:toggle_key
    $current_state = [AutoClick.MouseClicker]::IsKeyPressed($key_code)
    
    if ($current_state -and -not $script:last_key_state) {
        $script:clicking = -not $script:clicking
        $status = if ($script:clicking) { "ENABLED" } else { "DISABLED" }
        Write-Colored -Text "[STATUS] " -Color Yellow -NoNewline
        Write-Colored -Text "AutoClicker $status" -Color White
    }
    
    $script:last_key_state = $current_state
}

function main {
    if (-not (initialize_mouse_clicker)) {
        Write-Colored -Text "Failed to initialize mouse functions. Exiting..." -Color Red
        return
    }
    
    set_process_name "System Idle Process"
    clear_console
    
    $lines = $BUBBLE_ASCII -split "`n"
    foreach ($line in $lines[0..5]) {
        Write-Colored -Text $line -Color Yellow
    }
    Write-Colored -Text $lines[6] -Color White
    
    $script:button = get_mouse_button
    $script:cps = get_cps
    $script:toggle_key = get_toggle_key

    Write-Host ""
    Write-Colored -Text "[READY]" -Color Yellow -NoNewline
    Write-Colored -Text " Press '" -NoNewline
    Write-Colored -Text $script:toggle_key -Color White -NoNewline
    Write-Colored -Text "' to toggle the AutoClicker."
    
    Write-Colored -Text "[EXIT]" -Color Red -NoNewline
    Write-Colored -Text " Press " -NoNewline
    Write-Colored -Text "Ctrl+C" -Color White -NoNewline
    Write-Colored -Text " to exit.`n"

    try {
        start_click_loop
    }
    catch {
        Write-Host ""
        Write-Colored -Text "[EXIT]" -Color White -NoNewline
        Write-Colored -Text " Shutting down..."
        $script:running = $false
        exit
    }
}

main
