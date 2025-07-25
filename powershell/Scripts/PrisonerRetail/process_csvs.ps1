# The format of the incoming CSV file should be:
# 0: Location
# 1: NOMS Number
# 2: Surname
# 3: Initials
# 4: Regime
# 5: Balance
# 6: Date - formatted as dd/mm/20yy

$directory = '\\amznfsxhu7je3ss.azure.hmpp.root\PrisonerRetail$\Data'
$timestampDate = Get-Date
$timestamp = $timestampDate.ToString("yyyyMMddHHmmss")
$outputDir = "${directory}\Extracts\Outgoing_Archive"
$outputFile = "${outputDir}\PR${timestamp}.txt"
$archiveDir = "${directory}\Archive"
$finalZip = "${archiveDir}\${timestamp}.7z"
$tempZip = "${archiveDir}\${timestamp}.ziptmp"
$logFile =  "${directory}\process_csvs_log.txt"
$logRetentionDate = $timestampDate.AddMonths(-6)
$retention = $timestampDate.AddMonths(-1).ToString("yyyyMMddHHmmss")
$emailMessageFile = "${directory}\email_message.txt"
$emailSecretId = '/prisoner-retail/notify_emails'
$awsRegion = 'eu-west-2'
$savedEmailsFile = "${directory}\emails.ps1"


$allFiles = Get-ChildItem -Path $directory -File -Recurse | Where-Object {
    $_.DirectoryName -ne (Get-Item $directory).FullName
}
$csvFiles = $allFiles | Where-Object {
    $_.Name.EndsWith(".csv")
}
$processedFiles = $allFiles | Where-Object {
    $_.Name.EndsWith(".processed")
}
$extraFiles = $allFiles | Where-Object {
    -not ($_.Name.EndsWith(".processed") -or 
          $_.Name.EndsWith(".csv") -or 
          $_.Name.EndsWith(".success"))
}
$extraFilesList = "$directory\extra_files.txt"
$failedFilesList = "$directory\failed_files.txt"
$deletedFilesList = "$directory\deleted_files.txt"

$expectedFields = 7

. "${directory}\establishments.ps1"

function Main {
    Write-Log "$PSCommandPath started..."
    Refresh-WorkingDirectory
    
    [array]$outputLines = @()

    foreach ($file in $csvFiles) {
        [string]$filePath = $file.FullName
        [string]$processedFilePath = "$filePath.processed"
        
        [array]$dataLines = Get-DataLines $filePath
        $dataLines = Remove-StartingCommmas $dataLines
        [array]$dataArray = Create-DataArray $dataLines
        $fileIsValid = Check-Early $dataArray $file
        if (-not $fileIsValid) { continue } 
        $dataArray = Clean-Formatting $dataArray
        $fileIsValid = Check-FileIsValid $dataArray $file
        if (-not $fileIsValid) { continue }
        [array]$processedLines = Append-Fields $dataArray $file
        
        $processedLines | Set-Content $processedFilePath

        Append-OutputLines $dataArray $file

        Delete-Files $file
    }
    Archive-OutputFiles
    Delete-OldFiles -directory $archiveDir -extension ".7z"
    Delete-OldFiles -directory $outputDir  -prefix "PR" -extension ".txt"

    Get-Emails
    Send-Email

    Write-Log "$PSCommandPath ran successfully"
}

function Write-Log {
    param (
        [Parameter(Position = 0)][string]$Message
    )
    $logTimestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$logTimestamp - $Message" | Out-File -FilePath $logFile -Append
}

function Delete-Files {
    param (
        [Parameter(Position = 0)]$files
    )
    $noRecordList = @( $extraFilesList, $failedFilesList )
    if ($file -is [string]) { 
        $file = @($file)
    }  
    foreach ($file in $files) {
        if ($file -is [System.IO.FileInfo]) {
            $file = $file.FullName
        }
        if ($file -notin $noRecordList -and $file -notlike "*.processed") {
            $fileName = Split-Path $file -Leaf
            $parentFolder = Split-Path $file -Parent
            $folderName = Split-Path $parentFolder -Leaf
            Add-Content -Path $deletedFilesList -Value "$folderName\$fileName"
        }
        if (Test-Path $file) {
            Remove-Item -Path $file -Force
        }
    }
}

function Refresh-WorkingDirectory {
    "" | Out-File -FilePath $deletedFilesList
    "" | Out-File -FilePath $extraFilesList
    "" | Out-File -FilePath $failedFilesList
    Delete-Files $processedFiles
    Write-ExtraFiles
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    New-Item -ItemType Directory -Path $archiveDir -Force | Out-Null
    # rotate log file
    if (Test-Path $logFile) {
        $logFileMonth = (Get-Item $logFile).CreationTime.Month
        if ($logFileMonth -ne $timestampDate.Month) {
            $previousMonth = $timestampDate.AddMonths(-1)
            $oldLogName = "$($directory)\process_csvs_log_$($previousMonth.Year)_$($previousMonth.Month).txt"
            Rename-Item -Path $logFile -NewName $oldLogName
            New-Item -Path $logFile -ItemType File -Force | Out-Null
        }
    }

    # cleanup old logss
    Get-ChildItem -Path $directory -Filter "process_csvs_log_20*" |
        Where-Object { $_.LastWriteTime -lt $logRetentionDate } |
        ForEach-Object {
            Remove-Item $_.FullName -Force
            Write-Log "Deleted old log: $($_.Name)"
        }
}

