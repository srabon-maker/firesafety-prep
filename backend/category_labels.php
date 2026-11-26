<?php
declare(strict_types=1);
// Display labels only. Never replace canonical category keys in requests.
function category_labels_ready(PDO $pdo): bool {
    static $ready=null;
    if ($ready!==null) return $ready;
    try { $pdo->query('SELECT name_bn,name_en FROM categories LIMIT 0'); return $ready=true; }
    catch (PDOException $e) { return $ready=false; }
}
function category_labels(PDO $pdo): array {
    static $rows=null;
    if ($rows!==null) return $rows;
    if (!category_labels_ready($pdo)) return $rows=[];
    return $rows=$pdo->query('SELECT id,name,category_type,name_bn,name_en FROM categories ORDER BY is_active DESC,id')->fetchAll(PDO::FETCH_ASSOC);
}
function category_label_for(PDO $pdo,string $type,?string $name=null,?int $id=null): array {
    foreach(category_labels($pdo) as $row) {
        if ($row['category_type']!==$type) continue;
        if ($id!==null ? (int)$row['id']!==$id : (string)$row['name']!==$name) continue;
        return ['category_name_bn'=>trim((string)$row['name_bn']),'category_name_en'=>trim((string)$row['name_en'])];
    }
    return ['category_name_bn'=>'','category_name_en'=>''];
}
function category_label_matches(PDO $pdo,string $type,string $search,string $key='name'): array {
    if ($search==='') return [];
    $matches=[];
    foreach(category_labels($pdo) as $row) {
        if ($row['category_type']!==$type) continue;
        foreach(['name','name_bn','name_en'] as $field) {
            if (mb_stripos((string)$row[$field],$search,0,'UTF-8')!==false) {
                $matches[]=$row[$key];break;
            }
        }
    }
    return array_values(array_unique($matches));
}
