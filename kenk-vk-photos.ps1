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
$sFixedFotosIMGPath = "$sFixedArchivePath/$sFixedFotosIMGFolderName"
$sMessagesPath = "$sArchivePath/messages"
$sFixedMessagesPath = "$sFixedArchivePath/messages"
$sWallPath          = "$sArchivePath/wall"
$sFixedWallPath     = "$sFixedArchivePath/wall"

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
$sLocalLogName = $sLocalLogPath + $oTempDate.ToString($sLogFileNameTemplate) +".txt"
function Wlog( $sText ) {
    $sOut = "[" + (Get-Date).ToString("yyyy-MM-dd-HH-mm-ss") + "]: " + $sText
    $sOut | Out-File -FilePath $sLocalLogName -Encoding "UTF8" -Append
    write-host $sOut
}

############
function forcepath ($sThisPath) {
    if (-not (test-path $sThisPath)) {    
        $null = New-item $sThisPath -ItemType Directory -Force
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
function ProcessAttachmentNode($oNode) {
    $sOriginalNodeText = $oNode.InnerHtml

    # checking attachmet type via text in 'attachment__description' DIV
    $oAttachmentDescription = $oNode.SelectSingleNode(".//div[@class='attachment__description']")
    $sAttachmentDescription = $oAttachmentDescription.InnerText.ToString()
    $oAttachmentLink = $null
    $oAttachmentLink = $oElem.SelectSingleNode(".//a[@class='attachment__link']")
    
    # processing only FOTOS_DIV_DESCRIPTION div
    if ($sAttachmentDescription -ne $FOTOS_DIV_DESCRIPTION) {

        if ($null -ne $oAttachmentLink) {
            $sImgSrcPath = $oAttachmentLink.GetAttributeValue("href","nothing")

            $global:aAllAttachmentDescriptions = $global:aAllAttachmentDescriptions + $sAttachmentDescription
            $global:aAllAttachmentDescriptions = $global:aAllAttachmentDescriptions | Sort-Object -unique
            wlog "-- not supported and not empty sAttachmentDescription $sAttachmentDescription with link [$sImgSrcPath]"
        }    
        return $sOriginalNodeText
    }
    
    # parsing attachment's foto link
    $sImgSrcPath = $oAttachmentLink.GetAttributeValue("href","nothing")
    # finding original URI of file and downloading it to local copy
    if ($sImgSrcPath.StartsWith("https://vk.com/photo")) {
        #try to find this type of foto from cache and replace
        wlog "#try to find from cache and replace for [$sImgSrcPath]"
        if ($hRemoteLocalPhotos.ContainsKey($sImgSrcPath)) {
            $sLocalImgFilePath = $hRemoteLocalPhotos[$sImgSrcPath]

            $sOriginalBlockText = $oAttachmentLink.InnerHtml
            $sHTMLRelativePath = "../.$sLocalImgFilePath"

            wlog ("!!! should change [$sImgSrcPath] to [$sHTMLRelativePath] because it is in cache")

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
        } else {
            wlog ("!!! no cache for [$sImgSrcPath] found, leaving as is")
            return $sOriginalNodeText
        }       
    } else {
        # link is direct, downloading img file
        $sNewFileName = $null
        $sNewFileName = GetImgFileNameForUseapiSource $sImgSrcPath
        if ($null -eq $sNewFileName)
        {
            wlog "ERROR sNewFileName null"
            return $sOriginalNodeText
        }
        $sPath = "$sFixedMessagesPath/$sMessageFolderId/imgs"
        forcepath $sPath 
        $sPath = "$sPath/$sNewFileName"
        DownloadFilePlease $sImgSrcPath $sPath $DOWNLOAD_DELAY_SECONDS

        # creating new HMTL img object and making links to local file
        $sHTMLRelativePath = "./imgs/$sNewFileName"
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
function processWall($sWallPath) {
    wlog "processing wall at path [$sWallPath]"
    
    $aWallFiles = Get-ChildItem $sWallPath *.html -File 
    foreach ($oWallFile in $aWallFiles) {
        $sWallFileName = $oWallFile.Name
        wlog "processing wall file for file $sWallFileName"
        $sContent = get-content $oWallFile.FullName -Raw
        $dom = New-Object -TypeName "HtmlAgilityPack.HtmlDocument"
        $dom.LoadHtml($sContent)
        $sFixedPageContent = $sContent

        # getting and parsing all DIVs for wall attachment data

        $aElems = $dom.DocumentNode.SelectNodes("//div[@class='kludges']//div[@class='attachment']")
        
        foreach ($oElem in $aElems) {
            $sOriginalElementText = $oElem.InnerHtml
            $sNewElementText = ProcessAttachmentNode $oElem
            if ($sOriginalElementText -ne $sNewElementText) {
                $sFixedPageContent = $sFixedPageContent.Replace($sOriginalElementText, $sNewElementText)
            }
        }
        # writing fixed HTML file to disk
        $sPath = "$sFixedWallPath/$sWallFileName"
        wlog "writing fixed HTML wall content to [$sPath]"
        $sFixedPageContent | out-file $sPath -Encoding UTF8            
    }
}

#####
function ProcessMessages($sAllMessagesPath) {
    wlog "processing messages at path [$sAllMessagesPath]"

    $aMessageFolders = Get-ChildItem $sAllMessagesPath -directory | Sort-Object -property Name
    wlog ("got messages folders: " +  $aMessageFolders.count)
    
    # DEBUG
    # $aMessageFolders = $aMessageFolders | Where-Object{$_.Name -eq "2000000162"}
    # DEBUG
    foreach ($oMessageFolder in $aMessageFolders) {
        $sMessageFolderId = $oMessageFolder.Name
        wlog "processing messages for folder ID $sMessageFolderId"
        $aMessageFolderFiles = Get-ChildItem $oMessageFolder.FullName *.html -File 
        foreach ($oMessageFile in $aMessageFolderFiles) {
            $sMessageFileId = $oMessageFile.Name
            wlog "processing file for file ID $sMessageFileId"
            $sContent = get-content $oMessageFile.FullName -Raw
            $sFixedPageContent = $sContent 
            
            $dom = New-Object -TypeName "HtmlAgilityPack.HtmlDocument"
            $dom.LoadHtml($sContent)
            
            # getting and parsing all DIVs for message attachment data
            $aElems = $dom.DocumentNode.SelectNodes("//div[@class='wrap_page_content']//div[@class='item']//div[@class='item__main']//div[@class='message']//div//div[@class='kludges']//div[@class='attachment']")
            
            foreach ($oElem in $aElems) {
                $sOriginalElementText = $oElem.InnerHtml
                $sNewElementText = ProcessAttachmentNode $oElem
                if ($sOriginalElementText -ne $sNewElementText) {
                    $sFixedPageContent = $sFixedPageContent.Replace($sOriginalElementText, $sNewElementText)
                }
            }
            # writing fixed HTML file to disk
            $sPath = "$sFixedMessagesPath/$sMessageFolderId/$sMessageFileId"
            wlog "writing fixed HTML message content to [$sPath]"
            $sFixedPageContent | out-file $sPath -Encoding UTF8            
        }
    }
}
##################
function ProcessPhotoAlbums($sPhotoAlbumsPath) {
    wlog "==============================================="
    wlog "now processing photo albums"

    $aAlbums = Get-ChildItem $sPhotoAlbumsPath *.html -File | Sort-Object -property Length 

    foreach ($sAlbumFile in $aAlbums) {
        wlog ("================================")
        wlog ("parsing file" + $sAlbumFile.FullName)
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

        $sAlbumStorePath= "$sFixedFotosIMGPath/$sAlbumName"
        forcepath $sAlbumStorePath

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
            $sPathForStoringLocalImg = "$sAlbumStorePath/$sPhotoFileName"
            DownloadFilePlease $sImgSrcPath $sPathForStoringLocalImg $DOWNLOAD_DELAY_SECONDS

            # generating path to image for HTML links
            $sImgPathForHtml = "../../$sFixedFotosIMGFolderName/$sAlbumName/$sPhotoFileName"

            # Replacing links and generating new DIV text
            $sOldDivText = $oImgDiv.InnerHtml
            $sNewDivText = $oImgDiv.InnerHtml

            $oImgDivA = $oElem.SelectSingleNode(".//div[1]//a[1]")
            $sImgDivAPath = $oImgDivA.GetAttributeValue("href","nothing")

            # caching image original VK and local paths
            if (-not($hRemoteLocalPhotos.ContainsKey($sImgDivAPath))) {
                $hRemoteLocalPhotos.Add($sImgDivAPath, "$sAlbumStorePath/$sPhotoFileName")
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

wlog ("start of script")

ProcessPhotoAlbums $sAlbumsPath

$iCount = $hRemoteLocalPhotos.count
wlog ("at this time we got $iCount hashed fotos with original https://vk.com/photoXXXXXXXXX_XXXXXXXXX names")

ProcessMessages $sMessagesPath
processWall $sWallPath

wlog "not processed yet attachment descriptions:"
$global:aAllAttachmentDescriptions | Format-List

wlog ("end of script")