function Write-ExtraFiles {
    foreach ($file in $extraFiles) {
        $filePath = $file.FullName
        $parentFolder = Split-Path $filePath -Parent
        $folderName = Split-Path $parentFolder -Leaf
        Add-Content -Path $extraFilesList -Value "$folderName\$($file.Name)"
    }
}

function Get-DataLines {
    param (
        [Parameter(Position = 0)][string]$file
    )
    [array]$inputLines = Get-Content $file
    [array]$dataLines = @()
    foreach ($line in $inputLines) {
        # We're only interested in lines that have data in them
        # We insist that they must have "/20" in them (part of date)
        if ($line -ne "" -and $line -match "/20") {
            $dataLines += $line
        }
    }
    return $dataLines
}

# Some files have an extra comma at the start of a line
function Remove-StartingCommmas {
    param (
        [Parameter(Position = 0)][array]$lines
    )
    [array]$cleanLines = @()
    foreach ($line in $lines) {
        if ($line.StartsWith(",")) {
            $line = $line.Substring(1)
        }
        $cleanLines += $line      
    }
    return $cleanLines
}

function Create-DataArray {
    param (
        [Parameter(Position = 0)][array]$lines
    )
    [array]$lineArray = @()
    [array]$dataArray = @()
    foreach ($line in $lines) {
        # if line contains quotes
        if ($line -match '"') {
            # Replace commas within quotes with a special marker
            $withinQuotes = $false
            $newline = ""
            
            for ($i = 0; $i -lt $line.Length; $i++) {
                $char = $line[$i]
                
                if ($char -eq '"') {
                    $withinQuotes = -not $withinQuotes
                    $newline += $char
                } elseif ($char -eq ',' -and $withinQuotes) {
                    $newline += "¬~¬"
                } else {
                    $newline += $char
                }
            }
            $line = $newline
        }
        $lineArray = $line -split ','
        $dataArray += ,$lineArray
        
    }
    ,$dataArray
}

function Check-Early {
    param (
        [Parameter(Position = 0)][array]$dataArray,
        [Parameter(Position = 1)]$file
    )
    [String]$establishmentShort = $file.Directory.Name
    [String]$establishmentLong = $establishments[$establishmentShort]

    # check we have the establishment name
    if ($establishments[$establishmentShort] -eq $null) {
        Write-Log "We do not have $establishmentShort in our list of establishments. '${establishmentShort}\${file}' will be skipped."
        Add-Content -Path $failedFilesList -Value $file.FullName
        return $false
    }
    # check number of fields
    
    foreach ($row in $dataArray) {
        if ($row.Count -ne $expectedFields) {
            Write-Log "Invalid row in file '$($file.FullName)': Expected $expectedFields fields but found $($row.Count). This file will be skipped."
            Add-Content -Path $failedFilesList -Value $file.FullName
            exit
            return $false
        }
    }
    return $true
}

function Clean-Formatting {
    param (
        [Parameter(Position = 0)][array]$dataArray
    )
    foreach ($row in $dataArray) {
        for ($i = 0; $i -lt 7; $i++) {
            # Remove quotes at the start and end
            # Replace comma placeholder with comma
            if ($row[$i].StartsWith('"')) {
                $row[$i] = $row[$i].Substring(1)
            }
            if ($row[$i].EndsWith('"')) {
                $row[$i] = $row[$i].Substring(0, $row[$i].Length - 1)
            }
            $row[$i] = $row[$i] -replace "¬~¬", ","
        }
        # Just have numbers and . in Balance
        $row[5] = $row[5] -replace "[£,]", ""
        if ($row[5] -eq "-") {
            $row[5] = "0"
        }
        # Remove non-numeric first character (like £)
        if (-not [char]::IsDigit($row[5][0])) {
            $row[5] = $row[5].Substring(1)
        }
    }
    ,$dataArray
}

