

# Assuming the Puppet LVM module already installed 
class bolt_extend_fs::extend_lv {
 $lv_info.each|$info| { 
  $_lv_name = $info['lv_name']
  $_vg_name = $info['vg_name']
  $_fs_type = $info['fs_name']
  
  #notice("lv_name: ${_lv_name}")
  #notice("vg_name: ${_vg_name}")
  #notice("fs_type: ${_fs_type}")

  logical_volume { $_lv_name:
   ensure       => present,
   volume_group => $_vg_name,
   size         => '+10m',
   require      => Volume_group[$_vg_name],
   notify       => Exec['lv_size_changed'],
  }
 }
}

 #exec { 'lv_size_changed':
 #     command => "./lv_size_changed.sh $_lv_name",
 #     refreshonly => true,
 # }
 # class { 'bolt_extend_fs::extend_filesystem':
 #   lv_name => $_lv_name,
 #   vg_name => $_vg_name,
 #   fs_type => $_fs_type,
 # }
 #}

 #class bolt_extend_fs::extend_filesystem (
 # String $lv_name,
 # String $vg_name,
 # String $fs_type,
 #) {
 # if $facts['lv_size_changed'] {     
 #   $old_lvsize = $facts['lv_size_changed']['old']
 #   $new_lvsize = $facts['lv_size_changed']['new']
 #   if $new_lvsize > $old_lvsize {
 #     #Volume size has changed, so extend the filesystem
 #     filesystem { $_lv_name:
 #       ensure   => present,
 #       device   => "/dev/$_vg_name/$_lv_name",
 #       fs_type  => $_fs_type,
 #       require  => Logical_volume[$_lv_name],
 #     }
 #   }
 # }
#}

#the logical_volume resource is declared with the notify attribute set to Exec['lv_size_changed']. 
#Here's what happens when the class is evaluated:
#
#1.Whenever the logical_volume resource is applied (e.g., during a Puppet run), 
#if it triggers a change (e.g., the logical volume's size is modified), 
#it will notify the resource with the title 'lv_size_changed'.
#
#2.The notify attribute will not trigger the Exec['lv_size_changed'] resource immediately 
#during the same Puppet run. Instead, it marks the Exec['lv_size_changed'] resource as 
#"scheduled to be refreshed."
#
#3.After all the resources in the catalog are applied, Puppet will go through the "refresh" 
#process. During this process, it checks all the resources that were marked for refresh 
#(due to notifications) and executes them in a separate pass.
#
#4.If the logical_volume resource actually caused a change (e.g., increased the size of the 
#logical volume), then the Exec['lv_size_changed'] resource will be executed as part of the 
#refresh process.
#
#So, to answer your question: The notify attribute will not run the Exec['lv_size_changed'] 
#resource every single time the class extend_lv runs. Instead, it will trigger the execution 
#of Exec['lv_size_changed'] only if the logical_volume resource causes a change (e.g., modifies the size of the logical volume) and during the subsequent refresh process.
#
#In summary, the notify attribute in Puppet is used to schedule resources for refresh and execute them after the regular catalog application process if they are marked for refresh. This helps ensure that certain resources are executed in the correct order when they depend on changes made by other resources.
