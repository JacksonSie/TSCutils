<#
 # �`�γ]�w��
 #>

$timeoutSec = 10 #�o�_ request ���̤j���ݮɶ�(sec)
$default_account = "ooo" #sso �n�J�w�]�b��
$default_pwd = 'ooo'
$default_adaccount="ooo"
#�n�J�b�K�Ҧb���էO
$�ۤv�էO = @{depno = '01'; divino = '69' }

$deptList = @{  #���������M��ɡA�������C��
    "01" = "01-oo�B";
}

$crawler_csv = "ooo\email\�����qemail_$(Get-Date -UFormat '%Y%m%dT%H%M%S').csv" #���email���s���m



$RSarg = "RS^*^ooo�t��^*^http://ooo.tw/ooo/Index.aspx"
$PEarg = "PE^*^ooo�t��^*^http://ooo/App/AppHome.aspx"

$aes_key_source = "ooo"



#�٭��Ʈw�����Ѽ�
$global:remote_db = 'ooo'
$global:local_db = 'localhost'
$global:remote_disk_physical = "ooo\db.bak_rotatable\"
$global:remote_disk_samba = "\\ooo\db.bak_rotatable\"
$global:local_disk_physical = "E:\test\db.bak_rotatable\"
$global:backup_filename = "{0}.{1}.bak"
$global:backup_list = @("oooDB")
