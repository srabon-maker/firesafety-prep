<?php
declare(strict_types=1);

/** Caller must authenticate admin and verify CSRF. Permanent deletion is single-post only. */
function community_admin_delete_post(PDO $pdo, int $id): string {
    if ($id<1 || $pdo->inTransaction()) throw new InvalidArgumentException('সঠিক পোস্ট নির্বাচন করুন।');
    // Fail closed if the live schema cannot guarantee atomic dependent-row cleanup.
    if ((int)$pdo->query('SELECT @@SESSION.foreign_key_checks')->fetchColumn()!==1) {
        throw new RuntimeException('Community foreign key checks disabled');
    }
    $fk=$pdo->query("SELECT DISTINCT k.TABLE_NAME FROM information_schema.KEY_COLUMN_USAGE k
        JOIN information_schema.REFERENTIAL_CONSTRAINTS r
          ON r.CONSTRAINT_SCHEMA=k.CONSTRAINT_SCHEMA AND r.CONSTRAINT_NAME=k.CONSTRAINT_NAME AND r.TABLE_NAME=k.TABLE_NAME
        WHERE k.TABLE_SCHEMA=DATABASE() AND k.REFERENCED_TABLE_SCHEMA=DATABASE()
          AND k.COLUMN_NAME='post_id' AND k.REFERENCED_TABLE_NAME='community_posts'
          AND k.REFERENCED_COLUMN_NAME='id' AND r.DELETE_RULE='CASCADE'")->fetchAll(PDO::FETCH_COLUMN);
    $required=['community_comments','community_post_likes','community_reports'];
    if (array_diff($required,$fk)) throw new InvalidArgumentException('পোস্ট মোছার আগে ডেটাবেসের Cascade সম্পর্ক যাচাই করুন।');
    $engines=$pdo->query("SELECT TABLE_NAME FROM information_schema.TABLES
        WHERE TABLE_SCHEMA=DATABASE() AND ENGINE='InnoDB'
        AND TABLE_NAME IN ('community_posts','community_comments','community_post_likes','community_reports')")->fetchAll(PDO::FETCH_COLUMN);
    if (array_diff([...$required,'community_posts'],$engines)) throw new RuntimeException('Community tables must be transactional');
    $pdo->beginTransaction();
    try {
        $q=$pdo->prepare('SELECT id,image_path FROM community_posts WHERE id=? FOR UPDATE');
        $q->execute([$id]);
        $post=$q->fetch(PDO::FETCH_ASSOC);
        if (!$post) throw new InvalidArgumentException('পোস্টটি পাওয়া যায়নি অথবা আগেই মুছে ফেলা হয়েছে।');
        $q=$pdo->prepare('DELETE FROM community_posts WHERE id=?');
        $q->execute([$id]);
        if ($q->rowCount()!==1) throw new RuntimeException('Community delete did not affect one post');
        $pdo->commit();
    } catch (Throwable $e) {
        if ($pdo->inTransaction()) $pdo->rollBack();
        throw $e;
    }
    // Database commit is authoritative; filesystem cleanup is best effort.
    $message='পোস্ট এবং সংশ্লিষ্ট মন্তব্য, লাইক ও রিপোর্ট স্থায়ীভাবে মুছে ফেলা হয়েছে।';
    $image=(string)($post['image_path']??'');
    if ($image==='') return $message;
    try {
        if (!preg_match('/\A[a-f0-9]{32}\.(?:jpg|png|webp)\z/D',$image)) throw new RuntimeException('Unexpected image filename');
        $q=$pdo->prepare('SELECT COUNT(*) FROM community_posts WHERE image_path=?');
        $q->execute([$image]);
        if ((int)$q->fetchColumn()>0) return $message.' ছবিটি অন্য পোস্টে ব্যবহৃত হওয়ায় রাখা হয়েছে।';
        $dir=__DIR__.'/uploads/community';
        if (!is_dir($dir) || is_link($dir)) throw new RuntimeException('Community upload directory unavailable');
        $path=$dir.'/'.$image;
        if (is_link($path)) throw new RuntimeException('Unexpected image symlink');
        if (file_exists($path) && (!is_file($path) || !@unlink($path))) throw new RuntimeException('Image unlink failed');
        return $message;
    } catch (Throwable $e) {
        error_log('Community image cleanup after post deletion: '.$e->getMessage());
        return $message.' তবে সংযুক্ত ছবিটি স্বয়ংক্রিয়ভাবে সরানো যায়নি; ফাইল ম্যানেজারে যাচাই করুন।';
    }
}
