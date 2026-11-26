<?php
declare(strict_types=1);
require_once __DIR__ . '/admin_helpers.php';
require_admin();
require_once __DIR__ . '/db.php';
$orderHelper = __DIR__ . '/api/marketplace/_orders.php';
$orderUpgradeReady = false;
if (is_file($orderHelper)) {
    require_once $orderHelper;
    try {
        market_delivery_fee($pdo);
        $pdo->query('SELECT id FROM market_order_events LIMIT 1');
        $orderUpgradeReady = true;
    } catch (Throwable $ignored) { /* migrate before enabling new order controls */ }
}

$tabs = ['products','services','categories','orders','requests'];
$tab = (string)($_GET['tab'] ?? 'products');
if (!in_array($tab,$tabs,true)) $tab = 'products';
$token = csrf_token();
$error = '';
function mk_strlen(string $v): int {
    if (function_exists('mb_strlen')) return mb_strlen($v, 'UTF-8');
    return preg_match_all('/./us', $v) ?: 0;
}
function mk_string(mixed $v, int $max, string $name, bool $required = true): string {
    if (!is_string($v)) throw new InvalidArgumentException("Invalid $name");
    $v = trim($v);
    if (($required && $v === '') || mk_strlen($v) > $max) throw new InvalidArgumentException("Invalid $name");
    return $v;
}
function mk_id(mixed $v, bool $optional = false): ?int {
    if ($optional && ($v === '' || $v === null)) return null;
    $id = filter_var($v,FILTER_VALIDATE_INT,['options'=>['min_range'=>1]]);
    if ($id === false) throw new InvalidArgumentException('Invalid ID');
    return $id;
}
function mk_money(mixed $v, bool $optional = false): ?string {
    if ($optional && ($v === '' || $v === null)) return null;
    if (!is_scalar($v) || !preg_match('/^\d{1,10}(?:\.\d{1,2})?$/D',(string)$v)) throw new InvalidArgumentException('Invalid price');
    return number_format((float)$v,2,'.','');
}
function mk_enum(mixed $v, array $allowed): string {
    if (!is_string($v) || !in_array($v,$allowed,true)) throw new InvalidArgumentException('Invalid status/type');
    return $v;
}
function mk_url(mixed $v): ?string {
    $v = mk_string($v,2048,'image URL',false);
    if ($v === '') return null;
    if (!filter_var($v,FILTER_VALIDATE_URL) || !str_starts_with($v,'https://')) throw new InvalidArgumentException('Image URL must use HTTPS');
    return $v;
}
function mk_slug(string $v): string {
    $v = strtolower(trim($v));
    if (!preg_match('/^[a-z0-9]+(?:-[a-z0-9]+)*$/D',$v) || strlen($v) > 180) throw new InvalidArgumentException('Slug must be lowercase letters, numbers and hyphens');
    return $v;
}
function mk_flash(string $tab): never {
    header('Location: marketplace_admin.php?tab=' . urlencode($tab) . '&saved=1',true,303);
    exit;
}
if (($_SERVER['REQUEST_METHOD'] ?? '') === 'POST') {
    verify_csrf();
    try {
        $action = (string)($_POST['action'] ?? '');
        $id = mk_id($_POST['id'] ?? null, true);
        if ($action === 'save_product') {
            $name = mk_string($_POST['name'] ?? null,200,'name');
            $slug = mk_slug(mk_string($_POST['slug'] ?? null,220,'slug'));
            $category = mk_id($_POST['category_id'] ?? null,true);
            $sku = mk_string($_POST['sku'] ?? '',100,'SKU',false);
            $description = mk_string($_POST['description'] ?? '',50000,'description',false);
            $price = mk_money($_POST['price'] ?? null);
            $compare = mk_money($_POST['compare_price'] ?? '',true);
            $stock = filter_var($_POST['stock_quantity'] ?? null,FILTER_VALIDATE_INT,['options'=>['min_range'=>0,'max_range'=>100000000]]);
            if ($stock === false) throw new InvalidArgumentException('Invalid stock');
            $image = mk_url($_POST['image_url'] ?? '');
            $status = mk_enum($_POST['status'] ?? '', ['draft','published','archived']);
            $featured = isset($_POST['is_featured']) ? 1 : 0;
            $values = [$category,$name,$slug,$sku === '' ? null : $sku,$description,$price,$compare,$stock,$image,$status,$featured];
            if ($id === null) {
                $stmt = $pdo->prepare('INSERT INTO market_products (category_id,name,slug,sku,description,price,compare_price,stock_quantity,image_url,status,is_featured) VALUES (?,?,?,?,?,?,?,?,?,?,?)');
            } else {
                $stmt = $pdo->prepare('UPDATE market_products SET category_id=?,name=?,slug=?,sku=?,description=?,price=?,compare_price=?,stock_quantity=?,image_url=?,status=?,is_featured=? WHERE id=?');
                $values[] = $id;
            }
            $stmt->execute($values);
            mk_flash('products');
        }
        if ($action === 'save_service') {
            $name = mk_string($_POST['name'] ?? null,200,'name');
            $slug = mk_slug(mk_string($_POST['slug'] ?? null,220,'slug'));
            $category = mk_id($_POST['category_id'] ?? null,true);
            $description = mk_string($_POST['description'] ?? '',50000,'description',false);
            $pricing = mk_enum($_POST['pricing_type'] ?? '', ['fixed','starting','quote']);
            $price = mk_money($_POST['price'] ?? '',true);
            if ($pricing === 'fixed' && $price === null) throw new InvalidArgumentException('Fixed service needs a price');
            $image = mk_url($_POST['image_url'] ?? '');
            $status = mk_enum($_POST['status'] ?? '', ['draft','published','archived']);
            $featured = isset($_POST['is_featured']) ? 1 : 0;
            $values = [$category,$name,$slug,$description,$pricing,$price,$image,$status,$featured];
            if ($id === null) $stmt = $pdo->prepare('INSERT INTO market_services (category_id,name,slug,description,pricing_type,price,image_url,status,is_featured) VALUES (?,?,?,?,?,?,?,?,?)');
            else { $stmt = $pdo->prepare('UPDATE market_services SET category_id=?,name=?,slug=?,description=?,pricing_type=?,price=?,image_url=?,status=?,is_featured=? WHERE id=?'); $values[] = $id; }
            $stmt->execute($values);
            mk_flash('services');
        }
        if ($action === 'save_category') {
            $name = mk_string($_POST['name'] ?? null,150,'name');
            $slug = mk_slug(mk_string($_POST['slug'] ?? null,180,'slug'));
            $type = mk_enum($_POST['category_type'] ?? '', ['product','service','both']);
            $description = mk_string($_POST['description'] ?? '',10000,'description',false);
            $sort = filter_var($_POST['sort_order'] ?? 0,FILTER_VALIDATE_INT);
            if ($sort === false) throw new InvalidArgumentException('Invalid sort order');
            $active = isset($_POST['is_active']) ? 1 : 0;
            $values = [$name,$slug,$type,$description,$sort,$active];
            if ($id === null) $stmt = $pdo->prepare('INSERT INTO market_categories (name,slug,category_type,description,sort_order,is_active) VALUES (?,?,?,?,?,?)');
            else { $stmt = $pdo->prepare('UPDATE market_categories SET name=?,slug=?,category_type=?,description=?,sort_order=?,is_active=? WHERE id=?'); $values[] = $id; }
            $stmt->execute($values);
            mk_flash('categories');
        }
        if ($action === 'delivery_fee') {
            if (!$orderUpgradeReady) throw new InvalidArgumentException('Order management migration required');
            $fee = market_order_money(market_order_cents(mk_money($_POST['flat_fee'] ?? null)));
            $pdo->prepare('UPDATE market_delivery_settings SET flat_fee=? WHERE id=1')->execute([$fee]);
            mk_flash('orders');
        }
        if ($action === 'order_status') {
            if (!$orderUpgradeReady) throw new InvalidArgumentException('Deploy order API and SQL migration before changing status');
            if ($id === null) throw new InvalidArgumentException('Order ID required');
            $status = mk_enum($_POST['order_status'] ?? '', ['confirmed','processing','shipped','delivered','cancelled']);
            $courier = mk_string($_POST['courier_name'] ?? '',100,'courier name',false);
            $tracking = mk_string($_POST['tracking_number'] ?? '',150,'tracking number',false);
            $pdo->beginTransaction();
            market_order_transition($pdo,$id,$status,null,$courier === '' ? null : $courier,$tracking === '' ? null : $tracking,isset($_POST['legacy_reconciled']));
            $pdo->commit();
            mk_flash('orders');
        }
        if ($action === 'request_status') {
            if ($id === null) throw new InvalidArgumentException('Request ID required');
            $status = mk_enum($_POST['status'] ?? '', ['pending','reviewing','approved','completed','rejected','cancelled']);
            $stmt = $pdo->prepare('UPDATE market_service_requests SET status=? WHERE id=?');
            $stmt->execute([$status,$id]);
            mk_flash('requests');
        }
        throw new InvalidArgumentException('Invalid action');
    } catch (InvalidArgumentException|DomainException|OutOfBoundsException $e) {
        if ($pdo->inTransaction()) $pdo->rollBack();
        $error = $e->getMessage();
    } catch (Throwable $e) {
        if ($pdo->inTransaction()) $pdo->rollBack();
        error_log('Marketplace admin: '.$e->getMessage());
        $error = 'Unable to save changes.';
    }
}

