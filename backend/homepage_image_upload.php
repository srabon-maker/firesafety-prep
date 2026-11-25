<?php
declare(strict_types=1);

// Library only; caller must require admin and verify CSRF before use.
const HP_UPLOAD_MAX_BYTES = 4 * 1024 * 1024;
const HP_UPLOAD_MAX_PIXELS = 8000000;
const HP_UPLOAD_BASE = 'https://fire.manobikishwarganj.com/uploads/homepage/';

function hp_image_dimensions(string $path): array {
    $bytes = @filesize($path);
    if ($bytes === false || $bytes < 1 || $bytes > HP_UPLOAD_MAX_BYTES) {
        throw new DomainException('ছবির আকার সর্বোচ্চ ৪ MB হতে হবে।');
    }
    $info = @getimagesize($path);
    if (!$info || !in_array($info[2], [IMAGETYPE_JPEG, IMAGETYPE_PNG, IMAGETYPE_WEBP], true)) {
        throw new DomainException('শুধু সঠিক JPG, PNG অথবা WebP ছবি দিন।');
    }
    [$w, $h, $type] = $info;
    if ($w < 1 || $h < 1 || $w > 4096 || $h > 4096 || $w * $h > HP_UPLOAD_MAX_PIXELS) {
        throw new DomainException('ছবির রেজল্যুশন সর্বোচ্চ ৪০৯৬ পিক্সেল ও ৮ মেগাপিক্সেল হতে হবে।');
    }
    if (!class_exists('finfo')) {
        throw new RuntimeException('Fileinfo is unavailable');
    }
    $mime = (new finfo(FILEINFO_MIME_TYPE))->file($path);
    $expected = [IMAGETYPE_JPEG=>'image/jpeg', IMAGETYPE_PNG=>'image/png', IMAGETYPE_WEBP=>'image/webp'];
    if ($mime !== $expected[$type]) {
        throw new DomainException('ছবির ফাইল টাইপ সঠিক নয়।');
    }
    return [$w, $h, $type];
}

function hp_store_banner_image(array $upload, string $directory): ?array {
    $error = $upload['error'] ?? UPLOAD_ERR_NO_FILE;
    if ($error === UPLOAD_ERR_NO_FILE) return null;
    if ($error !== UPLOAD_ERR_OK) throw new DomainException('ছবি আপলোড হয়নি। ৪ MB-এর ছোট ছবি দিয়ে চেষ্টা করুন।');
    $tmp = $upload['tmp_name'] ?? null;
    if (!is_string($tmp) || !is_uploaded_file($tmp)) throw new DomainException('সঠিক আপলোড করা ছবি পাওয়া যায়নি।');
    [$w,$h,$type] = hp_image_dimensions($tmp);
    $decoder = [IMAGETYPE_JPEG=>'imagecreatefromjpeg', IMAGETYPE_PNG=>'imagecreatefrompng', IMAGETYPE_WEBP=>'imagecreatefromwebp'][$type];
    if (!function_exists($decoder) || !function_exists('imagecreatetruecolor') ||
        !function_exists('imagejpeg') || !function_exists('imagecopyresampled')) {
        throw new DomainException('সার্ভারে PHP GD image support চালু করতে হবে।');
    }
    if (!is_dir($directory) || is_link($directory) || !is_writable($directory) ||
        !is_file($directory.'/.htaccess')) {
        throw new RuntimeException('Protected homepage upload directory unavailable');
    }
    $src = @$decoder($tmp);
    if ($src === false) throw new DomainException('ছবিটি পড়া যাচ্ছে না। অন্য ছবি দিন।');
    $dest = null;
    $out = null;
    $completed = false;
    try {
        // Re-encode actual pixels: strip original names, metadata and embedded content.
        $ratio = min(1.0, 1600 / max($w,$h));
        $dw = max(1, (int)round($w*$ratio));
        $dh = max(1, (int)round($h*$ratio));
        $dest = imagecreatetruecolor($dw,$dh);
        if ($dest === false) throw new RuntimeException('Image allocation failed');
        imagefill($dest, 0, 0, imagecolorallocate($dest,255,255,255));
        if (!imagecopyresampled($dest,$src,0,0,0,0,$dw,$dh,$w,$h)) {
            throw new RuntimeException('Image resize failed');
        }
        $name = bin2hex(random_bytes(24)).'.jpg';
        $out = $directory.'/'.$name;
        // Create exclusively, never overwrite an existing file.
        $stream = @fopen($out,'xb');
        if ($stream === false) { $out = null; throw new RuntimeException('Image output unavailable'); }
        try {
            if (!imagejpeg($dest,$stream,86)) throw new RuntimeException('Image encoding failed');
        } finally { fclose($stream); }
        clearstatcache(true,$out);
        if (!is_file($out) || filesize($out) < 1 || !chmod($out,0644)) {
            throw new RuntimeException('Image output failed');
        }
        $completed = true;
        return ['path'=>$out,'url'=>HP_UPLOAD_BASE.$name];
    } finally {
        if (!$completed && $out !== null) @unlink($out);
        if ($dest !== null && $dest !== false) imagedestroy($dest);
        imagedestroy($src);
    }
}
