
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
        'https://ooo.tw/Login/Default.aspx',
        'https://ooo.tw/tstLogin/Default.aspx',
        'http://localhost:2205/Login/Default.aspx'
    )[$type]
    
    $captchaBody = ""
    $sso_resp = Invoke-WebRequest -TimeoutSec $timeoutSec -SessionVariable 'session' -Uri $DefaultPage
    $statecode = get_html_value_byid $sso_resp @('__VIEWSTATE', '__EVENTVALIDATION', 'ImageCaptcha_imgCaptcha', '__RequestVerificationToken') -enable_encoding $false

    try {
        $captcha = $statecode['ImageCaptcha_imgCaptcha'] | Select-String -Pattern '\?hash=(\w+)' -AllMatches | % { $_.matches.groups[1].value } 
        $captcha = decrypt_function $captcha
        write-host -NoNewline "."
    }
    catch {}
    
    #$BtnConfirm = "%E7%A2%BA%2B%2B%E5%AE%9A" 
    $body = @{
        "__EVENTVALIDATION" = $statecode['__EVENTVALIDATION']
        "__VIEWSTATE" = $statecode['__VIEWSTATE']
        "TxtUserAccount" = $account 
        "TxtPWd" = $pwdin 
        "BtnConfirm" = "確++定"
        "__RequestVerificationToken" = $statecode['__RequestVerificationToken']
    }
    if($captcha) {$body.Add("ImageCaptcha%24txtCaptcha",$captcha);}
    
    $sso_resp = Invoke-WebRequest -TimeoutSec $timeoutSec -WebSession $session -Uri $DefaultPage -Method "POST" -Body $(ConvertTo-QueryString $body)
    
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
    $appResp = Invoke-WebRequest -TimeoutSec $timeoutSec -Uri "https://ooo.tw/Login/Main.aspx?v=$ssoToken" -Method "POST" -ContentType "application/x-www-form-urlencoded" -Body "__VIEWSTATE=$__VIEWSTATE_Main_page&__VIEWSTATEGENERATOR=BBBFBD44&__EVENTTARGET=%E7%B3%BB%E7%B5%B1&__EVENTARGUMENT=$PEarg"
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
        'https://ooo.tw/Login/Main.aspx',
        'https://ooo.tw/tstLogin/Main.aspx'
    )[$type]
    
    $lg_resp = Invoke-WebRequest -WebSession $session -TimeoutSec $timeoutSec -Uri "$($mainPage)?v=$($ssoToken)"
    
    $statecode = get_html_value_byid $lg_resp @('__VIEWSTATE', '__VIEWSTATEGENERATOR', '__RequestVerificationToken') -enable_encoding $false
    <#$body = @{
        "__VIEWSTATE" = $statecode['__VIEWSTATE']
        "__VIEWSTATEGENERATOR" = $statecode['__VIEWSTATEGENERATOR']
        "__EVENTTARGET" = "系統"
        "__EVENTARGUMENT" = $AParg
        "__RequestVerificationToken" = $statecode['__RequestVerificationToken']
    }#>
    
    #goto web session & redirect to app
    $goto_app = Invoke-WebRequest -WebSession $session -Uri "$($mainPage)?v=$($ssoToken)" -TimeoutSec $timeoutSec -Method "POST" #-Body $(ConvertTo-QueryString $body)
    
    
    $ssoToken = $goto_app.BaseResponse.ResponseUri.AbsoluteUri | Select-String -Pattern 'v\=(\w+)$' -AllMatches | % { $_.matches.groups[1].value }
    
    if ($null -eq $goto_app) {
        throw 'can''t read response from Web server'
        exit
    }elseif($goto_app.Content.Contains("ListSign")){
       $goto_app = ActApply $goto_app $session
    }elseif ($null -eq $ssoToken) {
        throw 'not read token after login'
        exit
    }
    #$guid = $goto_app.Content | Select-String -Pattern '(.*ctl00_Menu1_1 ctl00_Menu1_3.*)' -AllMatches | % { $_.matches.groups[1].value } | Select-String -Pattern 'g=(.*?)"' -AllMatches | % { $_.matches.groups[1].value }
    $ASP_SessionID = get_asp_session $goto_app
    $ASP_SessionID , $__VIEWSTATE , $__VIEWSTATEGENERATOR , $__EVENTVALIDATION , $session_land_ap = ap_index_landing $AParg $ASP_SessionID $ssoToken $session $enable_encoding $goto_app
    Write-Host -NoNewline '.'
    return $ASP_SessionID , $__VIEWSTATE , $__VIEWSTATEGENERATOR , $__EVENTVALIDATION , $ssoToken , $session_land_ap
}

