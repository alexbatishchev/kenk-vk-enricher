# kenk-vk-enricher
# v 1.5.1
Add-Type -Path ".\HtmlAgilityPack.dll"

. ./kenk-vk-enricher-functions.ps1
# ToDo:

###########################
# SETTINGS SECTION
###########################
$DOWNLOAD_DELAY_SECONDS = 0.4
$FOTOS_DIV_DESCRIPTION      = "Фотография"
$VIDEOS_DIV_DESCRIPTION     = "Видеозапись"
$FILES_DIV_DESCRIPTION      = "Файл"

$bDO_DOWNLOAD_VIDEO         = $true

###########################
# cookie auth option for yt-dlp as in https://github.com/yt-dlp/yt-dlp manual
# Cookies from browser: Cookies can be automatically extracted from all major web browsers using --cookies-from-browser BROWSER[+KEYRING][:PROFILE][::CONTAINER]
$sYTDLPAuthString           = " --cookies-from-browser chrome "


##########
$sArchivePath               = "$PSScriptRoot\Archive"
$sFixedArchivePath          = "$PSScriptRoot\Fixed"
$sFixedFotosIMGFolderName   = "photos-dl"
$sFixedVideoFolderName      = "videos-dl"
$sTempVideoFolderName       = "videos-dl-temp"
$sFixedFilesFolderName      = "files-dl"
##########


$sWallPath                  = "$sArchivePath\wall"
$sFixedWallPath             = "$sFixedArchivePath\wall"
$sMessagesPath              = "$sArchivePath\messages"
$sFixedMessagesPath         = "$sFixedArchivePath\messages"
$sAlbumsPath                = "$sArchivePath\photos\photo-albums"
$sFixedFotosHTMLFilePath    = "$sFixedArchivePath\photos\photo-albums"
$sFixedFotosIMGPath         = "$sFixedArchivePath\$sFixedFotosIMGFolderName"
$sYTDLPExecPath             = "$PSScriptRoot\yt-dlp.exe"
$sVideoDestPath             = "$PSScriptRoot\Fixed\$sFixedVideoFolderName"
$sVideoTempPath             = "$PSScriptRoot\Fixed\$sTempVideoFolderName"
$sVideoDestFlagsPath        = "$PSScriptRoot\Fixed\$sFixedVideoFolderName\_flags"
$sFilesDestPath             = "$PSScriptRoot\Fixed\$sFixedFilesFolderName"
#$sFilesDestFlagsPath        = "$PSScriptRoot\Fixed\$sFixedFilesFolderName\_flags"

$sTmpPath                   = "$PSScriptRoot\tmp"
$sScriptDataPath            = "$PSScriptRoot\data"
$sFileDBPath                = "$PSScriptRoot\data\files.json" 

forcepath $sTmpPath 
forcepath $sVideoTempPath
forcepath $sVideoDestPath
forcepath $sScriptDataPath

$sVideoAlbumsPath           = "$sArchivePath\video\video-albums"
$sFixedVideoAlbumsPath      = "$sFixedArchivePath\video\video-albums"


$SSTDOUTPATH = "$sTmpPath\stdout.txt"
$SSTDERRPATH = "$sTmpPath\stderr.txt"

##########

$hRemoteLocalPhotos = @{}
$global:aAllAttachmentDescriptions = @("")

############
wlog ("start of script")

forcepath $sVideoDestPath
forcepath $sVideoDestFlagsPath
forcepath $sFixedFotosIMGPath
forcepath $sTmpPath
forcepath $sFilesDestPath

ProcessPhotoAlbums $sAlbumsPath

$iCount = $hRemoteLocalPhotos.count
wlog ("at this time we got $iCount hashed fotos with original https://vk.com/photoXXXXXXXXX_XXXXXXXXX names")

ProcessMessages $sMessagesPath

ProcessVideoAlbums $sVideoAlbumsPath

processWall $sWallPath

wlog "not processed yet attachment descriptions:"
$global:aAllAttachmentDescriptions | Format-List

wlog ("end of script")
