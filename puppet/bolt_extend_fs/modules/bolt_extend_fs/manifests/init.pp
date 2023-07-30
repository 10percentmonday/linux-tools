class bolt_extend_fs (
    Array[Hash] $lv_info = loadjson("/home/a127769_tr1/tool/puppet/bolt_extend_fs/custom_facts.json", 'ERROR: Failed to load json'),
) {
    include bolt_extend_fs::extend_lv
}
