# kenk-vk-enricher
# v 1.4.1
Add-Type -Path ".\HtmlAgilityPack.dll"

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
$sVideoDestFlagsPath        = "$PSScriptRoot\Fixed\$sFixedVideoFolderName\_flags"
$sFilesDestPath             = "$PSScriptRoot\Fixed\$sFixedFilesFolderName"
#$sFilesDestFlagsPath        = "$PSScriptRoot\Fixed\$sFixedFilesFolderName\_flags"

$sTmpPath                   = "$PSScriptRoot\tmp"


$sVideoAlbumsPath           = "$sArchivePath\video\video-albums"
$sFixedVideoAlbumsPath      = "$sFixedArchivePath\video\video-albums"


$SSTDOUTPATH = "$sTmpPath\stdout.txt"
$SSTDERRPATH = "$sTmpPath\stderr.txt"

##########
$sLogFileNameTemplate = "yyyy-MM-dd" #"yyyy-MM-dd-HH-mm-ss"
$sLogFilePathTemplate = "yyyy-MM"

$hRemoteLocalPhotos = @{}
$global:aAllAttachmentDescriptions = @("")

#####################################################
##### preparing logs path ###########
$oTempDate = Get-Date
$sLogSubFolder = ""
if ($sLogFilePathTemplate -ne "") {
    $sLogSubFolder = $oTempDate.ToString($sLogFilePathTemplate) + "\"
}
$sLocalLogPath = $PSScriptRoot + "\logs\" + $sLogSubFolder
if (-not (Test-Path $sLocalLogPath)) {
    new-item -type directory -path $sLocalLogPath -Force
}
$sLocalLogName              = $sLocalLogPath + $oTempDate.ToString($sLogFileNameTemplate) +".txt"
$sVideoDownloadErrorsPath   = $sLocalLogPath + $oTempDate.ToString($sLogFileNameTemplate) +".json"
function Wlog( $sText ) {
    $sOut = "[" + (Get-Date).ToString("yyyy-MM-dd-HH-mm-ss") + "]: " + $sText
    $sOut | Out-File -FilePath $sLocalLogName -Encoding "UTF8" -Append
    write-host $sOut
}
function slog( $sText ) {
    $sOut = "[" + (Get-Date).ToString("yyyy-MM-dd-HH-mm-ss") + "]: " + $sText
    $sOut | Out-File -FilePath $sLocalLogName -Encoding "UTF8" -Append
}


