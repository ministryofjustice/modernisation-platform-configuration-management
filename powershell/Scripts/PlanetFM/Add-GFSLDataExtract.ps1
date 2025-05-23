$ErrorActionPreference = "Stop"

$SecretId = "/GFSL/planetfm-data-extract"
$SecretValueRaw = aws secretsmanager get-secret-value --secret-id "${SecretId}" --query SecretString --output text
$SecretValue = "$SecretValueRaw" | ConvertFrom-Json

$sourcePath = $SecretValue.SourcePath
$destinationUrl = $SecretValue.DestinationUrl

# Get list of files in source directory
$files = Get-ChildItem -Path $sourcePath

foreach ($file in $files) {
  $filePath = $file.FullName

  # URL-encode the file name if necessary
  $fileName = [System.Net.WebUtility]::UrlEncode($file.Name)
  $uri = "$destinationUrl/$fileName"

  try {
    Invoke-RestMethod -Uri $uri -Method Put -InFile $filePath -ContentType "application/octet-stream"
    Write-Host "Uploaded $fileName successfully."
  }
  catch {
    Write-Error "Failed to upload $fileName. Error: $_"
  }
}
