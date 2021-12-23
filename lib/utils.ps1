
Add-Type -AssemblyName System.Web
. "$PSScriptRoot\settings.ps1"


function accountPwd() {
    $account = if ($Value = (Read-Host "input account (default:$default_account)")) { $Value }else { $default_account }
    $pwdret = if ($default_pwd -ne "") { $default_pwd | ConvertTo-SecureString -AsPlainText -Force }else { Read-Host -Prompt 'input password' -AsSecureString }
    $pwdret = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($pwdret))
    return $account, $pwdret
}

function adAccount() {
    $adAccount = if ($Value = (Read-Host "input AD Account (default:$default_adaccount)")) { $Value }else { $default_adaccount }
    return $adAccount;
}

function ssoLogin($account , $pwdin , $type = 0) {
    $DefaultPage = @(
        'https://oooo1.com.tw/Login/Default.aspx',
        'http://oooo2.com.tw/tstLogin/Default.aspx',
        'http://oooo3.com.tw:2205/Login/Default.aspx'
    )[$type]
    
    $captchaBody = ""
    $sso_resp = Invoke-WebRequest -TimeoutSec $timeoutSec -SessionVariable 'session' -Uri $DefaultPage
    $statecode = get_html_value_byid $sso_resp @('__VIEWSTATE', '__EVENTVALIDATION', 'ImageCaptcha_imgCaptcha', '__RequestVerificationToken')
    $__VIEWSTATE = $statecode['__VIEWSTATE']
    $__EVENTVALIDATION = $statecode['__EVENTVALIDATION']
    $__RequestVerificationToken = $statecode['__RequestVerificationToken']
    try {
        $captcha = $statecode['ImageCaptcha_imgCaptcha'] | Select-String -Pattern '%3Fhash%3D(\w+)' -AllMatches | % { $_.matches.groups[1].value } 
        $captcha = decrypt_function $captcha
        write-host "got captcha $captcha"
        $captchaBody = "ImageCaptcha%24txtCaptcha=$captcha";
    }
    catch {}
    
    $BtnConfirm = "%E7%A2%BA%2B%2B%E5%AE%9A" 
    $account = uri_dataEncoding $account
    $pwdin = uri_dataEncoding $pwdin
    
    $sso_resp = Invoke-WebRequest -TimeoutSec $timeoutSec -WebSession $session -Uri $DefaultPage -Method "POST" -Body "__EVENTVALIDATION=$__EVENTVALIDATION&__VIEWSTATE=$__VIEWSTATE&TxtUserAccount=$account&TxtPWd=$pwdin&BtnConfirm=$BtnConfirm&__RequestVerificationToken=$__RequestVerificationToken&$captchaBody"
    
    $statecode = get_html_value_byid $sso_resp @('__VIEWSTATE')
    $__VIEWSTATE_Main_page = $statecode['__VIEWSTATE']
    $ASP_SessionID = get_asp_session $sso_resp
    $ssoSessionvalue = $sso_resp.RawContent | Select-String -Pattern 'v\=(\w+)"' -AllMatches | ForEach-Object { $_.matches.groups[1].value }
    if ($null -eq $ssoSessionvalue) {
        throw 'can''t read response from SSO server, wrong $ID or $Password?'
        exit
    }
    Write-Host -NoNewline '.'
    return $ssoSessionvalue, $ASP_SessionID, $__VIEWSTATE_Main_page, $session
}


function parseHTMLTable($HTMLsource , $delimiter) {
    $data = $HTMLsource.ParsedHtml.getelementsbytagname('tr')
    [string[]]$table = @()
    forEach ($datum in $data) {
        if ($datum.tagName -like "tr") {
            $thisRow = ""
            $cells = $datum.children
            forEach ($child in $cells) {
                if ($child.tagName -like "td") {
                    $thisRow += $child.innerText + $delimiter
                }
            }
            #$thisRow=$thisRow -replace "`r`n","`t"
            $table += $thisRow.trimend($delimiter) -replace " " , ""
        }
    }
    return $table
}

