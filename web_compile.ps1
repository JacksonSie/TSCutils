$MSBUILD_PATH = "C:\Program Files (x86)\Microsoft Visual Studio\2019\Professional\MSBuild\Current\Bin\"
$PROJECT = $args[0] 
$PUBLISH_DIRECTORY = "E:\test\Publish\" + [System.IO.Path]::GetFileNameWithoutExtension($PROJECT)
if($args[1] -ne $null ){
    $PUBLISH_DIRECTORY = $args[1]
}

Write-Host "output_dir:$PUBLISH_DIRECTORY"

$ext = [System.IO.Path]::GetExtension($PROJECT)
if($ext -ne ".csproj" -and $ext -ne ".sln"){
    Write-Error "plz passing *.csproj or *.sln file" -ErrorAction Stop
}else{
    if(!(Test-Path $PUBLISH_DIRECTORY)){
        New-Item -ItemType directory -Path $PUBLISH_DIRECTORY #msbuild 會自己建立資料夾
    }else{
        Remove-Item -Path $PUBLISH_DIRECTORY -Recurse -Force
    }
}

& "$MSBUILD_PATH\MSBuild.exe" $(
        "$PROJECT"
        "/p:DeployOnBuild=True"
        "/p:DeployDefaultTarget=WebPublish"
        "/p:WebPublishMethod=FileSystem"
        "/p:DeleteExistingFiles=True"
        "-maxCpuCount:3"
        "-target:clean,build"
        "/p:publishUrl=$PUBLISH_DIRECTORY"
        "/p:SkipExtraFilesOnServer=False" #retains front-end file (aspx,rdlc)
        #/p:VisualStudioVersion=10.0 #目前TFS2013所指定的C#版本
    )


#echo $PUBLISH_DIRECTORY $MSBUILD_PATH $PROJECT
 