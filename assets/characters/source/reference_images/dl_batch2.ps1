$base = "C:\Users\caleb\RECONgame\assets\characters\source\reference_images"
$ua = "RECONgame-research/1.0 (calebdickenson@gmail.com)"
$sets = @{
  "m79" = @(
    "https://cdn.rockislandauction.com/dev_cdn/4090/454.jpg",
    "https://cdn.rockislandauction.com/dev_cdn/4091/3440.jpg",
    "https://upload.wikimedia.org/wikipedia/commons/3/3b/M79_Grenade_launcher.jpg",
    "https://upload.wikimedia.org/wikipedia/commons/4/49/M79_Grenade_Launcher_%287414625716%29.jpg"
  )
  "ithaca37" = @(
    "https://cdn.rockislandauction.com/dev_cdn/86/341.jpg",
    "https://cdn.rockislandauction.com/dev_cdn/1049/697.jpg",
    "https://upload.wikimedia.org/wikipedia/commons/d/d3/Ithaca_37_cropped_and_rotated.jpg",
    "https://upload.wikimedia.org/wikipedia/commons/d/d2/Ithaca_37.jpg"
  )
  "m70" = @(
    "https://cdn.rockislandauction.com/dev_cdn/1042/6440.jpg",
    "https://cdn.rockislandauction.com/dev_cdn/74/3542.jpg",
    "https://cdn.rockislandauction.com/dev_cdn/89/1345.jpg",
    "https://upload.wikimedia.org/wikipedia/commons/3/34/Pre-1964_Winchester_Model_70_2.jpg",
    "https://upload.wikimedia.org/wikipedia/commons/b/b4/Winchestermodel70.jpg"
  )
}
foreach ($k in $sets.Keys) {
  $dir = Join-Path $base $k
  New-Item -ItemType Directory -Force $dir | Out-Null
  $i = 1
  foreach ($url in $sets[$k]) {
    $ext = if ($url -match "\.png") { "png" } else { "jpg" }
    $out = Join-Path $dir "ref_$i.$ext"
    if (-not (Test-Path $out)) {
      try {
        Invoke-WebRequest -Uri $url -OutFile $out -UserAgent $ua -TimeoutSec 60
        Write-Output "OK $k/ref_$i <- $url"
      } catch { Write-Output "FAIL $k/ref_$i $url : $($_.Exception.Message)" }
      Start-Sleep -Seconds 3
    } else { Write-Output "SKIP $k/ref_$i (exists)" }
    $i++
  }
}
Write-Output "BATCH2 DONE"