function ActApply($goto_app,$session){
    $body = @{}
    $Matches = [regex]::matches($goto_app.Content,"_CheckBox1").count
    for($i=1;$i -le $Matches;$i++){ 
        $body += @{"ctl00$ctl00$MainContent$RightColumn$grdSignList$ctl$("$i".PadLeft(2,'0'))$CheckBox1"="on"}
    }

    $statecode = get_html_value_byid $goto_app @('__VIEWSTATE', '__VIEWSTATEGENERATOR','__EVENTVALIDATION') -enable_encoding $false
    $__VIEWSTATE = $statecode['__VIEWSTATE']
    $__VIEWSTATEGENERATOR = $statecode['__VIEWSTATEGENERATOR']
    $__EVENTVALIDATION = $statecode['__EVENTVALIDATION']

    $body += @{
        "__EVENTTARGET" = ""
        "__EVENTARGUMENT" = ""
        "ctl00_ctl00_TreeView1_ExpandState" = ""
        "ctl00_ctl00_TreeView1_SelectedNode" = ""
        "ctl00_ctl00_TreeView1_PopulateLog" = ""
        "__VIEWSTATE" = $__VIEWSTATE
        "__VIEWSTATEGENERATOR" = $__VIEWSTATEGENERATOR
        "__VIEWSTATEENCRYPTED" = ""
        "__EVENTVALIDATION" = $__EVENTVALIDATION
        "ctl00$ctl00$MainContent$RightColumn$BatchAllow" = "批次核准/同意/確認"

    }

    $applied = Invoke-WebRequest -WebSession $session -Uri "http://ooo/Pub/ListSign.aspx" -TimeoutSec $timeoutSec -Method "POST" -Body $(ConvertTo-QueryString $body)
    Write-Host -NoNewline '.'
    return $applied
}

