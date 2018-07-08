@powershell -NoProfile -ExecutionPolicy Unrestricted "$s=[scriptblock]::create((gc \"%~f0\"|?{$_.readcount -gt 1})-join\"`n\");&$s" %*&goto:eof

# powershell batch file
# vim :set ft=conf

# if you want to debug this file, uncomment next line
#Set-PSDebug -Trace 1

Add-Type -AssemblyName System.Web

function SecureString2PlainString($SecureString){
    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString)
    $PlainString = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($BSTR)
    # delete $BSTR
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
    return $PlainString
}

# entry point
Write-Host "Reverse Proxy Constructor"
Write-Host ""

# check if docker-machine command exists
if (!(gcm docker-machine -ea SilentlyContinue)) {
	Write-Host "docker-machine is not find"
	Write-Host "you must install docker-toolbox before run this script"
	Write-Host "install from here : https://docs.docker.com/toolbox/toolbox_install_windows/"
	exit 1
}

$proxy_host = Read-Host "enter proxy host"
$proxy_port = Read-Host "enter proxy port"
$proxy_user = Read-Host "enter proxy user"
$proxy_pass = SecureString2PlainString(Read-Host "enter proxy pass" -AsSecureString)
$proxy_pass_encoded = [System.Web.HttpUtility]::UrlEncode($proxy_pass)
$http_proxy = "http://${proxy_user}:${proxy_pass_encoded}@${proxy_host}:${proxy_port}/"

# set temporary environment value (need for docker-machine)
set-item env:http_proxy -value $http_proxy
set-item env:https_proxy -value $http_proxy

# check connection via proxy
$proxy = new-object System.Net.WebProxy("http://${proxy_host}:${proxy_port}/")
$Password = ConvertTo-SecureString $proxy_pass -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential $proxy_user, $Password
$proxy.credentials = $cred
$WebClient = new-object System.Net.WebClient
$WebClient.proxy = $proxy
$url = "http://www.google.com"
Try
{
    $content = $WebClient.DownloadString($url)
    Write-Host "connection check via proxy is passed" -ForegroundColor Green
}
catch
{
    Write-Host "connection error" -ForegroundColor Red
    Write-Host "prease check proxy settings and try again" -ForegroundColor Red
    exit 1
}

# create new docker-machine with proxy settings
docker-machine rm default
& docker-machine create -d virtualbox --engine-env http_proxy="${http_proxy}" --engine-env https_proxy="${http_proxy}" default
& docker-machine env --shell powershell | Invoke-Expression
Write-Host "docker-machine successfuly installed" -ForegroundColor Green

set-item env:no_proxy -value (docker-machine ip)

# install reverse proxy with docker
& docker build `
-t k-ishigaki/proxy-proxy `
--build-arg http_proxy="${http_proxy}" `
--build-arg https_proxy="${https_proxy}" `
.

#& docker run `
#-d `
#-p 8080:8080 `
#-e PARENT_PROXY_HOST="${proxy_host}" `
#-e PARENT_PROXY_PORT="${proxy_port}" `
#-e PARENT_PROXY_ID="${proxy_user}" `
#-e PARENT_PROXY_PW="${proxy_pass}" `
#--name proxy-proxy `
#k-ishigaki/proxy-proxy
#tail -f /dev/null


Write-Host "type any key to end this script" -ForegroundColor Green
[Console]::ReadKey($true) > $null
