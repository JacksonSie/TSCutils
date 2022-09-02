. "$PSScriptRoot\settings.ps1"

class sql_query {

    [string]$db_name

    sql_query(){}
    
    sql_query($db_name){
        $this.db_name = $db_name
    }

    [string] backup_db( $disk_physical){
        return "BACKUP DATABASE [{0}] TO DISK='{1}';`n go" -f ($this.db_name , $disk_physical)
    }
    [string] single_user(){
        return "ALTER DATABASE [{0}] SET SINGLE_USER WITH ROLLBACK /*AFTER 10*/ IMMEDIATE ;`n go"  -f ($this.db_name)
    }
    [string] multi_user(){
        return "ALTER DATABASE [{0}] SET MULTI_USER;`n go"  -f ($this.db_name)
    }
    [string] use_db(){
         return "use [{0}];`n go" -f ($this.db_name)
    }

    [string] use_db($db_name){
         return "use [{0}];`n go" -f ($db_name)
    }

    [string] restore_db($restore_file,$mdf_name,$mdf_path,$log_name,$log_path){
        return @"
            RESTORE DATABASE [{0}] FROM DISK='{1}'
            WITH MOVE '{2}' TO '{3}', MOVE '{4}' TO '{5}', RECOVERY,REPLACE;`n go
"@      -f (
            $this.db_name,
            $restore_file,
            $mdf_name,
            $mdf_path,
            $log_name,
            $log_path
        )
    }

    [string] physical_file_loc(){
        return @"
            use master
                SELECT
                    db.name AS DBName,
                    type_desc AS FileType,
                    mf.name as file_name,
                    Physical_Name AS Location
                FROM
                    sys.master_files mf
                INNER JOIN 
                    sys.databases db ON db.database_id = mf.database_id
                where db.name = '{0}' and type_desc in ('ROWS' , 'LOG');`n go
"@          -f ($this.db_name)
    }

