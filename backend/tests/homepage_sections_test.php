<?php
declare(strict_types=1);
require_once __DIR__.'/../homepage_sections.php';
function hp_expect(array $actual,array $expected):void{
 if($actual!==$expected)throw new RuntimeException('Homepage order mismatch');
}
hp_expect(hp_section_order('banners,marketplace,progress'),['banners','marketplace','career','progress']);
hp_expect(hp_section_order('jobs,career,marketplace'),['jobs','career','marketplace']);
hp_expect(hp_section_order('banners,jobs'),['banners','career','jobs']);
hp_expect(hp_section_order(hp_store_section_order(['jobs','marketplace'])),['jobs','marketplace']);
hp_expect(hp_section_order(hp_store_section_order([])),[]);
hp_expect(hp_section_order('career,career,unknown,jobs'),['career','jobs']);
echo "Homepage section tests passed\n";
