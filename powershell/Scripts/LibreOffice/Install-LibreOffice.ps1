$ErrorActionPreference = "Continue" # continue if the dependencies fail to install
choco install -y kb2919442 # workaround libreoffice dependency error
choco install -y kb2919355
choco install -y libreoffice-still