function get_html_value_byid($HTML_repsonse , [string[]]$id_tags, $enable_encoding = $true) {
    $result = @{}
    foreach ($id_tag in $id_tags) {
        $tmp = ($HTML_repsonse.AllElements | Where-Object { $_.id -eq $id_tag }).value
        if ($null -eq $tmp) { #ImageCaptcha_imgCaptcha
            $tmp = ($HTML_repsonse.AllElements | Where-Object { $_.id -eq $id_tag -and $_.tagname -eq 'IMG' }).src
        }
        if ($null -eq $tmp) {
            $tmp = ($HTML_repsonse.AllElements | Where-Object { $_.name -eq $id_tag }).value
        }        
        $result[$id_tag] = @($tmp, (uri_dataEncoding $tmp))[$enable_encoding]
    }
    return $result
}

function get_asp_session($HTML_response) {
    return $HTML_response.RawContent | Select-String -Pattern 'ASP\.NET_SessionId\=(\w+);' -AllMatches | ForEach-Object { $_.matches.groups[1].value };
}
 
function uri_dataEncoding($string , $letter_uppercase = $true) {
    try {
        $tmp = @($string, [System.Web.HttpUtility]::UrlEncode($string))[$letter_uppercase]
    }
    catch {
        Write-Error "error"
    }
    return $tmp
}

function AppLogin($ssoToken , $__VIEWSTATE_Main_page) {
    $appResp = Invoke-WebRequest -TimeoutSec $timeoutSec -Uri "https://oooo3.com.tw/Login/Main.aspx?v=$ssoToken" -Method "POST" -ContentType "application/x-www-form-urlencoded" -Body "__VIEWSTATE=$__VIEWSTATE_Main_page&__VIEWSTATEGENERATOR=BBBFBD44&__EVENTTARGET=%E7%B3%BB%E7%B5%B1&__EVENTARGUMENT=$PEarg"
    if ($null -eq $appResp) {
        throw 'can''t read response from HR app server'
        exit
    }
    $ASP_SessionID = get_asp_session $appResp
    $ASP_SessionID , $__VIEWSTATE_ap_index , $__VIEWSTATEGENERATOR , $__EVENTVALIDATION = ap_index_landing $PEarg , $ASP_SessionID
    Write-Host -NoNewline '.'

    return $ASP_SessionID , $__VIEWSTATE_ap_index , $__VIEWSTATEGENERATOR , $__EVENTVALIDATION
}

function getDiff($fileNew , $fileOld) {
    $fileOldContent = Get-Content $fileOld
    $fileNewContent = Get-Content $fileNew
    $result = (Compare-Object $fileOldContent $fileNewContent)
    return $result
}

function WebLogin($ssoToken , $AParg , $session , $enable_encoding = $true , $type = 0 ) {
    #get event args
    $mainPage = @(
        'https://oooo3.com.tw/Login/Main.aspx',
        'http://oooo2.com.tw/tstLogin/Main.aspx'
    )[$type]
    
    $lg_resp = Invoke-WebRequest -WebSession $session -TimeoutSec $timeoutSec -Uri "$($mainPage)?v=$($ssoToken)"
    
    $statecode = get_html_value_byid $lg_resp @('__VIEWSTATE', '__VIEWSTATEGENERATOR', '__RequestVerificationToken')
    $__VIEWSTATE = $statecode['__VIEWSTATE']
    $__VIEWSTATEGENERATOR = $statecode['__VIEWSTATEGENERATOR']
    $__RequestVerificationToken = $statecode['__RequestVerificationToken']
    
    $__EVENTTARGET = "%E7%B3%BB%E7%B5%B1"
    $AParg_encoded = uri_dataEncoding $AParg
    
    #goto web session & redirect to app
    $goto_app = Invoke-WebRequest -WebSession $session -Uri "$($mainPage)?v=$($ssoToken)" -TimeoutSec $timeoutSec -Method "POST" -Body "__VIEWSTATE=$__VIEWSTATE&__VIEWSTATEGENERATOR=$__VIEWSTATEGENERATOR&__EVENTTARGET=$__EVENTTARGET&__EVENTARGUMENT=$AParg_encoded&__RequestVerificationToken=$__RequestVerificationToken"
    
    $ssoToken = $goto_app.BaseResponse.ResponseUri.AbsoluteUri | Select-String -Pattern 'v\=(\w+)$' -AllMatches | % { $_.matches.groups[1].value }
    
    if ($null -eq $goto_app) {
        throw 'can''t read response from Web server'
        exit
    }
    elseif ($null -eq $ssoToken) {
        throw 'not read token after login'
        exit
    }
    #$guid = $goto_app.Content | Select-String -Pattern '(.*ctl00_Menu1_1 ctl00_Menu1_3.*)' -AllMatches | % { $_.matches.groups[1].value } | Select-String -Pattern 'g=(.*?)"' -AllMatches | % { $_.matches.groups[1].value }
    $ASP_SessionID = get_asp_session $goto_app
    $ASP_SessionID , $__VIEWSTATE , $__VIEWSTATEGENERATOR , $__EVENTVALIDATION , $session_land_ap = ap_index_landing $AParg $ASP_SessionID $ssoToken $session $enable_encoding
    Write-Host -NoNewline '.'
    return $ASP_SessionID , $__VIEWSTATE , $__VIEWSTATEGENERATOR , $__EVENTVALIDATION , $ssoToken , $session_land_ap
}


