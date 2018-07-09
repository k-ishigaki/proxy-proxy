@powershell -NoProfile -ExecutionPolicy Unrestricted "$s=[scriptblock]::create((gc \"%~f0\"|?{$_.readcount -gt 1})-join\"`n\");&$s" %*&goto:eof

# powershell batch file
# vim :set ft=conf

# if you want to debug this file, uncomment next line
Set-PSDebug -Trace 1

Add-Type -AssemblyName System.Web

function SecureString2PlainString($SecureString){
    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString)
    $PlainString = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($BSTR)
    # delete $BSTR
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
    return $PlainString
}

function String2Base64String($SourceString){
	$byte = [System.Text.Encoding]::UTF8.GetBytes($SourceString)
	$b64enc = [System.Convert]::ToBase64String($byte)
	return $b64enc
}

# entry point
Write-Host "Proxy for Proxy with Basic Authorization"
Write-Host ""

# check if docker-machine command exists
if (!(gcm docker-machine -ea SilentlyContinue)) {
	Write-Host "docker-machine is not find" -ForegroundColor Red
	Write-Host "you must install docker-toolbox before run this script" -ForegroundColor Red
	Write-Host "install from here : https://docs.docker.com/toolbox/toolbox_install_windows/" -ForegroundColor Red
	exit 1
}

# user proxy config prompts
$proxy_host = Read-Host "enter proxy host"
$proxy_port = Read-Host "enter proxy port"
$proxy_user = Read-Host "enter proxy user"
$proxy_pass = SecureString2PlainString(Read-Host "enter proxy pass" -AsSecureString)
$proxy_pass_encoded = [System.Web.HttpUtility]::UrlEncode($proxy_pass)
$proxy_auth_base64_encoded = String2Base64String("${proxy_user}:${proxy_pass}")
$http_proxy = "http://${proxy_user}:${proxy_pass_encoded}@${proxy_host}:${proxy_port}/"

$proxy_auth_base64_encoded

# set proxy environment value for docker-machine
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
docker-machine create -d virtualbox --engine-env http_proxy="${http_proxy}" --engine-env https_proxy="${http_proxy}" default
set-item env:no_proxy -value (docker-machine ip)
& docker-machine env --shell powershell | Invoke-Expression
Write-Host "docker-machine successfuly installed" -ForegroundColor Green


# install reverse proxy with docker
docker build `
-t k-ishigaki/proxy-proxy `
--build-arg proxy_host="${proxy_host}" `
--build-arg proxy_port="${proxy_port}" `
--build-arg proxy_auth_base64_encoded="${proxy_auth_base64_encoded}" `
--build-arg proxy_user="${proxy_user}" `
--build-arg proxy_pass_encoded="${proxy_pass_encoded}" `
.

docker run `
-d `
-p 8080:8080 `
-e proxy_host="${proxy_host}" `
-e proxy_port="${proxy_port}" `
-e proxy_auth_base64_encoded="${proxy_auth_base64_encoded}" `
-e proxy_user="${proxy_user}" `
-e proxy_pass_encoded="${proxy_pass_encoded}" `
--name proxy-proxy `
k-ishigaki/proxy-proxy

Write-Host "type any key to end this script" -ForegroundColor Green
[Console]::ReadKey($true) > $null
