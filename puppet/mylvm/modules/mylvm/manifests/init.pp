class mylvm (
    Array[Hash] $lv_info = loadjson("/home/a127769_tr1/tool/puppet/mylvm/custom_facts.json", 'ERROR: Failed to load json'),
) {
    include mylvm::extend_lv
    include mylvm::extend_filesystem
}
