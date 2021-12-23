<#
 # 說明 : 抓取打卡時間 
 #        sso Server -> HR App Server -> cardtimeQuery.aspx
 #        顯示 cardtimeQuery 第一頁
 #>

Add-Type -AssemblyName System.Web
. "$PSScriptRoot\lib\utils.ps1"
. "$PSScriptRoot\lib\settings.ps1"

$account,$pwd = accountPwd
$ssoToken , $ASP_SessionID , $__VIEWSTATE_Main_page , $login_session = ssoLogin $account $pwd
$ASP_SessionID , $__VIEWSTATE , $__VIEWSTATEGENERATOR , $__EVENTVALIDATION , $ssoToken , $session_landing = WebLogin $ssoToken $PEarg $login_session

$cardTimeQuery = Invoke-WebRequest -WebSession $session_landing -TimeoutSec $timeoutSec -Uri "http://ooo.com.tw/CFG/CardTimeQuery.aspx" -Method "POST" -Headers @{"cookie"="ASP.NET_SessionId=$($ASP_SessionID)"} -Body "__VIEWSTATE=$__VIEWSTATE&__VIEWSTATEGENERATOR=$__VIEWSTATEGENERATOR&__EVENTVALIDATION=$__EVENTVALIDATION"

if ($cardTimeQuery -eq $null) {
    throw 'can''t read response from card time query page'
    exit
}
Write-Host -NoNewline '.'

#parse html table
$table = parseHTMLTable $cardTimeQuery "`t"

$index=12
$index_list = (0..($table.Count - 1)) | Where-Object { $table[$_] -eq ""}
if($index_list[-1] -gt 0) {
    $index = $index_list[-1]+1
    $table=$table | Select-Object -Skip $index
} else {
    $table=$table | Select-Object -Last $index
    }
Write-Host
$table
