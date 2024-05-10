$path = [Environment]::GetFolderPath("MyDocuments")
"Hello World" | Out-File -FilePath "$path\file.txt"