    [string] list_orphaned_logins(){
        return @"
            select 'sp_change_users_login '+
	            '@Action ='+QUOTENAME('Update_One','''')+
	            ',@UserNamePattern='+QUOTENAME(a.name,'''')+
	            ',@LoginName ='+QUOTENAME(a.name,'''')+
	            char(13)+char(10) as past_and_go
            from (
            SELECT DP.name, DP.type_desc,
                   CASE WHEN SP.sid IS NOT NULL THEN 1 ELSE 0 END has_name_match,
                   CASE WHEN SP.sid = DP.sid THEN 1 ELSE 0 END is_name_sid_matched,
                   CASE WHEN SP2.sid IS NOT NULL THEN SP2.name END has_sid_match,
                   CASE WHEN dp2.sid IS NOT NULL THEN 1 ELSE 0 END name_sid_conflict
              FROM  sys.server_principals AS SP
              LEFT JOIN sys.database_principals AS DP
                ON DP.name = SP.name COLLATE SQL_Latin1_General_CP1_CI_AS
              LEFT JOIN sys.database_principals AS DP2
                ON SP.sid = DP2.sid AND DP.principal_id <> DP2.principal_id
              LEFT JOIN sys.server_principals AS SP2
                ON DP.sid = SP2.sid
            --WHERE DP.authentication_type_desc IN ('INSTANCE','WINDOWS')
              where DP.principal_id>1
              )a
            where name is not null AND has_sid_match IS NULL AND name_sid_conflict = 0
"@
    }

    [string] fix_init_page(){
        return "
            use [publicdb] 
            go
            update SysKind set SysDirPath=replace(SysDirPath,'http://ooo','');   
            update SysKind set SysDirPath=replace(SysDirPath,'http://ooo','');
            update SysKind set SysDirPath=replace(SysDirPath,'https://ooo.tw','');            
            update SysKind set SysDirPath=replace(SysDirPath,'https://ooo.tw','');         
            update SysKind set SysDirPath=replace(SysDirPath,'http://ooo.tw','');          
            update SysKind set SysDirPath=replace(SysDirPath,'http://ooo.tw','');          
            go
            
            
            declare @pass varchar(255)=''
            
            update UserAccount 
            set 
                password = CONVERT(nvarchar(64), HASHBYTES('SHA2_256','oooo'+@pass),2)
                ,UserId=UserNo

            update UserSysKind 
            set 
                OpeningDate='20001111'
                ,UseDueDate='20991111' 
                ,LastLoginDate='20991111'

            update UserAccount 
            set 
                OpeningDate='20001111' 
                ,PwdDueDate='20991111'
                ,UseDueDate='20991111'
                ,ErrorNumbers=-1
                ,LastLoginDate='20991111'
            
            update UserAccount set UserId='' where UserNo ='ooo'
            go
         
            --fix symkey
            use publicdb
            go
            
            DECLARE @name NVARCHAR(50),@exesql nvarchar(max); 
            DECLARE _cursor CURSOR FOR select name from master.sys.server_principals where name like 'SYS___'

            --  
            OPEN _cursor
            FETCH NEXT FROM _cursor INTO @name
            WHILE @@FETCH_STATUS = 0 BEGIN

            select @exesql = 'GRANT REFERENCES ON SYMMETRIC KEY::PUBLICDBSYM TO ' + @name
            --print @exesql
            EXEC sp_executesql @exesql

            FETCH NEXT FROM _cursor INTO @name;
            END
            CLOSE _cursor
            DEALLOCATE _cursor
        "
        
    }

}

function get_backup_db(){
    $db_list=$global:backup_list
    return $db_list
}

function backup_remote($db_list){
    $backup_dictionary=@{}
    $_remote_disk_physical = $global:remote_disk_physical
    $_backup_filename = $global:backup_filename
    $_remote_disk_samba = $global:remote_disk_samba
    $operating_path = $($_remote_disk_physical + $_backup_filename)
    $copy_path = $($_remote_disk_samba + $_backup_filename)
    
    foreach($db_name in $db_list){
        $db_operating = $operating_path -f ($db_name,$(get-date -format "yyyyMMddTHHmmss"))
        $copyable = $copy_path -f ($db_name,$(get-date -format "yyyyMMddTHHmmss"))
        if (backup_worker $db_name $db_operating ){
            $backup_dictionary[$db_name] = $copyable
        }
    }
    return $backup_dictionary
}

function backup_worker($db_input,$backup_file){
    $_remote_db = $global:remote_db
    #backup
    $sql_query=[sql_query]::new()
    $sql_query.db_name = $db_input
    $use = $sql_query.use_db()
    $backup_db = $sql_query.backup_db($backup_file)
    sqlcmd -E -S $_remote_db -d $db_input -Q $backup_db #trust

    #todo:verify
    
    return $true
}

function mover($db_bakup_done){
    $move_dictionary=@{}
    $_remote_disk_samba = $global:remote_disk_samba
    $_local_disk_physical = $global:local_disk_physical

    $db_bakup_done.keys | foreach {
        $remote_path = $db_bakup_done[$_]
        $file_name = $remote_path.Split('\')[-1]
        
        move $remote_path $_local_disk_physical
        $move_dictionary[$_] = $_local_disk_physical + $file_name
    }
    return $move_dictionary
}

function restore_local($restore_list){
    $sql_query=[sql_query]::new()
    $restore_done=New-Object Collections.Generic.List[string]
    $_local_db = $global:local_db
    $restore_list.keys | foreach {
        $sql_recovery = ""
        $sql_fix_users_and_logins = ""
        $orphaned_list = ""
        $local_bak_file = $restore_list[$_]
        $_db_input = $_
        $sql_query.db_name = $_db_input
        $dbfile_info = Invoke-Sqlcmd -ServerInstance $_local_db -Database $_db_input -Query $sql_query.physical_file_loc()
        $mdf_name = $($dbfile_info | Where-Object {$_.FileType -eq "ROWS"}).file_name
        $mdf_file = $($dbfile_info | Where-Object {$_.FileType -eq "ROWS"}).Location
        $mdl_name = $($dbfile_info | Where-Object {$_.FileType -eq "LOG"}).file_name
        $mdl_file = $($dbfile_info | Where-Object {$_.FileType -eq "LOG"}).Location

        $sql_recovery += $sql_query.use_db("master")
        $sql_recovery += "`n" + $sql_query.single_user()
        $sql_recovery += "`n" + $sql_query.restore_db($local_bak_file,$mdf_name,$mdf_file,$mdl_name,$mdl_file)
        $sql_recovery += "`n" + $sql_query.multi_user()

        Invoke-Sqlcmd -ServerInstance "$_local_db" -Database "$_db_input" -Query $sql_recovery


        $orphaned_list += $sql_query.list_orphaned_logins()

        $orphaned_list = Invoke-Sqlcmd -ServerInstance $_local_db -Database $_db_input -Query $orphaned_list
        $orphaned_list.past_and_go |foreach{
            $sql_fix_users_and_logins += $_
            $sql_fix_users_and_logins += "`n go `n"
            
        }
        $sql_fix_users_and_logins =  $sql_query.use_db() + "`n" + $sql_fix_users_and_logins

        $sql_fix_users_and_logins += "`n" + $sql_query.fix_init_page()
        
        Invoke-Sqlcmd -ServerInstance $_local_db -Database $_db_input -Query $sql_fix_users_and_logins

        #Write-Output  "$_db_input restored successfully"
        $restore_done.Add($_db_input)
    }

    return $restore_done
    
}