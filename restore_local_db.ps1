. "$PSScriptRoot\lib\restore_db.ps1"
. "$PSScriptRoot\lib\settings.ps1"

$db_list=get_backup_db
$db_bakup_done = backup_remote $db_list
$move_done = mover $db_bakup_done
$restore_success_list = restore_local $move_done
foreach($restore_success in $restore_success_list){
    Write-Output $restore_success
}