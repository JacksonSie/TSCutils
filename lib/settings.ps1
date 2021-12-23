<#
 # 常用設定檔
 #>

$timeoutSec = 10 #發起 request 的最大等待時間(sec)
$default_account = "xxxx" #sso 登入預設帳號
$default_pwd = 'yyyy'
$default_adaccount="zzzz"
#登入帳密所在的組別
$自己組別 = @{depno = '01'; divino = '02' }

$deptList = @{  #全部門列表
    "A" = "A-A";
    "B" = "B-B";
    "C" = "C-C";
    "D" = "D-D";
    "E" = "E-E";
    "F" = "F-F";
    "G" = "G-G";
    "H" = "H-H";
    "I" = "I-I";
    "J" = "J-J";
    "K" = "K-K";
    "L" = "L-L";
    "M" = "M-M";
    "N" = "N-N";
    "O" = "O-O";
    "P" = "P-P";
    "Q" = "Q-Q";
    "R" = "R-R";
    "S" = "S-S";
    "T" = "T-T";
    "U" = "U-U";
    "V" = "V-V";
    "W" = "W-W";
}

$crawler_csv = "email_$(Get-Date -UFormat '%Y%m%dT%H%M%S').csv" #抓取email的存放位置



$RSarg = "Z1^*^系統^*^http://oooo2.com.tw/aaa/Index.aspx"
$PEarg = "Z2^*^系統^*^http://oooo3.com.tw/aaa/AppHome.aspx"

$aes_key_source = "aaa"



#還原資料庫相關參數
$global:remote_db = 'oooo1.com.tw'
$global:local_db = 'oooo3.com.tw'
$global:remote_disk_physical = "db.bak_rotatable\"
$global:remote_disk_samba = "\\oooo1.com.tw\b.bak_rotatable\"
$global:local_disk_physical = "E:\test\db.bak_rotatable\"
$global:backup_filename = "{0}.{1}.bak"
$global:backup_list = @("A", "B", "C", "D", "E", "F")