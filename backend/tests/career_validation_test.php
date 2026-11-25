<?php
declare(strict_types=1);
require_once __DIR__.'/../career_common.php';
function check(bool $ok):void{if(!$ok)throw new RuntimeException('Career validation test failed');}
function rejects(callable $fn):void{try{$fn();}catch(DomainException $e){return;}throw new RuntimeException('Invalid input accepted');}
check(career_public_text('Fire Officer',120,true)==='Fire Officer');
check(career_public_text('ঢাকা',100)==='ঢাকা');
rejects(fn()=>career_public_text('01712345678',100));
rejects(fn()=>career_public_text('০১৭১২৩৪৫৬৭৮',100));
rejects(fn()=>career_public_text('me@example.com',100));
rejects(fn()=>career_public_text('https://example.com',100));
rejects(fn()=>career_text('',100,true));
rejects(fn()=>career_url('javascript:alert(1)'));
rejects(fn()=>career_url('https://user@example.com'));
check(career_url('https://example.com/course')==='https://example.com/course');
rejects(fn()=>career_id('0'));
check(career_id('12')===12);
echo "Career validation passed\n";