$categories = $pdo->query('SELECT id,name,category_type FROM market_categories ORDER BY name')->fetchAll();
$edit = null;
if (isset($_GET['edit']) && in_array($tab,['products','services','categories'],true)) {
    $editId = filter_var($_GET['edit'],FILTER_VALIDATE_INT,['options'=>['min_range'=>1]]);
    if ($editId !== false) {
        $table = ['products'=>'market_products','services'=>'market_services','categories'=>'market_categories'][$tab];
        $stmt = $pdo->prepare("SELECT * FROM $table WHERE id=?");
        $stmt->execute([$editId]);
        $edit = $stmt->fetch() ?: null;
    }
}
function field(array|null $edit,string $name,string $fallback = ''): string { return h((string)($edit[$name] ?? $fallback)); }
function selected(array|null $edit,string $name,string $value,string $default = ''): string { return (string)($edit[$name] ?? $default) === $value ? ' selected' : ''; }
function checked(array|null $edit,string $name,bool $default = false): string { return (int)($edit[$name] ?? ($default ? 1 : 0)) === 1 ? ' checked' : ''; }
?>
<!doctype html><html lang="bn"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Marketplace Admin - Fire Safety BD</title>
<style>
:root{font-family:Arial,'Noto Sans Bengali',sans-serif;color:#271519;background:#f8f5f5}*{box-sizing:border-box}body{margin:0}header{background:#36060d;color:white;padding:20px}header a{color:white}main{max-width:1160px;margin:auto;padding:20px}.tabs{display:flex;flex-wrap:wrap;gap:8px;margin:16px 0}.tabs a{padding:11px 16px;background:#fff;border:1px solid #ddd;border-radius:10px;color:#650d18;text-decoration:none}.tabs a.active{background:#650d18;color:white}.panel{background:white;border:1px solid #e7d8d8;border-radius:14px;padding:18px;margin-bottom:22px}form.grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:14px}label{font-size:14px;font-weight:bold;display:block}input,select,textarea{display:block;width:100%;margin-top:6px;padding:11px;border:1px solid #d6caca;border-radius:8px;font:inherit}textarea{min-height:100px}.wide{grid-column:1/-1}button{background:#650d18;color:#fff;border:0;border-radius:8px;padding:10px 16px;cursor:pointer}table{width:100%;border-collapse:collapse;font-size:14px}th,td{border-bottom:1px solid #eee;text-align:left;padding:11px;vertical-align:top}td a{color:#650d18}small{color:#666}.scroll{overflow-x:auto}.error{background:#ffe8e8;padding:14px;border-radius:8px}.success{background:#e6f7ed;padding:14px;border-radius:8px}@media(max-width:650px){form.grid{grid-template-columns:1fr}.wide{grid-column:1}main{padding:12px}}
</style></head><body>
<header><strong>Fire Safety BD · Marketplace Admin</strong> &nbsp; <a href="fire_safety_job_prep_dashboard.php">← Dashboard</a> &nbsp; <a href="logout.php">Logout</a></header>
<main>
<?php if ($error !== ''): ?><p class="error"><?= h($error) ?></p><?php endif; ?>
<?php if (isset($_GET['saved'])): ?><p class="success">Changes saved.</p><?php endif; ?>
<p><a href="marketplace_engagement_admin.php">Product Reviews &amp; Banners →</a></p>
<nav class="tabs">
<?php foreach (['products'=>'Products','services'=>'Services','categories'=>'Categories','orders'=>'Orders','requests'=>'Service Requests'] as $key=>$label): ?>
<a class="<?= $tab === $key ? 'active' : '' ?>" href="?tab=<?= h($key) ?>"><?= h($label) ?></a>
<?php endforeach; ?></nav>
<?php if ($tab === 'products' || $tab === 'services' || $tab === 'categories'): ?>
<section class="panel"><h2><?= $edit ? 'Edit' : 'Add' ?> <?= h(['products'=>'Product','services'=>'Service','categories'=>'Category'][$tab]) ?></h2>
<form method="post" class="grid">
<input type="hidden" name="csrf_token" value="<?= h($token) ?>"><input type="hidden" name="action" value="save_<?= h(['products'=>'product','services'=>'service','categories'=>'category'][$tab]) ?>"><input type="hidden" name="id" value="<?= field($edit,'id') ?>">
<label>Name<input name="name" maxlength="200" required value="<?= field($edit,'name') ?>"></label>
<label>Slug (English lowercase + hyphens)<input name="slug" maxlength="180" required value="<?= field($edit,'slug') ?>" placeholder="fire-extinguisher"></label>
<?php if ($tab === 'categories'): ?>
<label>Category type<select name="category_type"><option value="both"<?= selected($edit,'category_type','both','both') ?>>Both</option><option value="product"<?= selected($edit,'category_type','product') ?>>Product</option><option value="service"<?= selected($edit,'category_type','service') ?>>Service</option></select></label>
<label>Sort order<input type="number" name="sort_order" value="<?= field($edit,'sort_order','0') ?>"></label>
<label class="wide"><input type="checkbox" name="is_active" value="1" style="width:auto;display:inline"<?= checked($edit,'is_active',true) ?>> Active</label>
<?php else: ?>
<label>Category<select name="category_id"><option value="">Uncategorized</option>
<?php foreach ($categories as $c): if ($c['category_type'] !== 'both' && $c['category_type'] !== ($tab === 'products' ? 'product' : 'service')) continue; ?>
<option value="<?= (int)$c['id'] ?>"<?= (string)($edit['category_id'] ?? '') === (string)$c['id'] ? ' selected' : '' ?>><?= h($c['name']) ?></option>
<?php endforeach; ?></select></label>
<label>Image URL (HTTPS)<input name="image_url" type="url" value="<?= field($edit,'image_url') ?>" placeholder="https://..."></label>
<label>Status<select name="status"><?php foreach (['draft','published','archived'] as $status): ?><option value="<?= h($status) ?>"<?= selected($edit,'status',$status,'draft') ?>><?= h(ucfirst($status)) ?></option><?php endforeach; ?></select></label>
<label>Price (BDT)<?php if ($tab === 'services'): ?>, optional<?php endif; ?><input name="price" inputmode="decimal" value="<?= field($edit,'price', $tab === 'products' ? '0.00' : '') ?>"<?= $tab === 'products' ? ' required' : '' ?>></label>
<?php if ($tab === 'products'): ?>
<label>SKU<input name="sku" maxlength="100" value="<?= field($edit,'sku') ?>"></label>
<label>Compare price (optional)<input name="compare_price" inputmode="decimal" value="<?= field($edit,'compare_price') ?>"></label>
<label>Stock quantity<input name="stock_quantity" type="number" min="0" required value="<?= field($edit,'stock_quantity','0') ?>"></label>
<?php else: ?>
<label>Pricing type<select name="pricing_type"><?php foreach (['quote','fixed','starting'] as $type): ?><option value="<?= h($type) ?>"<?= selected($edit,'pricing_type',$type,'quote') ?>><?= h(ucfirst($type)) ?></option><?php endforeach; ?></select></label>
<?php endif; ?>
<label class="wide"><input type="checkbox" name="is_featured" value="1" style="width:auto;display:inline"<?= checked($edit,'is_featured') ?>> Featured</label>
<?php endif; ?>
<label class="wide">Description<textarea name="description"><?= field($edit,'description') ?></textarea></label>
<div class="wide"><button type="submit">Save</button> <a href="?tab=<?= h($tab) ?>">Clear form</a></div>
</form></section>
<?php endif; ?>
<?php if ($tab === 'orders'): ?>
<section class="panel"><h2>Delivery charge (BDT)</h2>
<?php if ($orderUpgradeReady): ?>
<form method="post">
<input type="hidden" name="csrf_token" value="<?= h($token) ?>">
<input type="hidden" name="action" value="delivery_fee">
<label>Flat fee per non-empty order<input name="flat_fee" type="number" min="0" max="9999999999.99" step="0.01" required value="<?= h(market_order_money(market_delivery_fee($pdo))) ?>"></label>
<button>Save delivery charge</button>
<p><small>Default is zero. Existing order totals are never changed. Older apps cannot place an order with a nonzero charge until updated.</small></p>
</form>
<?php else: ?><p>Deploy the order helper and SQL migration to enable delivery pricing and order updates.</p><?php endif; ?>
</section>
<?php endif; ?>
<section class="panel"><h2><?= h(ucfirst($tab)) ?></h2><div class="scroll"><table><thead><tr>
<?php if ($tab === 'products'): ?><th>ID</th><th>Product</th><th>Price</th><th>Stock</th><th>Status</th><th>Action</th>
<?php elseif ($tab === 'services'): ?><th>ID</th><th>Service</th><th>Pricing</th><th>Status</th><th>Action</th>
<?php elseif ($tab === 'categories'): ?><th>ID</th><th>Category</th><th>Type</th><th>Active</th><th>Action</th>
<?php elseif ($tab === 'orders'): ?><th>Order</th><th>Customer</th><th>Total</th><th>Payment</th><th>Status</th><th>Items</th>
<?php else: ?><th>Request</th><th>Service</th><th>Customer</th><th>Location</th><th>Status</th><?php endif; ?>
</tr></thead><tbody>
<?php
$table = ['products'=>'market_products','services'=>'market_services','categories'=>'market_categories','orders'=>'market_orders','requests'=>'market_service_requests'][$tab];
$rows = $pdo->query("SELECT * FROM $table ORDER BY id DESC LIMIT 200")->fetchAll();
$itemQuery = $pdo->prepare('SELECT product_name,quantity,unit_price,total_price FROM market_order_items WHERE order_id=? ORDER BY id');
foreach ($rows as $r): ?>
<tr>
<?php if ($tab === 'products'): ?>
<td><?= (int)$r['id'] ?></td><td><?= h($r['name']) ?><br><small><?= h($r['sku']) ?></small></td><td>৳<?= h($r['price']) ?></td><td><?= (int)$r['stock_quantity'] ?></td><td><?= h($r['status']) ?></td><td><a href="?tab=products&amp;edit=<?= (int)$r['id'] ?>">Edit</a></td>
<?php elseif ($tab === 'services'): ?>
<td><?= (int)$r['id'] ?></td><td><?= h($r['name']) ?></td><td><?= h($r['pricing_type']) ?> / <?= h($r['price']) ?></td><td><?= h($r['status']) ?></td><td><a href="?tab=services&amp;edit=<?= (int)$r['id'] ?>">Edit</a></td>
<?php elseif ($tab === 'categories'): ?>
<td><?= (int)$r['id'] ?></td><td><?= h($r['name']) ?></td><td><?= h($r['category_type']) ?></td><td><?= (int)$r['is_active'] ? 'Yes' : 'No' ?></td><td><a href="?tab=categories&amp;edit=<?= (int)$r['id'] ?>">Edit</a></td>
<?php elseif ($tab === 'orders'): ?>
<td><?= h($r['order_number']) ?><br><small><?= h($r['created_at']) ?></small></td>
<td><?= h($r['customer_name']) ?><br><?= h($r['mobile_number']) ?><br><?= h($r['delivery_address']) ?></td>
<td>৳<?= h($r['total_amount']) ?><br><small>Subtotal: ৳<?= h($r['subtotal']) ?><br>Delivery: ৳<?= h($r['delivery_charge']) ?></small></td><td><?= h($r['payment_method']) ?> / <?= h($r['payment_status']) ?></td>
<td><strong><?= h($r['order_status']) ?></strong>
<?php if ($orderUpgradeReady):
    $nextStatuses = market_order_next((string)$r['order_status']);
    $managed = market_order_managed($pdo,(int)$r['id']);
    $eventQuery = $pdo->prepare('SELECT order_status,created_at,courier_name,tracking_number FROM market_order_events WHERE order_id=? ORDER BY id');
    $eventQuery->execute([(int)$r['id']]);
    foreach ($eventQuery->fetchAll(PDO::FETCH_ASSOC) as $event): ?>
    <div><small><?= h($event['order_status']) ?> · <?= h($event['created_at']) ?> <?= h($event['courier_name'] ?? '') ?> <?= h($event['tracking_number'] ?? '') ?></small></div>
<?php endforeach; if ($nextStatuses): ?>
<form method="post" onsubmit="return confirm('Confirm order status change?');">
<input type="hidden" name="csrf_token" value="<?= h($token) ?>"><input type="hidden" name="action" value="order_status"><input type="hidden" name="id" value="<?= (int)$r['id'] ?>">
<select name="order_status" required><option value="">Select next status</option><?php foreach ($nextStatuses as $s): ?><option value="<?= h($s) ?>"><?= h($s) ?></option><?php endforeach; ?></select>
<?php if (in_array('shipped',$nextStatuses,true)): ?>
<label>Courier (optional)<input name="courier_name" maxlength="100"></label>
<label>Tracking number (optional)<input name="tracking_number" maxlength="150"></label>
<?php endif; ?>
<?php if (!$managed && in_array('cancelled',$nextStatuses,true)): ?>
<label><input type="checkbox" name="legacy_reconciled" value="1" style="width:auto;display:inline"> Legacy order: I will reconcile stock manually if cancelling.</label>
<?php endif; ?><button>Update</button></form>
<?php endif; endif; ?></td>
<td><?php $itemQuery->execute([(int)$r['id']]); foreach ($itemQuery->fetchAll() as $line): ?><?= h($line['product_name']) ?> × <?= (int)$line['quantity'] ?><br><?php endforeach; ?></td>
<?php else: ?>
<td><?= h($r['request_number']) ?><br><small><?= h($r['created_at']) ?></small></td><td>#<?= (int)$r['service_id'] ?><br><?= h($r['request_details']) ?></td><td><?= h($r['customer_name']) ?><br><?= h($r['mobile_number']) ?><br><?= h($r['company_name']) ?></td><td><?= h($r['service_location']) ?><br><?= h($r['preferred_date']) ?></td>
<td><form method="post"><input type="hidden" name="csrf_token" value="<?= h($token) ?>"><input type="hidden" name="action" value="request_status"><input type="hidden" name="id" value="<?= (int)$r['id'] ?>"><select name="status"><?php foreach (['pending','reviewing','approved','completed','rejected','cancelled'] as $s): ?><option value="<?= h($s) ?>"<?= $r['status'] === $s ? ' selected' : '' ?>><?= h($s) ?></option><?php endforeach; ?></select><button>Update</button></form></td>
<?php endif; ?></tr>
<?php endforeach; ?>
<?php if (!$rows): ?><tr><td colspan="7">No records yet.</td></tr><?php endif; ?>
</tbody></table></div></section>
<p><small>New unpaid COD orders restore reserved stock once on pre-shipment cancellation. Legacy orders require manual reconciliation. Shipped/delivered or paid orders cannot be cancelled here. Only COD is supported.</small></p>
</main></body></html>
