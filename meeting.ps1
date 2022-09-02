<#
 #        sso Server -> RSWeb -> MR01
 #>

Add-Type -AssemblyName System.Web
. "$PSScriptRoot\lib\utils.ps1"
. "$PSScriptRoot\lib\settings.ps1"


$account,$pwd = accountPwd
$ssoToken , $ASP_SessionID , $__VIEWSTATE_Main_page , $login_session = ssoLogin $account $pwd
$ASP_SessionID , $__VIEWSTATE , $__VIEWSTATEGENERATOR , $__EVENTVALIDATION , $ssoToken , $session_landing = WebLogin $ssoToken $RSArg $login_session

#$statecode = get_html_value_byid $session_landing @('__EVENTARGUMENT','__VIEWSTATE','__VIEWSTATEGENERATOR','__VIEWSTATEENCRYPTED','__EVENTVALIDATION','__ASYNCPOST') -enable_encoding $false

<#$body = @{
    #"__EVENTARGUMENT" = $statecode['__EVENTARGUMENT']
    #"__VIEWSTATEENCRYPTED" = $statecode['__VIEWSTATEENCRYPTED']
    #"__ASYNCPOST" = $statecode['__ASYNCPOST']
    '__EVENTTARGET' = 'ctl00$ContentPlaceHolder1$GridView1$ctl02$ddlPageRecord'
    '__VIEWSTATE' = $__VIEWSTATE
    '__VIEWSTATEGENERATOR' = $__VIEWSTATEGENERATOR
    '__EVENTVALIDATION' = $__EVENTVALIDATION
    'ctl00%24ContentPlaceHolder1%24GridView1%24ctl02%24ddlPageRecord' = 10000
}#>

$response = Invoke-WebRequest -WebSession $session_landing -Uri "http://ooo.tw/RSWeb/mr/mr_01.aspx" -TimeoutSec $timeoutSec 


$table = parseHTMLTable $response "," |Select-Object -Last 16 | Select-Object -SkipLast 6
Write-Host
$table