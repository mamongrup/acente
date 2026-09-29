<?php
// Build homepage-only WebP variants. Keep original images for detail pages.
declare(strict_types=1);

$root = dirname(__DIR__);
$html = file_get_contents($root . '/chisfis-final/index.html');
if ($html === false) { throw new RuntimeException('Homepage template could not be read'); }
preg_match_all('~assets/images/([^"\'<> ]+\.jpg)~i', $html, $matches);
$imageDir = $root . '/priv/static/chisfis/images';
$manifest = [];
foreach (array_unique($matches[1]) as $name) {
    if (!str_starts_with($name, 'pexels-photo-') && !str_starts_with($name, 'queen-of-liberty-')) continue;
    $source = $imageDir . '/' . $name;
    if (!is_file($source)) continue;
    $size = getimagesize($source);
    if ($size === false) continue;
    $maxWidth = $name === 'pexels-photo-131423.jpg' ? 2000 : 1200;
    if ($size[0] <= $maxWidth) continue;
    $targetName = substr($name, 0, -4) . '.home.webp';
    $target = $imageDir . '/' . $targetName;
    $image = imagecreatefromjpeg($source);
    if ($image === false) throw new RuntimeException("Cannot decode $name");
    $width = min($size[0], $maxWidth);
    $height = (int) round($size[1] * $width / $size[0]);
    $resized = imagecreatetruecolor($width, $height);
    imagecopyresampled($resized, $image, 0, 0, 0, 0, $width, $height, $size[0], $size[1]);
    if (!imagewebp($resized, $target, 82)) throw new RuntimeException("Cannot write $targetName");
    imagedestroy($resized);
    imagedestroy($image);
    $manifest[] = "$name|$targetName";
}
sort($manifest);
file_put_contents($imageDir . '/home-optimized.txt', implode("\n", $manifest) . "\n");
echo count($manifest) . " homepage images optimized\n";
