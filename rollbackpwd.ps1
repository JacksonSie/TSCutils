Add-Type -AssemblyName System.Web
. "$PSScriptRoot\lib\utils.ps1"
. "$PSScriptRoot\lib\settings.ps1"

$global:account=""
$global:historyPwd = @()
$global:adAccount=""
function main([int] $changeTimes) {

    $account, $pwdin = accountPwd
    $global:account = $account
    $global:historyPwd +=  $pwdin
    $global:adAccount = adAccount

    $rollbackpwd = set_rbkpwd;

    if ($rollbackpwd -eq "") {
        exit;
    }

    for ($i = 0; $i -le $changeTimes; $i++) {
        $rand_pwd = gen_pass
        $global:historyPwd +=  $rand_pwd;
        Write-Host -NoNewline "$i password $rand_pwd generated.";
        
        ChangeSSOpwd 0;
        ChangeSSOpwd 1;
        #ChangeSSOpwd 2;
        ChangeMailPwd;
        ChangeADPwd;
        Write-Host ''
    }

    $global:historyPwd += $rollbackpwd
    ChangeSSOpwd  0 #prod
    ChangeSSOpwd  1 #test
    #ChangeSSOpwd 2 #localhost
    ChangeMailPwd 
    ChangeADPwd 
    Write-Host "passwod recovery complete.";
}

function gen_pass() {
    $new_rand = ""
    Do {
        $new_rand = $( -join ((65..90)  | Get-Random -Count 3 | % { [char]$_ })) + 
        $( -join ((97..122) | Get-Random -Count 3 | % { [char]$_ })) + 
        '@' + 
        $( -join ((48..57)  | Get-Random -Count 3 | % { [char]$_ }));
    }
    Until(! ($new_rand -in $global:historyPwd))
    
    return $new_rand;
}

function set_rbkpwd() {
    $pwdret = (Read-Host "input rollback password (default:settings.`$default_pwd)" -AsSecureString);
    $pwdret = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($pwdret))
    $pwdret = if ($pwdret -ne "") { $pwdret }else { $default_pwd }
    $pwdrbkcmt = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($(Read-Host -Prompt 'retype rollback password' -AsSecureString)))

    if ($pwdret -ne $pwdrbkcmt) {
        Write-Error 'rollback password not match';
        return "";
    }
    return $pwdrbkcmt;
}

<#
type refer to util.ssoLogin.$type
#>
function ChangeSSOpwd ([int]$type = 0){
    $changePwdPage = @(
        'https://ooo.tw/Login/PwdUpdate.aspx',
        'https://ooo.tw/tstLogin/PwdUpdate.aspx',
        'http://localhost:2205/Login/PwdUpdate.aspx'
    )[$type]

    $ssoToken , $ASP_SessionID , $__VIEWSTATE_Main_page , $login_session = ssoLogin $global:account $global:historyPwd[-2]  $type
    $page_sessoion , $pageToken , $body = gotoPwdPage $ssoToken $type $login_session
    $reset = Invoke-WebRequest -WebSession $page_sessoion -TimeoutSec $timeoutSec -Uri "$($changePwdPage)?v=$($pageToken)" -Method "POST" -Body "$body&BtnConfirm=%E7%A2%BA++%E5%AE%9A&TxtNewAcct=$global:account&TxtNewSecretWd=$(uri_dataEncoding $global:historyPwd[-1])&TxtDoubleCheckNewSecretWd=$(uri_dataEncoding $global:historyPwd[-1])"
    Write-Host -NoNewline '.'
}

