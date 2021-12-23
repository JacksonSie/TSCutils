<#
 # ���� : ����̷s�ܧ�L���q��ï�Bemail list
 #>

Add-Type -AssemblyName System.Web
. "$PSScriptRoot\lib\utils.ps1"
. "$PSScriptRoot\lib\settings.ps1" 

<#
 # ����:���� HR APP �����q�H���A�A����s�걵�� email
 # ��J : 
 # ��X : ./lib/settings.ps1 ���w�q�� .csv file
 #>

$global:__EVENTVALIDATION=$null
$global:__VIEWSTATEENCRYPTED=$null
$global:__VIEWSTATEGENERATOR=$null
$global:__VIEWSTATE=$null
$global:session=$null
$global:ASP_SessionID=$null
$global:ssoToken=$null
$global:pass_landing_page=$false

$global:AParg=$PEarg



function emailCrawler($crawler_csv){

    #��o���u�C��t�Ϊ�appSession
	$global:ASP_SessionID , 
    $global:__VIEWSTATE , 
    $global:__VIEWSTATEGENERATOR , 
    $global:__EVENTVALIDATION , 
    $global:ssoToken , 
    $global:session = WebLogin -ssoToken $global:ssoToken `
        -AParg $global:AParg `
        -session $global:session `
        -enable_encoding $false

    if ($global:session -eq $null){
        throw 'can''t read response from HR app server'
        exit
    }

    #�i�J�ӤH�u��c�A���o��d�ɶ�(�ϥ�appSession)

    if (!$deptList){
        Write-Error -ErrorAction Stop -Message "�줣�쳡�����(�� settings.ps1 �w�q, ex.$deptList=@{"01":"XX��"})"
    }

    if (!$crawler_csv){
        Write-Error -ErrorAction Stop -Message "���]�w$crawler_csv"
    }else{
        "����,¾��,��ܦW��,�D�nemail" >> $crawler_csv
    }

    foreach($deptno in $deptList.Keys){
        
        $DeptOrgPerson = retrieve_person -deptno $deptno

        $table = parseHTMLTable $DeptOrgPerson ","

        #�̫�@�ӪŦ�H�e���ȳ����ݭn�A�_�hpass
        $index_list=(0..($table.Count-1))|where {$table[$_] -eq ""}
        if($index_list[-1] -gt 0) {
            $index = $index_list[-1]+1
            $table=$table | Select-Object -Skip $index
        } else {
            Write-Host "`n$($deptList[$deptno]) Pass`n"
            <#
            Write-Error -ErrorAction Stop -Message "
                �줣�� table ���I��� , source:
                ------------
                $table
            "
            #>
            continue
        }
        Write-Host -NoNewline $deptList[$deptno] ' '
        $table = $table -replace ",(\d+)$" , ',a$1' -replace ",([atTZ]\d+)$" , ',$1@oooo.com.tw' 
        $table = $table -replace "^(.*?),(.*?),(.*?)," , '$1_$2_$3,'
        $table >> $crawler_csv
    }
    Write-Host
    Write-Host "out file: $crawler_csv"
}

function cfg_home(){
        $body = @{
        "__EVENTVALIDATION" = $global:__EVENTVALIDATION
        "__VIEWSTATEENCRYPTED" = $global:__VIEWSTATEENCRYPTED
        "__VIEWSTATEGENERATOR" = $global:__VIEWSTATEGENERATOR
        "__VIEWSTATE" = $global:__VIEWSTATE
        "ctl00%24ctl00%24MainContent%24RightColumn%24DropDownList1" = $deptno
        "ctl00%24ctl00%24MainContent%24RightColumn%24DropDownList2" = $divino
        "ctl00%24ctl00%24MainContent%24RightColumn%24DropDownList3" = $branno
        "__EVENTTARGET" = "ctl00%24ctl00%24TreeView1"
        "__EVENTARGUMENT" = "sCFG-01-06"

    }

    $cfg_home = Invoke-WebRequest -Method "POST" `
	    -TimeoutSec $timeoutSec `
	    -WebSession $global:session `
	    -Uri "http://oooo.com.tw/CFG/CfgHome.aspx" `
        -Headers @{"cookie"="ASP.NET_SessionId=$global:ASP_SessionID"}`
	    -Body $body
         
    assign_global $cfg_home

    return $cfg_home
}

function retrieve_person($deptno){
    #�w�]�|landing��ۤv����
    if(-not $global:pass_landing_page){
        $cfg_home = cfg_home
        assign_global $cfg_home

        $DeptOrgPerson = request_person_page -deptno $�ۤv�էO.depno -divino $�ۤv�էO.divino -branno $�ۤv�էO.branno
        assign_global $DeptOrgPerson
        
        $global:pass_landing_page = $true
    }
         $DeptOrgPerson = request_person_page -deptno $deptno
         assign_global $DeptOrgPerson
         return $DeptOrgPerson
}


function request_person_page($deptno = '' , $divino = '' , $branno = ''){
    $body = @{
        "__EVENTVALIDATION" = $global:__EVENTVALIDATION
        "__VIEWSTATEENCRYPTED" = $global:__VIEWSTATEENCRYPTED
        "__VIEWSTATEGENERATOR" = $global:__VIEWSTATEGENERATOR
        "ctl00`$ctl00`$MainContent`$RightColumn`$DropDownList1" = $deptno
        "ctl00`$ctl00`$MainContent`$RightColumn`$DropDownList2" = $divino
        "ctl00`$ctl00`$MainContent`$RightColumn`$DropDownList3" = $branno
    }


    if($divino -eq '' -and $branno -eq ''){
        $body['__VIEWSTATE'] = $global:__VIEWSTATE
    }
        
    $DeptOrgPerson = Invoke-WebRequest -Method "POST" `
	    -TimeoutSec $timeoutSec `
	    -WebSession $global:session `
	    -Uri "http://oooo.com.tw/PUB/DeptOrg_Person.aspx" `
	    -Body $body `
        -Headers @{"cookie"="ASP.NET_SessionId=$global:ASP_SessionID"}

    return $DeptOrgPerson
}


function assign_global($html_resp , $tobe_parsed = @('__VIEWSTATE','__EVENTVALIDATION','__VIEWSTATEENCRYPTED','__VIEWSTATEGENERATOR')) {
    $statecode = get_html_value_byid $html_resp $tobe_parsed $false
    $global:__VIEWSTATE = $statecode['__VIEWSTATE']
    $global:__EVENTVALIDATION = $statecode['__EVENTVALIDATION']
    $global:__VIEWSTATEENCRYPTED = $statecode['__VIEWSTATEENCRYPTED']
    $global:__VIEWSTATEGENERATOR = $statecode['__VIEWSTATEGENERATOR']
}

function diffLast2CSV($crawler_csv){
    $outputFullPath = (Get-ChildItem $crawler_csv).Directory.FullName
    $fileNew , $fileOld = Get-ChildItem $outputFullPath | sort LastWriteTime | select -Last 2
    $fileNew = $outputFullPath + '/' + $fileNew
    $fileOld = $outputFullPath + '/' + $fileOld
    $result = getDiff $fileNew $fileOld
    return $result
}


#��J�b�K�B�n�J ��@�J�f
$account,$pwd = accountPwd
$global:ssoToken , $global:ASP_SessionID , $global:__VIEWSTATE , $global:session = ssoLogin $account $pwd

emailCrawler $crawler_csv

write-host "Diff �s ��"
write-host "<= �s�ɦs�� , => ���ɦs��"
diffLast2CSV $crawler_csv