function generateRelativePath($sFullPathTo,$sFromFile) {

    $sFullPathTo = $sFullPathTo.Replace('/','\')
    $sFromFile = $sFromFile.Replace('/','\')

    $aFromFile = $sFromFile.Split('\')
    $iFromSegments = ($sFromFile.ToCharArray() | Where-Object {$_ -eq '\'} | Measure-Object).Count
    $aFullPathTo = $sFullPathTo.Split('\')
    $iToSegments = ($sFullPathTo.ToCharArray() | Where-Object {$_ -eq '\'} | Measure-Object).Count

    $iIndex = 0
    while ($aFromFile[$iIndex] -eq $aFullPathTo[$iIndex]) {
        $iIndex ++
    }

    $iUpCount = $iFromSegments - $iIndex
    $sUPPath = $null
    for ($iIndex2=0 ; $iIndex2 -lt $iUpCount; $iIndex2++) {
        $sUPPath = $sUPPath + "../"
    }
    if ($null -eq $sUPPath) {
        $sUPPath = "."
    }

    $sRelativePath = $sUPPath.TrimEnd("/")

    for ($iIndex3 = $iIndex ; $iIndex3 -le $iToSegments; $iIndex3++) {
        $sRelativePath = $sRelativePath + "/" + $aFullPathTo[$iIndex3]
    }
    return $sRelativePath
}

############
function forcepath ($sThisPath) {
    if (-not (test-path $sThisPath)) {    
        $null = New-item $sThisPath -ItemType Directory -Force
    }
}
############
function DownloadVideoPlease ($sVKVideoURL) {
    slog "===="
    slog "start of DownloadVideoPlease for $sVKVideoURL" 
    
    $sPrefix = $sVKVideoURL.Replace("https://vk.com/", "")

    #checking if file was already downloaded for speedup
    $sFlagsFilePath = "$sVideoDestFlagsPath\$sPrefix"
    if (test-path $sFlagsFilePath) {
        $sAlreadyDownloadedpath = get-content $sFlagsFilePath
        wlog "file from [$sVKVideoURL] already downloaded, reading and returning path [$sAlreadyDownloadedpath] from cache file [$sFlagsFilePath]"

        # pre -1.3.7 flag naming fix
        if ($sAlreadyDownloadedpath.StartsWith("$sVideoDestPath")) {
            $sAlreadyDownloadedpath =  $sAlreadyDownloadedpath.Replace(("$sVideoDestPath\"),"")
            $sAlreadyDownloadedpath | out-file $sFlagsFilePath
        }
        # unknown_video fix
        if ($sAlreadyDownloadedpath.EndsWith(".unknown_video")) {
            $sNewAlreadyDownloadedpath =  $sAlreadyDownloadedpath.Replace(".unknown_video",".mp4")
            Move-Item -Path "$sVideoDestPath\$sAlreadyDownloadedpath" -Destination "$sVideoDestPath\$sNewAlreadyDownloadedpath"
            $sAlreadyDownloadedpath = $sNewAlreadyDownloadedpath
            $sAlreadyDownloadedpath | out-file $sFlagsFilePath
        }
        return $true, $sAlreadyDownloadedpath
    }

    wlog ("trying to predict video file name for [$sVKVideoURL]")
    $sVIDEO_FILE_NAME_TEMPLATE = '"' + $sPrefix +'-%(title)s.%(ext)s" '
    $sCommonArgs = $sVKVideoURL + ' -P "' + $sVideoDestPath + '" -o ' + $sVIDEO_FILE_NAME_TEMPLATE + ' --restrict-filenames ' + $sYTDLPAuthString 
    
    ####
    $sArgs = $sCommonArgs + ' --print filename'
    $oProc = $null
    $oProc = Start-Process -NoNewWindow -FilePath $sYTDLPExecPath -ArgumentList $sArgs -Wait -PassThru -RedirectStandardOutput $SSTDOUTPATH -RedirectStandardError $SSTDERRPATH
    if (0 -ne $oProc.ExitCode) {
        slog ("error " + $oProc.ExitCode + " at Start-Process")
        $sStdErrText = Get-Content -Path $SSTDERRPATH
        #wlog $sStdErrText
        return $false, $sStdErrText
    }
    
    $sFutureVideoFilePath =  Get-Content -Path $SSTDOUTPATH
    slog ("got sFutureVideoFilePath [$sFutureVideoFilePath]")
    
    if (test-path $sFutureVideoFilePath) {
        slog ("file already downloaded, skipping download")
        $sFutureVideoFilePath =  $sFutureVideoFilePath.Replace(("$sVideoDestPath\"),"")
        $sFutureVideoFilePath | out-file $sFlagsFilePath
        return $true, $sFutureVideoFilePath
    }

    wlog ("trying to download video file")
    $sArgs = $sCommonArgs + ' --write-thumbnail'
    $oProc = Start-Process -NoNewWindow -FilePath $sYTDLPExecPath -ArgumentList $sArgs -Wait -PassThru -RedirectStandardError $SSTDERRPATH
    slog ("Start-Process result is [" + $oProc.ExitCode + "]")
    if (0 -ne $oProc.ExitCode) {
        slog ("error " + $oProc.ExitCode + " at Start-Process")
        $sStdErrText = Get-Content -Path $SSTDERRPATH
        #wlog $sStdErrText
        return $false, $sStdErrText
    }
    
    # fixing .unknown_video ext f YT-DLP choses it
    if ($sFutureVideoFilePath.EndsWith(".unknown_video")) {
        $sNewFutureVideoFilePath =  $sFutureVideoFilePath.Replace(".unknown_video",".mp4")
        Move-Item -Path $sFutureVideoFilePath -Destination $sNewFutureVideoFilePath
        $sFutureVideoFilePath = $sNewFutureVideoFilePath
        wlog "fixed .unknown_video ext to .mp4 for [$sFutureVideoFilePath]"
    }
   
    # fixing .webm to .mp4 if YT-DLP renames possible name
    if (-not (test-path $sFutureVideoFilePath)) {
        $sFutureVideoFilePath = $sFutureVideoFilePath.Replace(".webm",".mp4")
    }

    if (-not (test-path $sFutureVideoFilePath)) {
        wlog "---- !!!! video file [$sFutureVideoFilePath] reported downloaded from [$sVKVideoURL] but not found, leaving html as is"
        return $false, "video file [$sFutureVideoFilePath] reported downloaded from [$sVKVideoURL] but not found"
    }

    #storing flags file
    $sFutureVideoFilePath =  $sFutureVideoFilePath.Replace(("$sVideoDestPath\"),"")
    $sFutureVideoFilePath | out-file $sFlagsFilePath

    return $true, $sFutureVideoFilePath
}

##########
function DownloadFromDirectURIPlease ($sFromURI, $sToLocalPath, $iDelaySeconds) {
    #wlog "will try to download [$sImgSrcPath] to [$sToLocalPath]"
    if (-not(test-path $sToLocalPath)) {
        wlog "downloading [$sFromURI] to [$sToLocalPath]"
        Invoke-WebRequest -URI $sFromURI -OutFile $sToLocalPath
        Start-Sleep $iDelaySeconds
    }
    else {
        slog "file [$sToLocalPath] already downloaded, skipping"
    }
}

##########
function GetFileNameForUseapiSource ($sImgSourcePath,$sSuffix="") {
    #wlog "parsing sImgSrcPath [$sImgSourcePath]"
    if ($sImgSourcePath.Length -eq 0) {
        wlog "sImgSourcePath [$sImgSourcePath] length 0"
        return $null
    }
    $sNewPath = $sImgSourcePath
    # getting remote file original name
    try {
        $sNewPath = $sNewPath.Substring(0,$sNewPath.LastIndexOf("?")) 
    }
    catch {
    }
    try {
        $sNewPath = $sNewPath.Substring($sNewPath.LastIndexOf("/") + 1)            
    }
    catch {
    }
    # adding hash of source URI for uniqueness
    $sHash = [System.Security.Cryptography.HashAlgorithm]::Create("sha256").ComputeHash([System.Text.Encoding]::UTF8.GetBytes($sImgSourcePath))
    $sPrefix =([System.BitConverter]::ToString($sHash).Replace("-","")).Substring(0,8) 

    if ("" -ne $sSuffix) {
        $sPhotoFileName = "$sPrefix-$sSuffix-$sNewPath"
    } else {
        $sPhotoFileName = "$sPrefix-$sNewPath"
    }
    return $sPhotoFileName
}

function ProcessAttachmentNodeFile($oNode,$sSourceHtmlFilePath) {
    # checking attachmet type via text in 'attachment__description' DIV
    $oAttachmentLink = $null
    $oAttachmentLink = $oNode.SelectSingleNode(".//a[@class='attachment__link']")
    $sObjectHref = $oAttachmentLink.GetAttributeValue("href","nothing")

    
    if ($sObjectHref.StartsWith("https://vk.com/")) {
        wlog ("trying to download attachment file via https://vk.com/ link, possibly result will be junk")
    }
    $sDestFileName = GetFileNameForUseapiSource $sObjectHref
    $sDestFilePath = "$sFilesDestPath\$sDestFileName"
    $bRet = DownloadFromDirectURIPlease $sObjectHref $sDestFilePath $DOWNLOAD_DELAY_SECONDS
    
    # fixing HTML
    $sHTMLFileRelativePath  = generateRelativePath  $sDestFilePath $sSourceHtmlFilePath
    slog ("generated sHTMLFileRelativePath as [$sHTMLFileRelativePath]")


    slog "adding link for file to local path"
    $oNewBR =  $dom.CreateElement("br")
    $null = $oNode.AppendChild($oNewBR)
    
    $oNewA = $dom.CreateElement("A")
    $null = $oNewA.InnerHtml = "Enricher downloaded local file"
    $null = $oNewA.SetAttributeValue("href",$sHTMLFileRelativePath)
    $null = $oNewA.SetAttributeValue("target","_blank")
    $null = $oNode.AppendChild($oNewA)
    $sNewNodeText = $oNode.InnerHtml
    return $sNewNodeText
}
########
function ProcessAttachmentNodeVideo($oNode,$sSourceHtmlFilePath) {
    # checking attachmet type via text in 'attachment__description' DIV
    $oAttachmentLink = $null
    $oAttachmentLink = $oNode.SelectSingleNode(".//a[@class='attachment__link']")
    $sObjectHref = $oAttachmentLink.GetAttributeValue("href","nothing")

    $sDownloadedVideoFilePath = $null
    $bResult, $sDwonloadResultText = DownloadVideoPlease $sObjectHref
    slog ("bResult is [$bResult] and sDwonloadResultText is [$sDwonloadResultText]")
    if ($bResult -eq $false) {
        $oNewP = $dom.CreateElement("p")
        $null = $oNewP.InnerHtml = "YT-DLP download $sDwonloadResultText"
        $null = $oNode.AppendChild($oNewP)
        $sNewNodeText = $oNode.InnerHtml
        wlog "---- !!!! error downloading video, adding comment to html"
        
        $oRep = "" | select date, href, YTDLPResult
        $oRep.Date = (get-date).ToString("yyyy-MM-dd-HH-mm-ss")
        $oRep.href =$sObjectHref 
        $oRep.YTDLPResult = $sDwonloadResultText.ToString()
        $oRep | convertto-json -Compress | out-file $sVideoDownloadErrorsPath -append
        
        #debug
        wlog ($oRep | convertto-json -Compress)
        wlog($sVideoDownloadErrorsPath)
        #debug
        return $sNewNodeText
    }
    
    # video suscessfully downloaded
    # returning to absolute paths
    $sDownloadedVideoFilePath = "$sVideoDestPath\$sDwonloadResultText"
    wlog "video file [$sDownloadedVideoFilePath] sucsessfylly downloaded from [$sObjectHref]"
    
    #thumbnail file path regenerating
    $oVideoFile = Get-Item $sDownloadedVideoFilePath
    $sThumbPath = $oVideoFile.FullName
    $sThumbPath = $sThumbPath.Replace($oVideoFile.Extension,".jpg")
    if (-not (test-path $sThumbPath)) {
        $sThumbPath = $oVideoFile.FullName
        $sThumbPath = $sThumbPath.Replace($oVideoFile.Extension,".webp")
    }
    slog "we re-generated thumbnail path as [$sThumbPath]"
    if (-not (test-path $sThumbPath)) {
        wlog "---- !!!  re-generated thumbnail path as $sThumbPath not found!!"
    }
    # fixing HTML
    $sHTMLVideoRelativePath  = generateRelativePath  $sDownloadedVideoFilePath $sSourceHtmlFilePath
    $sHTMLThumbRelativePath  = generateRelativePath  $sThumbPath $sSourceHtmlFilePath
    slog ("generated sHTMLVideoRelativePath as [$sHTMLVideoRelativePath] and sHTMLThumbRelativePath as [$sHTMLThumbRelativePath]")
    slog "replacing link for video to local path"
    $null = $oAttachmentLink.SetAttributeValue("href",$sHTMLVideoRelativePath)
    $null = $oAttachmentLink.SetAttributeValue("target","_blank")
    #replacing text inside of <a> tag to local image
    $oAttachmentLink.InnerHtml = ""
    $oNewImg = $dom.CreateElement("img")
    $null = $oNewImg.SetAttributeValue("src",$sHTMLThumbRelativePath)
    $null = $oAttachmentLink.AppendChild($oNewImg)
    # adding br before image to break line of attachment description
    $oNewBR =  $dom.CreateElement("br")
    $null = $oNode.InsertBefore($oNewBR, $oAttachmentLink)
    # returning fixed HTML
    $sNewNodeText = $oNode.InnerHtml
    return $sNewNodeText
}

function ProcessAttachmentNodePhoto ($oNode,$sSourceHtmlFilePath) {
    $sOriginalNodeText = $oNode.InnerHtml

    # checking attachmet type via text in 'attachment__description' DIV
    $oAttachmentLink = $null
    $oAttachmentLink = $oNode.SelectSingleNode(".//a[@class='attachment__link']")

    # parsing attachment's foto link
    $sImgSrcPath = $oAttachmentLink.GetAttributeValue("href","nothing")
    # finding original URI of file and downloading it to local copy
    if ($sImgSrcPath.StartsWith("https://vk.com/photo")) {
        #try to find this type of foto from cache and replace
        wlog "# try to find img from cache and replace link for [$sImgSrcPath]"
        if ($hRemoteLocalPhotos.ContainsKey($sImgSrcPath)) {
            $sLocalImgFilePath = $hRemoteLocalPhotos[$sImgSrcPath]

            $sHTMLRelativePath = generateRelativePath $sLocalImgFilePath $sSourceHtmlFilePath
            wlog ("changing [$sImgSrcPath] to [$sHTMLRelativePath] because it is in cache")

            $null = $oAttachmentLink.SetAttributeValue("href",$sHTMLRelativePath)
   
            #replacing text inside of <a> tag to local image
            $oAttachmentLink.InnerHtml = ""
            $oNewImg = $dom.CreateElement("img")
            $null = $oNewImg.SetAttributeValue("src",$sHTMLRelativePath)
            $null = $oAttachmentLink.AppendChild($oNewImg)
            # adding br before image to break line of attachment description
            $oNewBR =  $dom.CreateElement("br")
            $null = $oNode.InsertBefore($oNewBR, $oAttachmentLink)
            
            # returning fixed HTML
            $sNewNodeText = $oNode.InnerHtml
            return $sNewNodeText
        } 
        else {
            wlog ("no cache for [$sImgSrcPath] found, leaving as is")
            return $sOriginalNodeText
        }       
    } else {
        # link is direct, downloading img file
        
        $sNewFileName = $null
        $sNewFileName = GetFileNameForUseapiSource $sImgSrcPath
        if ($null -eq $sNewFileName)
        {
            wlog "ERROR sNewFileName null"
            return $sOriginalNodeText
        }
        
        $sPath = "$sFixedMessagesPath\$sMessageFolderId\imgs"
        forcepath $sPath 
        $sImgDestPath = "$sPath\$sNewFileName"
        DownloadFromDirectURIPlease $sImgSrcPath $sImgDestPath $DOWNLOAD_DELAY_SECONDS

        # creating new HMTL img object and making links to local file
        
        $sHTMLRelativePath = generateRelativePath $sImgDestPath $sSourceHtmlFilePath
        
        $null = $oAttachmentLink.SetAttributeValue("href",$sHTMLRelativePath)
        #replacing text inside of <a> tag to local image
        $oAttachmentLink.InnerHtml = ""
        $oNewImg = $dom.CreateElement("img")
        $null = $oNewImg.SetAttributeValue("src",$sHTMLRelativePath)
        $null = $oAttachmentLink.AppendChild($oNewImg)
        # adding br before image to break line of attachment description
        $oNewBR =  $dom.CreateElement("br")
		$null = $oNode.InsertBefore($oNewBR, $oAttachmentLink)
        # returning fixed HTML
        $sNewNodeText = $oNode.InnerHtml
        return $sNewNodeText
    }

}
##########
function processVideoAlbumNode($oNode,$sSourceHtmlFilePath)  {
    # $oElem.SelectSingleNode(".//div[1]") # link to video via thumbnail
    # $oElem.SelectSingleNode(".//div[2]") # description
    # $oElem.SelectSingleNode(".//div[3]") # stats
    # $oElem.SelectSingleNode(".//div[4]") # text link

    $oAElement      = $oNode.SelectSingleNode(".//div[4]//a[1]")
    $sObjectHref    = $oAElement.GetAttributeValue("href","nothing")

    $bResult, $sDwonloadResultText = DownloadVideoPlease $sObjectHref
    slog ("bResult is [$bResult] and sDwonloadResultText is [$sDwonloadResultText]")
    
    if ($bResult -eq $false) {
        $oDivWithThumb = $oElem.SelectSingleNode(".//div[1]")
        $oNewP = $dom.CreateElement("p")
        $null = $oNewP.InnerHtml = "YT-DLP download $sDwonloadResultText"
        $null = $oDivWithThumb.AppendChild($oNewP)
        $sNewNodeText = $oNode.InnerHtml
        wlog "---- !!!! error downloading video, adding comment to html"

        $oRep = "" | select date, href, YTDLPResult
        $oRep.Date = (get-date).ToString("yyyy-MM-dd-HH-mm-ss")
        $oRep.href =$sObjectHref 
        $oRep.YTDLPResult = $sDwonloadResultText.ToString()
        $oRep | convertto-json -Compress | out-file $sVideoDownloadErrorsPath -append
        #debug
        wlog ($oRep | convertto-json -Compress)
        wlog($sVideoDownloadErrorsPath)
        #debug

        return $sNewNodeText
    }
    
    # video suscessfully downloaded
    # returning to absolute paths
    $sDownloadedVideoFilePath = "$sVideoDestPath\$sDwonloadResultText"
    wlog "video file [$sDownloadedVideoFilePath] sucsessfylly downloaded from [$sObjectHref]"
    
    #thumbnail file path regenerating
    $oVideoFile = Get-Item $sDownloadedVideoFilePath
    $sThumbPath = $oVideoFile.FullName
    $sThumbPath = $sThumbPath.Replace($oVideoFile.Extension,".jpg")
    if (-not (test-path $sThumbPath)) {
        $sThumbPath = $oVideoFile.FullName
        $sThumbPath = $sThumbPath.Replace($oVideoFile.Extension,".webp")
    }
    slog "we re-generated thumbnail path as [$sThumbPath]"
    if (-not (test-path $sThumbPath)) {
        wlog "---- !!!  re-generated thumbnail path as $sThumbPath not found!!"
    }
    
    # fixing HTML
    $sHTMLVideoRelativePath  = generateRelativePath  $sDownloadedVideoFilePath $sSourceHtmlFilePath
    $sHTMLThumbRelativePath  = generateRelativePath  $sThumbPath $sSourceHtmlFilePath
    slog ("generated sHTMLVideoRelativePath as [$sHTMLVideoRelativePath] and sHTMLThumbRelativePath as [$sHTMLThumbRelativePath]")
    slog "replacing link for video to local path"

    $oThumbnailAElement = $oNode.SelectSingleNode(".//div[1]//a[1]")
    $null = $oThumbnailAElement.SetAttributeValue("href",$sHTMLVideoRelativePath)

    $oThumbPictureElement = $oNode.SelectSingleNode(".//div[1]//a[1]//div[1]//div[1]")
    $sStyle="background-image: url($sHTMLThumbRelativePath);"
    $null = $oThumbPictureElement.SetAttributeValue("style","$sStyle")
    $sNewNodeText = $oNode.InnerHtml
    return $sNewNodeText
}
function ProcessAttachmentNode($oNode,$sSourceHtmlFilePath) {
    $sOriginalNodeText = $oNode.InnerHtml

    # checking attachmet type via text in 'attachment__description' DIV
    $oAttachmentDescription = $oNode.SelectSingleNode(".//div[@class='attachment__description']")
    $sAttachmentDescription = $oAttachmentDescription.InnerText.ToString()
    $oAttachmentLink = $null
    $oAttachmentLink = $oElem.SelectSingleNode(".//a[@class='attachment__link']")

    if ($sAttachmentDescription -eq $VIDEOS_DIV_DESCRIPTION) {
        if ($bDO_DOWNLOAD_VIDEO) {
            return ProcessAttachmentNodeVideo $oNode $sSourceHtmlFilePath
        }
        else {
            wlog ("skipping video downloading and HTML changing due to bDO_DOWNLOAD_VIDEO is $bDO_DOWNLOAD_VIDEO")
            return $sOriginalNodeText
        }
    }        
    if ($sAttachmentDescription -eq $FOTOS_DIV_DESCRIPTION) {
        return ProcessAttachmentNodePhoto $oNode $sSourceHtmlFilePath
    }        
    if ($sAttachmentDescription -eq $FILES_DIV_DESCRIPTION) {
        return ProcessAttachmentNodeFile $oNode $sSourceHtmlFilePath
    }        

    if ($null -ne $oAttachmentLink) {
        $sImgSrcPath = $oAttachmentLink.GetAttributeValue("href","nothing")

        $global:aAllAttachmentDescriptions = $global:aAllAttachmentDescriptions + $sAttachmentDescription
        $global:aAllAttachmentDescriptions = $global:aAllAttachmentDescriptions | Sort-Object -unique
        wlog "-- not supported and not empty sAttachmentDescription $sAttachmentDescription with link [$sImgSrcPath]"
    }    
    return $sOriginalNodeText
}
function processWall($sWallPath) {
    wlog "===================================================="
    wlog "processing wall at path [$sWallPath]"
    
    $aWallFiles = Get-ChildItem $sWallPath *.html -File | Sort-Object -property Length  
    # debug 
    # $aWallFiles = $aWallFiles | Where-Object {$_.Name -eq "wall13.html"}
    # debug
    foreach ($oWallFile in $aWallFiles) {
        $sWallFileName = $oWallFile.Name
        wlog "processing wall file for file $sWallFileName"

        $sDestHTMLWallFilePath = "$sFixedWallPath\$sWallFileName"

        $sContent = get-content $oWallFile.FullName -Raw
        $dom = New-Object -TypeName "HtmlAgilityPack.HtmlDocument"
        $dom.LoadHtml($sContent)
        $sFixedPageContent = $sContent

        # getting and parsing all DIVs for wall attachment data

        $aElems = $dom.DocumentNode.SelectNodes("//div[@class='kludges']//div[@class='attachment']")
        
        foreach ($oElem in $aElems) {
            $sOriginalElementText = $oElem.InnerHtml
            $sNewElementText = ProcessAttachmentNode $oElem $sDestHTMLWallFilePath
            if ($sOriginalElementText -ne $sNewElementText) {
                $sFixedPageContent = $sFixedPageContent.Replace($sOriginalElementText, $sNewElementText)
                
                # immediately writing fixed HTML file to disk for fast results
                slog "writing fixed HTML wall content to [$sDestHTMLWallFilePath]"
                $sFixedPageContent | out-file $sDestHTMLWallFilePath -Encoding UTF8            
            }
        }
        # writing fixed HTML file to disk
        slog "writing fixed HTML wall content to [$sDestHTMLWallFilePath]"
        $sFixedPageContent | out-file $sDestHTMLWallFilePath -Encoding UTF8            
    }
}

#####
function ProcessMessages($sAllMessagesPath) {
    wlog "processing messages at path [$sAllMessagesPath]"

    $aMessageFolders = Get-ChildItem $sAllMessagesPath -directory | Sort-Object -property Name
    wlog ("got messages folders: " +  $aMessageFolders.count)
    
    # DEBUG
    # $aMessageFolders = $aMessageFolders | Where-Object{$_.Name -eq "-13776950"}
    # DEBUG
    foreach ($oMessageFolder in $aMessageFolders) {
        $sMessageFolderId = $oMessageFolder.Name
        wlog "processing messages for folder ID $sMessageFolderId"
        $aMessageFolderFiles = Get-ChildItem $oMessageFolder.FullName *.html -File 
        foreach ($oMessageFile in $aMessageFolderFiles) {
            $sMessageFileId = $oMessageFile.Name
            $sMessageFileFullName = $oMessageFile.FullName
            wlog "processing message file [$sMessageFileFullName]"
            $sContent = get-content $oMessageFile.FullName -Raw
            $sFixedPageContent = $sContent 
            
            $sDestMessageFileHTMLPath = "$sFixedMessagesPath\$sMessageFolderId\$sMessageFileId"

            $dom = New-Object -TypeName "HtmlAgilityPack.HtmlDocument"
            $dom.LoadHtml($sContent)
            
            # getting and parsing all DIVs for message attachment data
            $aElems = $dom.DocumentNode.SelectNodes("//div[@class='wrap_page_content']//div[@class='item']//div[@class='item__main']//div[@class='message']//div//div[@class='kludges']//div[@class='attachment']")
            
            foreach ($oElem in $aElems) {
                $sOriginalElementText = $oElem.InnerHtml
                $sNewElementText = ProcessAttachmentNode $oElem $sDestMessageFileHTMLPath
                if ($sOriginalElementText -ne $sNewElementText) {
                    $sFixedPageContent = $sFixedPageContent.Replace($sOriginalElementText, $sNewElementText)
                }
            }

            # writing fixed HTML file to disk
            wlog "writing fixed HTML message content to [$sDestMessageFileHTMLPath]"
            $sFixedPageContent | out-file $sDestMessageFileHTMLPath -Encoding UTF8            
        }
    }
}
##################
function ProcessPhotoAlbums($sPhotoAlbumsPath) {
    wlog "==============================================="
    wlog "now processing photo albums"

    $aAlbums = Get-ChildItem $sPhotoAlbumsPath *.html -File | Sort-Object -property Length 

    # debug
    # $aAlbums = $aAlbums | Select-Object -first 1
    # debug

    foreach ($sAlbumFile in $aAlbums) {
        wlog ("================================")
        wlog ("parsing file " + $sAlbumFile.FullName)
        $sContent = get-content $sAlbumFile.FullName -Raw
        $sFixedContent = $sContent # for later String replace
        
        $dom = New-Object -TypeName "HtmlAgilityPack.HtmlDocument"
        $dom.LoadHtml($sContent)

        $sAlbumFileBaseName = $sAlbumFile.BaseName
        
        # getting album name from HTML code, safe for filesystem 
        $aElems = $dom.DocumentNode.SelectNodes("//div[@class='ui_crumb']")
        $aElems = $aElems | Select-Object -First 1
        $sAlbumName = $aElems.InnerText
        $sAlbumName = $sAlbumName.Split([IO.Path]::GetInvalidFileNameChars()) -join '_'
        wlog "processing album [$sAlbumName]"

        $sAlbumStorePath= "$sFixedFotosIMGPath\$sAlbumName"
        forcepath $sAlbumStorePath

        $sAlbumHTMLFilePath = "$sFixedFotosHTMLFilePath\$sAlbumFileBaseName.html"

        # getting all items (fotos) DIVs in album 
        $aElems = $dom.DocumentNode.SelectNodes("//div[@class='wrap_page_content']//div[@class='item']")
        foreach ($oElem in $aElems) {
            $oImgDiv = $oElem.SelectSingleNode(".//div[1]") #img
            # $oElem.SelectSingleNode(".//div[2]") # comment if exists
            # $oElem.SelectSingleNode(".//div[3]") # vk original url
            # $oElem.SelectSingleNode(".//div[4]") # ??
            # $oElem.SelectSingleNode(".//div[5]") # vk upload date
            
            # finding original URI of file and downloading it to local copy
            $oImgDivImg = $oElem.SelectSingleNode(".//div[1]//img[1]")
            $sImgSrcPath    = $oImgDivImg.GetAttributeValue("src","nothing")
            $sAlt           = $oImgDivImg.GetAttributeValue("alt","nothing")
            
            $sPhotoFileName = GetFileNameForUseapiSource $sImgSrcPath $sAlt
            $sPathForStoringLocalImg = "$sAlbumStorePath\$sPhotoFileName"
            DownloadFromDirectURIPlease $sImgSrcPath $sPathForStoringLocalImg $DOWNLOAD_DELAY_SECONDS

            # generating path to image for HTML links
            $sImgPathForHtml = generateRelativePath $sPathForStoringLocalImg $sAlbumHTMLFilePath
            
            # Replacing links and generating new DIV text
            $sOldDivText = $oImgDiv.InnerHtml
            $sNewDivText = $oImgDiv.InnerHtml

            $oImgDivA = $oElem.SelectSingleNode(".//div[1]//a[1]")
            $sImgDivAPath = $oImgDivA.GetAttributeValue("href","nothing")

            # caching image original VK and local paths
            if (-not($hRemoteLocalPhotos.ContainsKey($sImgDivAPath))) {
                $hRemoteLocalPhotos.Add($sImgDivAPath, $sPathForStoringLocalImg)
            }
            
            #replacing src for img 
            $sNewDivText = $sNewDivText.Replace($sImgSrcPath,$sImgPathForHtml)
            #replacing href for a link
            $sNewDivText = $sNewDivText.Replace($sImgDivAPath,$sImgPathForHtml)
            
            # Replacing old DIV text with new in file
            $sFixedContent = $sFixedContent.Replace($sOldDivText,$sNewDivText)

            # saving comment (if exists) to separate txt file
            $oCommentDiv = $oElem.SelectSingleNode(".//div[2]") #img
            if ($null -ne $oCommentDiv) {
                $sTxt = $oCommentDiv.InnerHtml
                if ("" -ne $sTxt) {
                    $sCommentFilePath = "$sAlbumStorePath\$sPhotoFileName.txt"
                    $sTxt | out-file $sCommentFilePath
                    slog "comment [$sTxt]"
                }
            }
        }
        # writing fixed HTML to disk
        wlog "writing fixed HTML to [$sAlbumHTMLFilePath]"
        $sFixedContent | out-file $sAlbumHTMLFilePath -Encoding UTF8
    }
}

##################
function ProcessVideoAlbums($sPhotoAlbumsPath) {
    wlog "==============================================="
    wlog "now processing video albums"

    $aAlbums = Get-ChildItem $sVideoAlbumsPath *.html -File | Sort-Object -property Length 

    # debug
    # $aAlbums = $aAlbums | Select-Object -first 1
    # debug

    foreach ($sAlbumFile in $aAlbums) {
        wlog ("================================")
        wlog ("parsing file " + $sAlbumFile.FullName)
        $sContent = get-content $sAlbumFile.FullName -Raw
        $sFixedPageContent = $sContent # for later String replace
        
        $dom = New-Object -TypeName "HtmlAgilityPack.HtmlDocument"
        $dom.LoadHtml($sContent)

        $sVideoAlbumFileBaseName = $sAlbumFile.BaseName
        $sDestVideoAlbumHTMLFilePath = "$sFixedVideoAlbumsPath\$sVideoAlbumFileBaseName.html"
        # getting all items DIVs in album 
        $aElems = $dom.DocumentNode.SelectNodes("//div[@class='wrap_page_content']//div[@class='item']")
        foreach ($oElem in $aElems) {
            $sOriginalElementText = $oElem.InnerHtml
            $sNewElementText = ProcessVideoAlbumNode $oElem $sDestVideoAlbumHTMLFilePath
            if ($sOriginalElementText -ne $sNewElementText) {
                $sFixedPageContent = $sFixedPageContent.Replace($sOriginalElementText, $sNewElementText)

                # immideatly writing fixed HTML file to disk
                wlog "writing fixed HTML video album content to [$sDestVideoAlbumHTMLFilePath]"
                $sFixedPageContent | out-file $sDestVideoAlbumHTMLFilePath -Encoding UTF8           
            }
        }        
        # writing fixed HTML file to disk
        wlog "writing fixed HTML video album content to [$sDestVideoAlbumHTMLFilePath]"
        $sFixedPageContent | out-file $sDestVideoAlbumHTMLFilePath -Encoding UTF8           
    }    
}
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
