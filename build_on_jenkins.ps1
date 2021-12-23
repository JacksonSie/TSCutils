
$user = 'oooooo'
$pass = 'oooooooooooooooooooooooooooooooooo'
$ZZ1JobToken = 'ZZProjectbuildFromScript'
$ZZ2JobToken = 'ZZProjectbuildFromScript'
$ZZ3JobToken = 'ZZProjectbuildFromScript'
$ZZWebJobToken = 'ZZWebProjectbuildFromScript'
$jenkins_host = 'http://jenkins.oooooo.com.tw:8090'

$pair = "$($user):$($pass)"
$encodedCreds = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($pair))
$basicAuthValue = "Basic $encodedCreds"
$Headers = @{
    Authorization = $basicAuthValue
}

$json = Invoke-WebRequest -Uri "$jenkins_host/crumbIssuer/api/json" -Headers $Headers
$parsedJson = $json | ConvertFrom-Json


$BuildHeaders = @{
    "Jenkins-Crumb" = $parsedJson.crumb
    Authorization = $basicAuthValue
}

Invoke-WebRequest -Uri "$jenkins_host/job/ZZ/build?token=$ZZ1JobToken" -Headers $BuildHeaders -Method Post
Invoke-WebRequest -Uri "$jenkins_host/job/ZZ/build?token=$ZZ2JobToken" -Headers $BuildHeaders -Method Post
Invoke-WebRequest -Uri "$jenkins_host/job/ZZWeb/build?token=$ZZ3JobToken" -Headers $BuildHeaders -Method Post


