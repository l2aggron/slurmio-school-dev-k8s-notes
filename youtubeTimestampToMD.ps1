# Конвертируем ссылку с привязкой ко времени в markdown таймкод
while ($true) {
    $clipboard = Get-Clipboard
    if ($clipboard -match "^https:\/\/youtu\.be\/.+\?t=\d+$") {
        $totalSeconds = ($clipboard -split "t=")[1]
        $timestamp = (New-TimeSpan -Start (Get-Date 0) -End (Get-Date 0).AddSeconds($totalSeconds)).ToString()
        "[$timestamp]($clipboard)" | Set-Clipboard
    }
    sleep -Milliseconds 200
}