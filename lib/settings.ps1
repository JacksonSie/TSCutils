<#
 # 常用設定檔
 #>

$timeoutSec = 10 #發起 request 的最大等待時間(sec)
$default_account = "ooo" #sso 登入預設帳號
$default_pwd = 'ooo'
$default_adaccount="ooo"
#登入帳密所在的組別
$自己組別 = @{depno = '01'; divino = '69' }

$deptList = @{  #爬取部門清單時，全部門列表
    "01" = "01-oo處";
}

$crawler_csv = "ooo\email\全公司email_$(Get-Date -UFormat '%Y%m%dT%H%M%S').csv" #抓取email的存放位置



$RSarg = "RS^*^ooo系統^*^http://ooo.tw/ooo/Index.aspx"
$PEarg = "PE^*^ooo系統^*^http://ooo/App/AppHome.aspx"

$aes_key_source = "ooo"



#還原資料庫相關參數
$global:remote_db = 'ooo'
$global:local_db = 'localhost'
$global:remote_disk_physical = "ooo\db.bak_rotatable\"
$global:remote_disk_samba = "\\ooo\db.bak_rotatable\"
$global:local_disk_physical = "E:\test\db.bak_rotatable\"
$global:backup_filename = "{0}.{1}.bak"
$global:backup_list = @("oooDB")