function ap_index_landing($AParg , $ASP_SessionID , $ssoToken , $session_after_login , $enable_encoding , $respMain) {
    $ap_url = $AParg | Select-String -Pattern '(http.*)$' -AllMatches | ForEach-Object { $_.matches.groups[1].value };
    $statecode = get_html_value_byid $respMain @('__VIEWSTATE', '__VIEWSTATEGENERATOR','__RequestVerificationToken') -enable_encoding $false

    $body = @{
        '__VIEWSTATE' = $statecode['__VIEWSTATE']
        '__VIEWSTATEGENERATOR' = $statecode['__VIEWSTATEGENERATOR']
        '__RequestVerificationToken' = $statecode['__RequestVerificationToken']
        '__EVENTARGUMENT' = $AParg
        '__EVENTTARGET' = '系統'
    }

    $landingtoindex = Invoke-WebRequest -Method "POST" -WebSession $session_after_login -Uri "https://ooo.tw/Login/Main.aspx?v=$($ssoToken)" -Body $(ConvertTo-QueryString $body) -TimeoutSec $timeoutSec -Headers @{"method"="POST"} 

    $ap_index = Invoke-WebRequest -WebSession $session_after_login -TimeoutSec $timeoutSec -Uri "$($ap_url)?v=$($ssoToken)" #-Headers @{"cookie" = "ASP.NET_SessionId=$($ASP_SessionID)" }
    
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

function encrypt_function($plan_txt) {
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($plan_txt)
    $aesManaged = create_aes_obj
    $encryptor = $aesManaged.CreateEncryptor()
    $encrypted_source = $encryptor.TransformFinalBlock($bytes, 0, $bytes.Length);
    $encrypted_str = $encrypted_source | ForEach-Object { $_.tostring('x2') } 
    return $encrypted_str -join ''
}

function decrypt_function($encrypted_x2) {
    $aesManaged = create_aes_obj
    $decryptor = $aesManaged.CreateDecryptor()
    $bytes = [byte[]] -split ($encrypted_x2 -replace '..', '0x$& ')
    $unencryptedData = $decryptor.TransformFinalBlock($bytes, 0, $bytes.Length);
    $answer = [System.Text.Encoding]::UTF8.GetString($unencryptedData)
    return $answer
}

function ConvertTo-QueryString {
    [CmdletBinding()]
    [OutputType([string])]
    param (
        # Value to convert
        [Parameter(Mandatory=$true, Position=0, ValueFromPipeline=$true)]
        [object] $InputObjects
    )

    process {
        foreach ($InputObject in $InputObjects) {
            $QueryString = New-Object System.Text.StringBuilder
            if ($InputObject -is [hashtable] -or $InputObject -is [System.Collections.Specialized.OrderedDictionary] -or $InputObject.GetType().FullName.StartsWith('System.Collections.Generic.Dictionary')) {
                foreach ($Item in $InputObject.GetEnumerator()) {
                    if ($QueryString.Length -gt 0) { [void]$QueryString.Append('&') }
                    [void]$QueryString.AppendFormat('{0}={1}',$Item.Key,[System.Net.WebUtility]::UrlEncode($Item.Value))
                }
            }
            elseif ($InputObject -is [object] -and $InputObject -isnot [ValueType])
            {
                foreach ($Item in ($InputObject | Get-Member -MemberType Property,NoteProperty)) {
                    if ($QueryString.Length -gt 0) { [void]$QueryString.Append('&') }
                    $PropertyName = $Item.Name
                    [void]$QueryString.AppendFormat('{0}={1}',$PropertyName,[System.Net.WebUtility]::UrlEncode($InputObject.$PropertyName))
                }
            }
            else
            {
                ## Non-Terminating Error
                $Exception = New-Object ArgumentException -ArgumentList ('Cannot convert input of type {0} to query string.' -f $InputObject.GetType())
                Write-Error -Exception $Exception -Category ([System.Management.Automation.ErrorCategory]::ParserError) -CategoryActivity $MyInvocation.MyCommand -ErrorId 'ConvertQueryStringFailureTypeNotSupported' -TargetObject $InputObject
                continue
            }

            Write-Output $QueryString.ToString()
        }
    }
}




function Get-AllCookiesFromWebRequestSession
{
   <#
         .SYNOPSIS
         Get all cookies stored in the WebRequestSession variable from any Invoke-RestMethod and/or Invoke-WebRequest request

         .DESCRIPTION
         Get all cookies stored in the WebRequestSession variable from any Invoke-RestMethod and/or Invoke-WebRequest request
         The WebRequestSession stores useful info and it has something that some my know as CookieJar or http.cookiejar.

         .PARAMETER WebRequestSession
         Specifies a variable where Invoke-RestMethod and/or Invoke-WebRequest saves values.
         Must be a valid [Microsoft.PowerShell.Commands.WebRequestSession] object!

         .EXAMPLE
         PS C:\> $null = Invoke-WebRequest -UseBasicParsing -Uri 'http://jhochwald.com' -Method Get -SessionVariable WebSession -ErrorAction SilentlyContinue
         PS C:\> $WebSession | Get-AllCookiesFromWebRequestSession

         Get all cookies stored in the $WebSession variable from the request above.
         This page doesn't use or set any cookies, but the (awesome) CloudFlare service does.

		   .EXAMPLE
         $null = Invoke-RestMethod -UseBasicParsing -Uri 'https://jsonplaceholder.typicode.com/todos/1' -Method Get -SessionVariable RestSession -ErrorAction SilentlyContinue
         $RestSession | Get-AllCookiesFromWebRequestSession

         Get all cookies stored in the $RestSession variable from the request above.
         Please do not abuse the free API service above!

         .NOTES
         I used something I had stolen from Chrissy LeMaire's TechNet Gallery entry a (very) long time ago.
         But I needed something more generic, independent from the URL! This can become handy, to find any cookie from a 3rd party site or another host.

         .LINK
         https://docs.python.org/3/library/http.cookiejar.html

         .LINK
         https://en.wikipedia.org/wiki/HTTP_cookie

         .LINK
         https://gallery.technet.microsoft.com/scriptcenter/Getting-Cookies-using-3c373c7e

         .LINK
         Invoke-RestMethod

         .LINK
         Invoke-WebRequest
   #>

   [CmdletBinding(ConfirmImpact = 'None')]
   param
   (
      [Parameter(Mandatory,
         ValueFromPipeline,
         ValueFromPipelineByPropertyName,
         Position = 0,
         HelpMessage = 'Specifies a variable where Invoke-RestMethod and/or Invoke-WebRequest saves values.')]
      [ValidateNotNull()]
      [Alias('Session', 'InputObject')]
      [Microsoft.PowerShell.Commands.WebRequestSession]
      $WebRequestSession
   )

   begin
   {
      # Do the housekeeping
      $CookieInfoObject = $null
   }

   process
   {
      try
      {
         # I know, this look very crappy, but it just work fine!
         [pscustomobject]$CookieInfoObject = ((($WebRequestSession).Cookies).GetType().InvokeMember('m_domainTable', [Reflection.BindingFlags]::NonPublic -bor [Reflection.BindingFlags]::GetField -bor [Reflection.BindingFlags]::Instance, $null, (($WebRequestSession).Cookies), @()))
      }
      catch
      {
         #region ErrorHandler
         # get error record
         [Management.Automation.ErrorRecord]$e = $_

         # retrieve information about runtime error
         $info = [PSCustomObject]@{
            Exception = $e.Exception.Message
            Reason    = $e.CategoryInfo.Reason
            Target    = $e.CategoryInfo.TargetName
            Script    = $e.InvocationInfo.ScriptName
            Line      = $e.InvocationInfo.ScriptLineNumber
            Column    = $e.InvocationInfo.OffsetInLine
         }

         # output information. Post-process collected info, and log info (optional)
         $info | Out-String | Write-Verbose

         $paramWriteError = @{
            Message      = $e.Exception.Message
            ErrorAction  = 'Stop'
            Exception    = $e.Exception
            TargetObject = $e.CategoryInfo.TargetName
         }
         Write-Error @paramWriteError

         # Only here to catch a global ErrorAction overwrite
         exit 1
         #endregion ErrorHandler
      }
   }

   end
   {
      # Dump the Cookies to the Console
      ((($CookieInfoObject).Values).Values)
   }
}
