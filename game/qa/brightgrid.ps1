param([string]$Path, [int]$Cols = 20, [int]$Rows = 12)
# 截图降采样为亮度网格,验证 3D 场景渲染内容(非黑屏/非纯色)
Add-Type -AssemblyName System.Drawing
$bmp = [System.Drawing.Bitmap]::FromFile($Path)
$w = $bmp.Width; $h = $bmp.Height
$sum = 0.0; $max = 0.0; $n = 0
for ($r = 0; $r -lt $Rows; $r++) {
  $line = ''
  for ($c = 0; $c -lt $Cols; $c++) {
    $x0 = [int]($c * $w / $Cols); $x1 = [int](($c + 1) * $w / $Cols)
    $y0 = [int]($r * $h / $Rows); $y1 = [int](($r + 1) * $h / $Rows)
    $s = 0.0; $cn = 0
    for ($y = $y0; $y -lt $y1; $y += 4) {
      for ($x = $x0; $x -lt $x1; $x += 4) {
        $px = $bmp.GetPixel($x, $y)
        $lum = 0.2126 * $px.R + 0.7152 * $px.G + 0.0722 * $px.B
        $s += $lum; $cn++
      }
    }
    $avg = $s / [Math]::Max(1, $cn)
    $sum += $avg * $cn; $n += $cn
    if ($avg -gt $max) { $max = $avg }
    $line += [string][int][Math]::Min(9, $avg / 26)
  }
  Write-Output $line
}
Write-Output ("SIZE={0}x{1} MEAN={2:N1}/255 MAX={3:N1}/255" -f $w, $h, ($sum / [Math]::Max(1,$n)), $max)
$bmp.Dispose()