function ap_index_landing($AParg , $ASP_SessionID , $ssoToken , $session_after_login , $enable_encoding) {
    $ap_url = $AParg | Select-String -Pattern '(http.*)$' -AllMatches | ForEach-Object { $_.matches.groups[1].value };
    $ap_index = Invoke-WebRequest -WebSession $session_after_login -TimeoutSec $timeoutSec -Uri "$($ap_url)?v=$($ssoToken)" -Headers @{"cookie" = "ASP.NET_SessionId=$($ASP_SessionID)" }
    
    $ASP_SessionID_after_landing = get_asp_session $ap_index
    if ($null -ne $ASP_SessionID_after_landing) { $ASP_SessionID = $ASP_SessionID_after_landing }
    
    $statecode = get_html_value_byid $ap_index @('__VIEWSTATE' , '__VIEWSTATEGENERATOR' , '__EVENTVALIDATION') $enable_encoding
    $__VIEWSTATE = $statecode['__VIEWSTATE']
    $__VIEWSTATEGENERATOR = $statecode['__VIEWSTATEGENERATOR']
    $__EVENTVALIDATION = $statecode['__EVENTVALIDATION']
    
    return $ASP_SessionID , $__VIEWSTATE , $__VIEWSTATEGENERATOR , $__EVENTVALIDATION , $session_after_login
}

function StrToByteArr($str) {
    $enc = [System.Text.Encoding]::UTF8
    $str = $str.Replace(" ", "")
    if (($str.Length % 2) -ne 0) {
        $str += " "
    }
    $returnBytes = @([byte]) * $str.Length
    
    for ($i = 0; $i -lt $str.Length; $i++) {
        $byte_iter = $enc.GetBytes($str[$i])
        write-host $str[$i], $byte_iter
        $returnBytes[$i] = $byte_iter
    }
    return $returnBytes
}

function create_aes_obj() {
    $aes_key = $aes_key_source #setting
    $aesManaged = New-Object "System.Security.Cryptography.AesManaged"
    $aesManaged.Mode = [System.Security.Cryptography.CipherMode]::CBC
    $aesManaged.Padding = [System.Security.Cryptography.PaddingMode]::PKCS7
    $aesManaged.BlockSize = 128
    $aesManaged.KeySize = 256
    $aesManaged.Key = new-object System.Security.Cryptography.SHA256Managed | ForEach-Object { $_.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($aes_key)) }
    $aesManaged.IV = New-Object -TypeName System.Security.Cryptography.MD5CryptoServiceProvider | ForEach-Object { $_.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($aes_key)) }
    return $aesManaged
}


function decrypt_function($encrypted_x2) {
    ##密文解密方法 不公開
    return $answer
}

