$ErrorActionPreference = "Continue" # continue if the dependencies fail to install
. ../Common/Install-Choco-Package.ps1 kb2919442 # workaround libreoffice dependency error
. ../Common/Install-Choco-Package.ps1 kb2919355
. ../Common/Install-Choco-Package.ps1 libreoffice-still
