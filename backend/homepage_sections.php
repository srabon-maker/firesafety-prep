<?php
declare(strict_types=1);
// Legacy stored orders get the new section after marketplace without a migration.
// career_off is an internal marker for an explicit admin opt-out, never an API section.
function hp_section_order(string $stored):array {
    $allowed=['banners','marketplace','career','progress','jobs','topics','notes','community','tips'];
    $tokens=array_map('trim',explode(',',$stored));
    $order=array_values(array_unique(array_intersect($tokens,$allowed)));
    if(in_array('career_off',$tokens,true)){
        return array_values(array_diff($order,['career']));
    }
    if(!in_array('career',$order,true)){
        $index=array_search('marketplace',$order,true);
        if($index===false)$index=array_search('banners',$order,true);
        array_splice($order,$index===false?0:$index+1,0,['career']);
    }
    return $order;
}
function hp_store_section_order(array $order):string {
    if(!in_array('career',$order,true))$order[]='career_off';
    return implode(',',$order);
}
