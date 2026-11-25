<?php
declare(strict_types=1);
const PREMIUM_PDF_MAX=10485760;
// cPanel account home, NOT the web document root. Provision this directory manually with 0700.
function premium_pdf_dir():string{
 $expected='/home2/manobiki/fire-safety-private-pdfs';
 $root=realpath((string)($_SERVER['DOCUMENT_ROOT']??''));
 $app=realpath(__DIR__);
 $dir=realpath($expected);
 if($root===false||$app===false||$dir!==$expected||is_link($expected)||!is_dir($dir)||!is_readable($dir)||(($mode=fileperms($dir))===false)||($mode&0077)!==0)throw new RuntimeException('Private PDF directory is not ready');
 foreach([$root,$app] as $public)if($dir===$public||str_starts_with($dir,$public.DIRECTORY_SEPARATOR))throw new RuntimeException('Unsafe PDF directory');
 return $dir;
}
function premium_pdf_path(string $name):string{
 if(!preg_match('/^[a-f0-9]{64}\.pdf$/D',$name))throw new RuntimeException('Invalid private PDF name');
 $path=premium_pdf_dir().DIRECTORY_SEPARATOR.$name;
 if(is_link($path)||!is_file($path)||realpath($path)!==$path)throw new RuntimeException('Private PDF missing');
 return $path;
}
function premium_pdf_upload(array $file):array{
 if(($file['error']??null)!==UPLOAD_ERR_OK||!is_string($file['tmp_name']??null)||!is_uploaded_file($file['tmp_name']))throw new DomainException('সঠিক PDF আপলোড করুন।');
 $src=$file['tmp_name'];$size=filesize($src);
 if($size===false||$size<5||$size>PREMIUM_PDF_MAX)throw new DomainException('PDF সর্বোচ্চ ১০ MB হতে হবে।');
 if((new finfo(FILEINFO_MIME_TYPE))->file($src)!=='application/pdf'||file_get_contents($src,false,null,0,5)!=='%PDF-')throw new DomainException('শুধু PDF গ্রহণযোগ্য।');
 $dir=premium_pdf_dir();if(!is_writable($dir))throw new RuntimeException('Private directory is not writable');
 $name=bin2hex(random_bytes(32)).'.pdf';$path=$dir.DIRECTORY_SEPARATOR.$name;
 if(file_exists($path)||!move_uploaded_file($src,$path))throw new RuntimeException('PDF upload failed');
 if(!chmod($path,0600)){@unlink($path);throw new RuntimeException('PDF permission failed');}
 return ['name'=>$name,'size'=>$size,'path'=>$path];
}
