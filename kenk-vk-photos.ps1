# v 1.1
Add-Type -Path "./HtmlAgilityPack.dll"

$sArchivePath = "./Archive"
$sFixedArchivePath = "./Fixed"
$sFixedFotosIMGFolderName = "photos-src"
$FOTOS_DIV_DESCRIPTION = "Фотография"
$DOWNLOAD_DELAY_SECONDS = 0.4
##########

$sAlbumsPath = "$sArchivePath/photos/photo-albums"
$sFixedFotosHTMLFilePath = "$sFixedArchivePath/photos/photo-albums"
$sFixedFotosIMGPath = "$sFixedArchivePath/$sFixedFotosIMGFolderName/"
$sMessagesPath = "$sArchivePath/messages"
$sFixedMessagesPath = "$sFixedArchivePath/messages"

$sLogFileNameTemplate = "yyyy-MM-dd" #"yyyy-MM-dd-HH-mm-ss"
$sLogFilePathTemplate = "yyyy-MM"

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
$sLocalLogName = $sLocalLogPath + $oTempDate.ToString($sLogFileNameTemplate) +".txt"
function Wlog( $sText ) {
    $sOut = "[" + (Get-Date).ToString("yyyy-MM-dd-HH-mm-ss") + "]: " + $sText
    $sOut | Out-File -FilePath $sLocalLogName -Encoding "UTF8" -Append
    write-host $sOut
}
############
function force-path ($sThisPath) {
    if (-not (test-path $sThisPath)) {    
        $bRet = New-item $sThisPath -ItemType Directory -Force
    }
}