function Check-FileIsValid {
    param (
        [Parameter(Position = 0)][array]$dataArray,
        [Parameter(Position = 1)]$file
    )
    foreach ($row in $dataArray) {    
        # Check if we have valid balance
        if (-not ($row[5] -match "^\d+(\.\d{1,2})?$")) {
            Write-Log "Invalid balance in file '$($file.FullName)': Expected only numbers and decimals but found '$($row[5])'. This file will be skipped."
            Add-Content -Path $failedFilesList -Value $file.FullName
            return $false
        }
        # Check if we have valid date
        $dateFormat = 'dd/MM/yyyy'
        $dateFormats = @(
          'dd/MM/yyyy',  # expected format
          'd/M/yyyy',    # Optional flexibility
          'dd/M/yyyy',
          'd/MM/yyyy'
        )
        [DateTime]$parsedDate = [DateTime]::MinValue
        if (-not ([DateTime]::TryParseExact($row[6], $dateFormat, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref]$parsedDate))) {
            if ([DateTime]::TryParseExact($row[6], $dateFormats, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref]$parsedDate)) {
                Write-Log "Correcting date format in file '$($file.FullName)': Expected date format dd/MM/yyyy but found '$($row[6])'."
                $row[6] = $row[6].ToString('dd/MM/yy')
            } else {
                Write-Log "Invalid date in file '$($file.FullName)': Expected date format dd/mm/yyyy but found '$($row[6])'. This file will be skipped."
                Add-Content -Path $failedFilesList -Value $file.FullName
                return $false
            }
        }
        
        if (-not ($parsedDate.Year -ge 2000 -and $parsedDate.Month -ge 1 -and $parsedDate.Month -le 12 -and $parsedDate.Day -ge 1 -and $parsedDate.Day -le 31)) {
            Write-Log "Invalid date in file '$($file.FullName)': Expected date format dd/mm/yyyy with dd=[0-31], mm=[0-12], yyyy=[2000+], found '$($row[6])'. This file will be skipped."
            Add-Content -Path $failedFilesList -Value $file.FullName
            return $false
        }
    }
    return $true
}

function Append-Fields {
    param (
        [Parameter(Position = 0)][array]$dataArray,
        [Parameter(Position = 1)]$file
    )
    $fileTime = $file.LastWriteTime
    [string]$establishment = $file.Directory.Name
    [array]$outputArray = @()
    foreach ($row in $dataArray) {
        # Join fields and add timestamp and establishment
        [string]$line = $row -join ","
        $line = $line + "," + $fileTime.Hour + "," + $fileTime.Minute + "," + $fileTime.Second + ",," + $establishment
        $outputArray += $line
    }

    ,$outputArray
}

function Append-OutputLines {
    param (
        [Parameter(Position = 0)][array]$dataArray,
        [Parameter(Position = 1)]$file
    )
    [String]$establishmentShort = $file.Directory.Name
    [String]$establishmentLong = $establishments[$establishmentShort]

    foreach ($row in $dataArray) {    
        $location   = $row[0]
        $nomsNumber = $row[1].ToUpper()
        $surname    = $row[2].ToUpper()
        $initials   = $row[3].ToUpper()
        $regime     = $row[4]
        $balance    = $row[5]
        $date       = $row[6] 

        [String]$line = "$surname $initials,$nomsNumber,$establishmentShort,$establishmentLong,$location,$balance"
        Add-Content -Path $outputFile -Value $line
    }
}

function Archive-OutputFiles {
    #\\amznfsxhu7je3ss.azure.hmpp.root\PrisonerRetail$\7-Zip\7z a -mx7 -tzip $tempZip $outputFile > $null
    #Rename-Item -Path $tempZip -NewName "$timestamp.7z"
    if (Test-Path $outputFile) {
        Compress-Archive -Path $outputFile -DestinationPath "$archiveDir\$($timestampDate.Day)\.zip" -Update
    }
}

# assumes dates are 14 chars 
function Delete-OldFiles {
    param (
        [string]$directory,
        [string]$prefix = "",
        [string]$extension = ""
    )
    Get-ChildItem -Path $directory -File | Where-Object { $_.Name -match "$prefix^\d{14}\$extension$" } | ForEach-Object {
        $filename = $_.BaseName
        if ($filename.Substring($prefix.length) -lt $retention) {
            Write-Log "Deleting $($_.FullName)"
            Delete-Files $_.FullName
        }
    }
}

function Get-Emails {
    try {
        $secretText = aws secretsmanager get-secret-value `
            --secret-id $emailSecretId `
            --region $awsRegion `
            --query 'SecretString' `
            --output text

        if ($secretText -match "\.gov\.uk") {
            $emailVars = $secretText | ConvertFrom-Json
            $emailFrom = $emailVars.from 
            $emailTo = $emailVars.to 
            "`$from = '$emailFrom'
`$to = '$emailTo'" | Out-File -FilePath $savedEmailsFile -Encoding UTF8 -Force
        }
        else {
            Write-Log "Email secret does not contain 'gov.uk'. Output was not saved."
        }
    }
    catch {
        Write-Log "Exception occurred while retrieving the email secret: $_"
    }
}

function Send-Email {
    . $savedEmailsFile
    "Hi All

This is what's been removed from Prison Retail's Folders on this run
If no lines are below, nothing has been deleted
" | Out-File $emailMessageFile
    Get-Content -Path $deletedFilesList  | Add-Content -Path $emailMessageFile
    "
Glenn Bot
" | Add-Content -Path $emailMessageFile
    
    # Send-MailMessage -from '$from' -to $to -subject ‘Prison Retail Removed Files Last Run’ -Body Get-Content -Path $emailMessageFile -SmtpServer ‘smtp.hmpps-domain.service.justice.gov.uk’

}

try {
    Main
} catch {
    Write-Log "An error occurred: $_"
    exit 1
}