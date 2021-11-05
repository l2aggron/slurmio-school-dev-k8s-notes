while ($true) {
    $clipboard = Get-Clipboard

    # Конвертируем ссылку с привязкой ко времени в markdown таймкод
    if ($clipboard -match "^https:\/\/youtu\.be\/.+\?t=\d+$") {
        $totalSeconds = ($clipboard -split "t=")[1]
        $timestamp = (New-TimeSpan -Start (Get-Date 0) -End (Get-Date 0).AddSeconds($totalSeconds)).ToString()
        "[$timestamp]($clipboard)" | Set-Clipboard
    }
    
    # Конвертируем вывод терминала для вставки в markdown
    if ($clipboard -match "^\$ k ") {
        $clipboard = $clipboard -replace "^\$ k ", "> kubectl "
        @('```shell', $clipboard[0], "", @($clipboard | select-object -skip 1), '```') | Set-Clipboard
    }
    elseif ($clipboard -match "^\$") {
        $clipboard = $clipboard -replace "\$", ">"
        @('```shell', $clipboard[0], "", @($clipboard | select-object -skip 1), '```') | Set-Clipboard
    }

    sleep -Milliseconds 200
}