param([string]$Dir = "game/qa/shots")
# UI 改版视觉特征检测(像素级定量断言):
#   1. 标题画面:朱红元素行分布(「封」印/分隔线/警示行)
#   2. HUD:CRT 扫描线(y%3 分组亮度差)+ 理智条冷色像素
#   3. 弹窗:中央纸纹暖褐(R-B 均值)
#   4. 死亡画面:中央红带行分布(「卒」印/标题)
#   5. 结局画面:中央标题亮像素
Add-Type -AssemblyName System.Drawing

function Open-Bmp([string]$n) { [System.Drawing.Bitmap]::FromFile((Join-Path $Dir $n)) }
function Lum($p) { 0.2126 * $p.R + 0.7152 * $p.G + 0.0722 * $p.B }

# 红元素行分布:中央竖带内扫描,聚类为区间输出
function Red-Segments($b, [int]$x0, [int]$x1, [int]$step) {
  $rowCnt = @{}
  for ($y = 0; $y -lt $b.Height; $y++) {
    $c = 0
    for ($x = $x0; $x -lt $x1; $x += $step) {
      $p = $b.GetPixel($x, $y)
      if ($p.R -gt 50 -and ($p.R - $p.G) -gt 22 -and ($p.R - $p.B) -gt 22) { $c++ }
    }
    if ($c -ge 3) { $rowCnt[$y] = $c }
  }
  $ys = @($rowCnt.Keys) | Sort-Object
  if ($ys.Count -eq 0) { Write-Output "  (无红元素)"; return }
  $segs = @(); $start = $ys[0]; $prev = $ys[0]
  for ($i = 1; $i -lt $ys.Count; $i++) {
    if ($ys[$i] - $prev -gt 4) { $segs += , @($start, $prev); $start = $ys[$i] }
    $prev = $ys[$i]
  }
  $segs += , @($start, $prev)
  foreach ($s in $segs) {
    $peak = 0
    for ($y = $s[0]; $y -le $s[1]; $y++) { if ($rowCnt.ContainsKey($y) -and $rowCnt[$y] -gt $peak) { $peak = $rowCnt[$y] } }
    Write-Output ("  y[{0}-{1}] 峰值红计数={2}" -f $s[0], $s[1], $peak)
  }
}

"===== 1. 标题画面(01-title.png)====="
$b = Open-Bmp "01-title.png"
Red-Segments $b 400 940 3
$b.Dispose()

"===== 2. HUD 画面(02-1f-lobby.png)====="
$b2 = Open-Bmp "02-1f-lobby.png"
foreach ($xc in 400, 640, 900) {
  $s0 = 0.0; $s1 = 0.0; $s2 = 0.0; $c0 = 0; $c1 = 0; $c2 = 0
  for ($y = 350; $y -lt 520; $y++) {
    $p = $b2.GetPixel($xc, $y)
    $v = 0.2126 * $p.R + 0.7152 * $p.G + 0.0722 * $p.B
    $m = $y % 3
    if ($m -eq 0) { $s0 += $v; $c0++ }
    elseif ($m -eq 1) { $s1 += $v; $c1++ }
    else { $s2 += $v; $c2++ }
  }
  $a0 = $s0 / $c0; $a1 = $s1 / $c1; $a2 = $s2 / $c2
  $mx = [Math]::Max($a0, [Math]::Max($a1, $a2))
  $mn = [Math]::Min($a0, [Math]::Min($a1, $a2))
  Write-Output ("  x={0} y%3 亮度: {1:N2}/{2:N2}/{3:N2}  组差: {4:N2}" -f $xc, $a0, $a1, $a2, ($mx - $mn))
}
$cold = 0
for ($y = 30; $y -lt 120; $y += 2) {
  for ($x = 20; $x -lt 240; $x += 2) {
    $p = $b2.GetPixel($x, $y)
    if ($p.B -gt ($p.R + 12) -and $p.B -gt 40) { $cold++ }
  }
}
Write-Output "  左上冷色像素(理智条): $cold"
$b2.Dispose()

"===== 3. 弹窗纸纹(06-2f-mahjong-puzzle.png)====="
$b6 = Open-Bmp "06-2f-mahjong-puzzle.png"
$s = 0.0; $n6 = 0
for ($y = 250; $y -lt 500; $y += 3) {
  for ($x = 400; $x -lt 880; $x += 3) {
    $p = $b6.GetPixel($x, $y)
    $s += ($p.R - $p.B); $n6++
  }
}
Write-Output ("  弹窗中央 R-B 均值: {0:N2}" -f ($s / $n6))
$b6.Dispose()

"===== 4. 死亡画面(28-gameover-sanity.png)====="
$b28 = Open-Bmp "28-gameover-sanity.png"
Red-Segments $b28 400 940 4
$b28.Dispose()

"===== 5. 结局画面(23-ending-true.png)====="
$b23 = Open-Bmp "23-ending-true.png"
$lit = 0
for ($y = 220; $y -lt 380; $y += 2) {
  for ($x = 400; $x -lt 880; $x += 2) {
    $p = $b23.GetPixel($x, $y)
    if ((Lum $p) -gt 85) { $lit++ }
  }
}
Write-Output "  中央亮像素(结局标题): $lit"
$b23.Dispose()
