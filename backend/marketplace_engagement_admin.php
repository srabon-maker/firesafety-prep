<?php
declare(strict_types=1);
require_once __DIR__.'/admin_helpers.php';
require_admin();
require_once __DIR__.'/db.php';
$token=csrf_token();
$error='';
$ready=false;
function me_id(mixed $value): int {
    $id=filter_var($value,FILTER_VALIDATE_INT,['options'=>['min_range'=>1]]);
    if($id===false) throw new InvalidArgumentException('Invalid ID');
    return $id;
}
function me_text(mixed $value,int $max,bool $required=false): string {
    if(!is_string($value)) throw new InvalidArgumentException('Invalid text');
    $value=trim($value);
    $length=function_exists('mb_strlen')?mb_strlen($value,'UTF-8'):preg_match_all('/./us',$value);
    if(($required&&$value==='')||$length===false||$length>$max) throw new InvalidArgumentException('Invalid text length');
    return $value;
}
try {
    $pdo->query('SELECT id FROM market_product_reviews LIMIT 1');
    $pdo->query('SELECT id FROM market_product_banners LIMIT 1');
    $ready=true;
    if(($_SERVER['REQUEST_METHOD']??'')==='POST'){
        verify_csrf();
        $action=$_POST['action']??'';
        if($action==='review_status'){
            $id=me_id($_POST['id']??null);
            $status=$_POST['status']??'';
            if(!in_array($status,['approved','hidden','pending'],true)) throw new InvalidArgumentException('Invalid status');
            $pdo->prepare('UPDATE market_product_reviews SET status=? WHERE id=?')->execute([$status,$id]);
        } elseif($action==='save_banner'){
            $pid=me_id($_POST['product_id']??null);
            $q=$pdo->prepare("SELECT id FROM market_products WHERE id=? AND status='published'");
            $q->execute([$pid]);
            if(!$q->fetchColumn()) throw new InvalidArgumentException('Choose a published product');
            $title=me_text($_POST['title']??'',150,true);
            $subtitle=me_text($_POST['subtitle']??'',250);
            $image=me_text($_POST['image_url']??'',2048);
            if($image!=='' && (!filter_var($image,FILTER_VALIDATE_URL)||parse_url($image,PHP_URL_SCHEME)!=='https'||parse_url($image,PHP_URL_USER)!==null)) throw new InvalidArgumentException('Image must use HTTPS');
            $sort=filter_var($_POST['sort_order']??0,FILTER_VALIDATE_INT);
            if($sort===false||abs($sort)>100000)throw new InvalidArgumentException('Invalid sort order');
            $values=[$pid,$title,$subtitle,$image===''?null:$image,isset($_POST['is_active'])?1:0,$sort];
            if(($_POST['id']??'')===''){
                $q=$pdo->prepare('INSERT INTO market_product_banners(product_id,title,subtitle,image_url,is_active,sort_order) VALUES(?,?,?,?,?,?)');
            } else {
                $q=$pdo->prepare('UPDATE market_product_banners SET product_id=?,title=?,subtitle=?,image_url=?,is_active=?,sort_order=? WHERE id=?');
                $values[]=me_id($_POST['id']);
            }
            $q->execute($values);
        } elseif($action==='disable_banner'){
            $pdo->prepare('UPDATE market_product_banners SET is_active=0 WHERE id=?')->execute([me_id($_POST['id']??null)]);
        } else throw new InvalidArgumentException('Invalid action');
        header('Location: marketplace_engagement_admin.php?saved=1',true,303);exit;
    }
} catch(InvalidArgumentException $e){$error=$e->getMessage();}
catch(Throwable $e){error_log('Marketplace engagement admin: '.$e->getMessage());$error='Unable to load or save. Check migration and server logs.';}
$products=$banners=$reviews=[];$edit=null;
if($ready){
    try{
        $products=$pdo->query("SELECT id,name FROM market_products WHERE status='published' ORDER BY name")->fetchAll(PDO::FETCH_ASSOC);
        $banners=$pdo->query("SELECT b.*,p.name AS product_name FROM market_product_banners b LEFT JOIN market_products p ON p.id=b.product_id ORDER BY b.sort_order,b.id DESC")->fetchAll(PDO::FETCH_ASSOC);
        $reviews=$pdo->query("SELECT r.id,r.rating,r.review_text,r.status,r.updated_at,p.name AS product_name FROM market_product_reviews r LEFT JOIN market_products p ON p.id=r.product_id ORDER BY (r.status='pending') DESC,r.id DESC LIMIT 200")->fetchAll(PDO::FETCH_ASSOC);
        foreach($banners as $b)if((string)$b['id']===(string)($_GET['edit']??''))$edit=$b;
    }catch(Throwable $e){error_log('Marketplace engagement admin: '.$e->getMessage());$error='Unable to load data.';}
}
function me_field(?array $row,string $key): string{return h((string)($row[$key]??''));}
?>
<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Marketplace Reviews &amp; Banners</title>
<style>body{font:15px Arial,sans-serif;background:#f8f5f5;color:#271519;margin:0}header{background:#650d18;color:white;padding:20px}header a{color:white}main{max-width:1100px;margin:auto;padding:18px}section{background:white;border:1px solid #e4d2d5;border-radius:12px;padding:18px;margin-bottom:18px}label{display:block;margin:10px 0}input:not([type=checkbox]),select,textarea{box-sizing:border-box;max-width:100%;padding:9px;border:1px solid #ccc;border-radius:6px}label input:not([type=checkbox]),label select{display:block;width:100%}button{background:#650d18;color:white;border:0;border-radius:7px;padding:9px;cursor:pointer}table{border-collapse:collapse;width:100%}td,th{text-align:left;padding:9px;border-bottom:1px solid #ddd;vertical-align:top}td{overflow-wrap:anywhere}.scroll{overflow:auto}.error{color:#a00}</style></head><body>
<header><strong>Marketplace · Reviews &amp; Banners</strong> · <a href="marketplace_admin.php">Back to Marketplace</a></header>
<main>
<?php if($error!==''):?><p class="error"><?=h($error)?></p><?php endif;?>
<?php if(isset($_GET['saved'])):?><p>Changes saved.</p><?php endif;?>
<?php if(!$ready):?><p>Apply the marketplace reviews/banners SQL migration first.</p><?php else:?>
<section><h2><?= $edit?'Edit':'Add'?> product banner</h2>
<form method="post"><input type="hidden" name="csrf_token" value="<?=h($token)?>"><input type="hidden" name="action" value="save_banner"><input type="hidden" name="id" value="<?=me_field($edit,'id')?>">
<label>Published product<select name="product_id" required><option value="">Select product</option><?php foreach($products as $p):?><option value="<?=h((string)$p['id'])?>" <?= (string)($edit['product_id']??'')===(string)$p['id']?'selected':''?>><?=h($p['name'])?></option><?php endforeach;?></select></label>
<label>Title<input name="title" maxlength="150" required value="<?=me_field($edit,'title')?>"></label>
<label>Subtitle / offer text<input name="subtitle" maxlength="250" value="<?=me_field($edit,'subtitle')?>"></label>
<label>Banner image HTTPS URL (optional)<input type="url" name="image_url" maxlength="2048" value="<?=me_field($edit,'image_url')?>"></label>
<label>Sort order<input type="number" name="sort_order" value="<?=h((string)($edit['sort_order']??0))?>"></label>
<label><input type="checkbox" name="is_active" <?=!empty($edit['is_active'])?'checked':''?>> Active</label>
<button>Save banner</button> <a href="marketplace_engagement_admin.php">New banner</a>
</form></section>
<section class="scroll"><h2>Product banners</h2><table><tr><th>Title</th><th>Product</th><th>Status</th><th>Actions</th></tr>
<?php foreach($banners as $b):?><tr><td><?=h($b['title'])?></td><td><?=h($b['product_name'])?></td><td><?= $b['is_active']?'Active':'Inactive'?></td><td><a href="?edit=<?=h((string)$b['id'])?>">Edit</a> <form method="post" style="display:inline"><input type="hidden" name="csrf_token" value="<?=h($token)?>"><input type="hidden" name="action" value="disable_banner"><input type="hidden" name="id" value="<?=h((string)$b['id'])?>"><button>Disable</button></form></td></tr><?php endforeach;?>
</table></section>
<section class="scroll"><h2>Verified purchase reviews</h2><p>Approve genuine reviews regardless of rating. Hide only spam, abuse, or policy violations. Latest 200, pending first.</p><table><tr><th>Product</th><th>Rating</th><th>Review</th><th>Status</th><th>Moderate</th></tr>
<?php foreach($reviews as $r):?><tr><td><?=h($r['product_name'])?></td><td><?=h((string)$r['rating'])?>/5</td><td><?=h($r['review_text'])?></td><td><?=h($r['status'])?></td><td><form method="post"><input type="hidden" name="csrf_token" value="<?=h($token)?>"><input type="hidden" name="action" value="review_status"><input type="hidden" name="id" value="<?=h((string)$r['id'])?>"><select name="status"><option value="approved">Approve</option><option value="hidden">Hide</option><option value="pending">Pending</option></select> <button>Save</button></form></td></tr><?php endforeach;?>
</table></section><?php endif;?></main></body></html>
