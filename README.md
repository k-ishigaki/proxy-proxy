# proxy-proxy
Proxy for Proxy with Basic Authorization

## Requwirements
- Windows 7 or higher
- Dokcker Toolbox (https://docs.docker.com/toolbox/toolbox_install_windows/)

## Usage
1. Install Docker Toolbox
2. Download this repository
3. Double click `run.bat` on explorer 
4. Enter your proxy settings and type `y<Enter>`  
  `enter proxy host: 123.456.789.012`  
  `enter proxy port: 8888`  
  `enter proxy user: k-ishigaki`  
  `enter proxy pass: **********`  
  `WARNING: This action will delete both local reference and remote instance.`  
  `Are you sure? (y/n): y`
5. Run `docker-machine ip` and set proxy to `<docker-machine ip>:<port>`
6. Enjoy!