##########
function DownloadFilePlease ($sFromURI, $sToLocalPath, $iDelaySeconds) {
    #wlog "will try to download [$sImgSrcPath] to [$sToLocalPath]"
    if (-not(test-path $sToLocalPath)) {
        wlog "downloading [$sFromURI] to [$sToLocalPath]"
        Invoke-WebRequest -URI $sFromURI -OutFile $sToLocalPath
        Start-Sleep $iDelaySeconds
    }
    else {
        wlog "file [$sToLocalPath] already downloaded, skipping"
    }

}
##########
function GetImgFileNameForUseapiSource ($sImgSourcePath,$sSuffix="") {
    wlog "parsing sImgSrcPath [$sImgSourcePath]"
    if ($sImgSourcePath.Length -eq 0) {
        wlog "sImgSourcePath length 0"
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
##########
function ProcessMessages($sAllMessagesPath) {
    wlog "processing messages at path [$sMessagesPath]"
    $aAllAttachmentDescriptionTypes = @()
    $aAllAttachmentDescriptionTypes = $aAllAttachmentDescriptionTypes + ''

    $aMessageFolders = gci $sAllMessagesPath -directory | sort -property Name
    foreach ($oMessageFolder in $aMessageFolders) {
        $sMessageFolderId = $oMessageFolder.Name
        wlog "processing messages for folder ID $sMessageFolderId"
        $aMessageFolderFiles = gci $oMessageFolder.FullName *.html -File 
        foreach ($oMessageFile in $aMessageFolderFiles) {
            $sMessageFileId = $oMessageFile.Name
            wlog "processing file for file ID $sMessageFileId"
            $sContent = get-content $oMessageFile.FullName
            $sFixedContent = $sContent # for later String replace
            
            $dom = New-Object -TypeName "HtmlAgilityPack.HtmlDocument"
            $dom.LoadHtml($sContent)
            
            # getting and parsing all DIVs for message attachment data
            $aElems = $dom.DocumentNode.SelectNodes("//div[@class='wrap_page_content']//div[@class='item']//div[@class='item__main']//div[@class='message']//div//div[@class='kludges']//div[@class='attachment']")
            
            foreach ($oElem in $aElems) {
                $oAttachmentDescription = $oElem.SelectNodes(".//div[@class='attachment__description']")
                $sAttachmentDescription = $oAttachmentDescription.InnerText.ToString()
                $aAllAttachmentDescriptionTypes += $sAttachmentDescription 
                $aAllAttachmentDescriptionTypes = $aAllAttachmentDescriptionTypes| Sort-Object -unique

                if ($sAttachmentDescription -ne $FOTOS_DIV_DESCRIPTION) {
                    #wlog "---------------------- $sAttachmentDescription"
                    continue
                }
                $aAttachmentLinks = $oElem.SelectNodes(".//a")
                foreach ($oAttachmentLink in $aAttachmentLinks) {
                    $sOriginalText = $oAttachmentLink.OuterHtml

                    # finding original URI of file and downloading it to local copy
                    $sImgSrcPath = $oAttachmentLink.GetAttributeValue("href","nothing")
                    $sNewFileName = $null
                    $sNewFileName = GetImgFileNameForUseapiSource $sImgSrcPath
                    if ($null -eq $sNewFileName)
                    {
                        wlog "ERROR sNewFileName null"
                        return
                    }
                    
                    $sPath = "$sFixedMessagesPath/$sMessageFolderId/imgs"
                    force-path $sPath 
                    $sPath = "$sPath/$sNewFileName"
                    DownloadFilePlease $sImgSrcPath $sPath $DOWNLOAD_DELAY_SECONDS

                    # creating new HMTL img object and making links to local file
                    $sHTMLRelativePath = "./imgs/$sNewFileName"
                    $bRet = $oAttachmentLink.SetAttributeValue("href",$sHTMLRelativePath)

                    $oAttachmentLink.InnerHtml = ""
                    $oNewImg = $dom.CreateElement("img")
                    $bRet = $oNewImg.SetAttributeValue("src",$sHTMLRelativePath)
                    $bRet = $oAttachmentLink.AppendChild($oNewImg)

                    # fixing HTML
                    $sNewText = $oAttachmentLink.OuterHtml
                    $sNewText = "<br>" + $sNewText
                    $sFixedContent = $sFixedContent.Replace($sOriginalText,$sNewText)
                }
            }
            # writing fixed HTML file to disk
            $sPath = "$sFixedMessagesPath/$sMessageFolderId/$sMessageFileId"
            $sFixedContent | out-file $sPath -Encoding UTF8            
        }
    }
    wlog "unprocessed types of attachments in messages:"
    $aAllAttachmentDescriptionTypes | ? {$_ -ne ''}| fl
}
function ProcessPhotoAlbums($sPhotoAlbumsPath) {
    wlog "==============================================="
    wlog "now processing photo albums"

    $aAlbums = gci $sPhotoAlbumsPath *.html -File | sort -property Length 
    #$aAlbums | ft

    foreach ($sAlbumFile in $aAlbums) {
        wlog ("================================")
        wlog ("parsing file" + $sAlbumFile.FullName)
        $sContent = get-content $sAlbumFile.FullName
        $sFixedContent = $sContent # for later String replace
        
        $dom = New-Object -TypeName "HtmlAgilityPack.HtmlDocument"
        $dom.LoadHtml($sContent)

        $sAlbumFileBaseName = $sAlbumFile.BaseName
        
        # getting album name from HTML code, safe for filesystem 
        $aElems = $dom.DocumentNode.SelectNodes("//div[@class='ui_crumb']")
        $aElems = $aElems | select -First 1
        $sAlbumName = $aElems.InnerText
        $sAlbumName = $sAlbumName.Split([IO.Path]::GetInvalidFileNameChars()) -join '_'
        
        wlog "processing album [$sAlbumName]"

        $sAlbumStorePath= "$sFixedFotosIMGPath/$sAlbumName"
        force-path $sAlbumStorePath

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
            
            $sPhotoFileName = GetImgFileNameForUseapiSource $sImgSrcPath $sAlt
            $sPath = "$sAlbumStorePath/$sPhotoFileName"
            DownloadFilePlease $sImgSrcPath $sPath $DOWNLOAD_DELAY_SECONDS

            # generating path to image for HTML links
            $sImgPathForHtml = "../../$sFixedFotosIMGFolderName/$sAlbumName/$sPhotoFileName"

            # Replacing links and generating new DIV text
            $sOldDivText = $oImgDiv.InnerHtml
            $sNewDivText = $oImgDiv.InnerHtml

            $oImgDivA = $oElem.SelectSingleNode(".//div[1]//a[1]")
            $sImgDivAPath = $oImgDivA.GetAttributeValue("href","nothing")
            
            $sNewDivText = $sNewDivText.Replace($sImgSrcPath,$sImgPathForHtml)
            $sNewDivText = $sNewDivText.Replace($sImgDivAPath,$sImgPathForHtml)
            
            # Replacing old DIV text with new in file
            $sFixedContent = $sFixedContent.Replace($sOldDivText,$sNewDivText)

            # saving comment (if exists) to separate txt file
            $oCommentDiv = $oElem.SelectSingleNode(".//div[2]") #img
            if ($oCommentDiv -ne $null) {
                $sTxt = $oCommentDiv.InnerHtml
                if ("" -ne $sTxt) {
                    $sCommentFilePath = "$sAlbumStorePath/$sPhotoFileName.txt"
                    $sTxt | out-file $sCommentFilePath
                    wlog "comment [$sTxt]"
                }
            }

        }
        # writing fixed HTML to disk
        $sAlbumFilepath = "$sFixedFotosHTMLFilePath/$sAlbumFileBaseName.html"
        wlog "writing fixed HTML to [$sAlbumFilepath]"
        $sFixedContent | out-file $sAlbumFilepath -Encoding UTF8
    }
}

ProcessMessages $sMessagesPath
ProcessPhotoAlbums $sAlbumsPath

