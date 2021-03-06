param(
	[parameter(Mandatory = $true)]
	[String]$LoadTestPackageSourcePath,
	[parameter(Mandatory = $true)]
	[String]$LoadTestDestinationPath
)

function DownloadLoadTestZip
{
	param(
		[parameter(Mandatory = $true)]
		[String] $SourcePath,
		[parameter(Mandatory = $true)]
		[String] $TargetPath
	)
	
	if(-not(Test-Path $TargetPath))
	{
		New-Item $TargetPath -ItemType directory
	}
	$destFileName = Split-Path $SourcePath -Leaf
	$destFullPath = Join-Path $TargetPath $destFileName
	
	if(-not(Test-Path $destFileName))
	{
		$success = $false
		$retryCount = 0
		while(-not($success))
		{
			try
			{
				$wc = New-Object System.Net.WebClient
    			$wc.DownloadFile($SourcePath, $destFullPath)
				$success = $true
			}
			catch
			{
				$retryCount++
				$success = $false
			}
			if($retryCount -ge 5)
			{
				throw [System.Exception] "Download load test file failed"
			}
		}
		
	}
}

function ExtractZipFile
{
	param(
		[parameter(Mandatory = $true)]
		[String] $SourceZip,
		[parameter(Mandatory = $true)]
		[String] $TargetPath
	)
	if(-not(Test-Path $SourceZip))
	{
		throw [System.IO.FileNotFoundException] "$($SourceZip) not found"
	}
	if(-not(Test-Path $TargetPath))
	{
		New-Item $TargetPath -ItemType directory
		Add-Type -assembly “System.IO.Compression.Filesystem”
		[System.IO.Compression.ZipFile]::ExtractToDirectory($SourceZip,$TargetPath)
	}
	Remove-Item $SourceZip
}
#Import log to file module

$ltArchiveFolderName = "LoadTestPackages"
$ltArchivePath = Join-Path $env:tmp $ltArchiveFolderName

if(-not(Test-Path $ltArchivePath))
{
	New-Item $ltArchivePath -ItemType directory	
}
DownloadLoadTestZip -SourcePath $LoadTestPackageSourcePath -TargetPath $ltArchivePath
$ltZipFileName = Split-Path $LoadTestPackageSourcePath -Leaf
$ltZipLocalPath = Join-Path $ltArchivePath $ltZipFileName
ExtractZipFile -SourceZip $ltZipLocalPath -TargetPath $LoadTestDestinationPath