<#
$type:{(0 = prod);(1 = test);(2 = localhost)}
#>
function gotoPwdPage($ssoToken , $type , $session) {
    $mainPage = @(
        'https://ooo.tw/Login/Main.aspx',
        'https://ooo.tw/tstLogin/Main.aspx',
        'http://localhost:2205/Login/Main.aspx'
    )[$type]
    
    $lg_resp = Invoke-WebRequest -WebSession $session -TimeoutSec $timeoutSec -Uri "$($mainPage)?v=$($ssoToken)"
    
    $statecode = get_html_value_byid $lg_resp @('__VIEWSTATE', '__VIEWSTATEGENERATOR', '__RequestVerificationToken')
    $__VIEWSTATE = $statecode['__VIEWSTATE']
    $__VIEWSTATEGENERATOR = $statecode['__VIEWSTATEGENERATOR']
    $__RequestVerificationToken = $statecode['__RequestVerificationToken']
    $__EVENTTARGET = "%E8%AE%8A%E6%9B%B4%E5%B8%B3%E5%AF%86"
    $AParg_encoded = "%E8%AE%8A%E6%9B%B4%E5%B8%B3%E5%AF%86"

    $goto_resetPwd = Invoke-WebRequest -WebSession $session -Uri "$($mainPage)?v=$($ssoToken)" -TimeoutSec $timeoutSec -Method "POST" -Body "__VIEWSTATE=$__VIEWSTATE&__VIEWSTATEGENERATOR=$__VIEWSTATEGENERATOR&__EVENTTARGET=$__EVENTTARGET&__EVENTARGUMENT=$AParg_encoded&__RequestVerificationToken=$__RequestVerificationToken"
    $statecode = get_html_value_byid $goto_resetPwd @('__VIEWSTATE', '__VIEWSTATEGENERATOR', '__RequestVerificationToken', '__EVENTVALIDATION', '__EVENTTARGET', '__EVENTARGUMENT', 'ImageCaptcha_imgCaptcha')
    $ssoToken = $goto_resetPwd.BaseResponse.ResponseUri.AbsoluteUri | Select-String -Pattern 'v\=(\w+)$' -AllMatches | % { $_.matches.groups[1].value }
    $__VIEWSTATE =  $statecode['__VIEWSTATE']
    $__VIEWSTATEGENERATOR =  $statecode['__VIEWSTATEGENERATOR']
    $__RequestVerificationToken =  $statecode['__RequestVerificationToken']
    $__EVENTVALIDATION =  $statecode['__EVENTVALIDATION']
    $__EVENTTARGET =  $statecode['__EVENTTARGET']
    $__EVENTARGUMENT =  $statecode['__EVENTARGUMENT']
    $captchaBody = ""
    try {
        $captcha = $statecode['ImageCaptcha_imgCaptcha'] | Select-String -Pattern '%3Fhash%3D(\w+)' -AllMatches | % { $_.matches.groups[1].value } 
        $captcha = decrypt_function $captcha
        #write-host "got captcha $captcha"
        $captchaBody = "ImageCaptcha`$txtCaptcha=$captcha";
        if (![string]::IsNullOrEmpty($captchaBody)) { $captchaBody = "$captchaBody&" }
    }
    catch {}
    $bodyStatement = "$($captchaBody)__VIEWSTATE=$__VIEWSTATE&__VIEWSTATEGENERATOR=$__VIEWSTATEGENERATOR&__RequestVerificationToken=$__RequestVerificationToken&__EVENTVALIDATION=$__EVENTVALIDATION&__EVENTTARGET=$__EVENTTARGET&__EVENTARGUMENT=$__EVENTARGUMENT"
    return $session , $ssoToken , $bodyStatement;
}

function ChangeMailPwd() {
    Write-Host -NoNewline '.'
}

function changeADPwd() {
    $newPwd = $global:historyPwd[-1];
    $oldPwd = $global:historyPwd[-2];
    Set-ADAccountPassword -Identity $global:adAccount -NewPassword (ConvertTo-SecureString -AsPlainText "$newPwd" -Force) -OldPassword (ConvertTo-SecureString -AsPlainText "$oldPwd" -Force)
    Write-Host -NoNewline '.'
}


[int]$value = $args[0]
main $((4, $value | Measure -Max).Maximum)
