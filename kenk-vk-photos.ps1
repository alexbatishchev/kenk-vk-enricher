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
$aAllAttachmentDescriptions = @()
$aAllAttachmentDescriptions += ""

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

function ProcessAttachmentNode($oNode) {

    #wlog "---------------------------"
    #wlog "!!!!! DEBUG starting ProcessAttachmentNode"
    $sOriginalText = $oNode.OuterHtml
    #wlog "!!!!! DEBUG WAS sOriginalText [$sOriginalText]"

    $oAttachmentDescription = $oNode.SelectSingleNode(".//div[@class='attachment__description']")
    $sAttachmentDescription = $oAttachmentDescription.InnerText.ToString()
    if ($sAttachmentDescription -ne $FOTOS_DIV_DESCRIPTION) {
        $aAllAttachmentDescriptions = $aAllAttachmentDescriptions + $sAttachmentDescription
        $aAllAttachmentDescriptions = $aAllAttachmentDescriptions | sort -unique
        #wlog "---------------------- not supported sAttachmentDescription $sAttachmentDescription"
        return $sOriginalText
    }
    $oAttachmentLink = $oElem.SelectSingleNode(".//a[@class='attachment__link']")
    #$sOriginalText = $oAttachmentLink.OuterHtml

    # finding original URI of file and downloading it to local copy
    $sImgSrcPath = $oAttachmentLink.GetAttributeValue("href","nothing")
    if ($sImgSrcPath.StartsWith("https://vk.com/photo")) {
        #read-host 
        wlog "#try to find from cache and replace for [$sImgSrcPath]"
        #try to find from cache and replace
        if ($hRemoteLocalPhotos.ContainsKey($sImgSrcPath)) {
            $sLocalImgFilePath = $hRemoteLocalPhotos[$sImgSrcPath]

            $sOriginalBlockText = $oAttachmentLink.OuterHtml
            $sHTMLRelativePath = "../.$sLocalImgFilePath"

            wlog ("!!! should change [$sImgSrcPath] to [$sHTMLRelativePath] because it is in cache")

            $bRet = $oAttachmentLink.SetAttributeValue("href",$sHTMLRelativePath)
            $oAttachmentLink.InnerHtml = ""
            $oNewImg = $dom.CreateElement("img")
            $bRet = $oNewImg.SetAttributeValue("src",$sHTMLRelativePath)
            $bRet = $oAttachmentLink.AppendChild($oNewImg)
            # fixing HTML
            $sNewBlockText = $oAttachmentLink.OuterHtml
            $sNewBlockText = "<br>" + $sNewBlockText            
            $sOriginalText = $sOriginalText.Replace($sOriginalBlockText,$sNewBlockText)
            return $sOriginalText
        } else {
            wlog ("!!! no cache for [$sImgSrcPath] found, leaving as is")
            return $sOriginalText
        }       
    } else {
        $sNewFileName = $null
        $sNewFileName = GetImgFileNameForUseapiSource $sImgSrcPath
        if ($null -eq $sNewFileName)
        {
            wlog "ERROR sNewFileName null"
            return $sOriginalText
        }
        $sPath = "$sFixedMessagesPath/$sMessageFolderId/imgs"
        forcepath $sPath 
        $sPath = "$sPath/$sNewFileName"
        DownloadFilePlease $sImgSrcPath $sPath $DOWNLOAD_DELAY_SECONDS
        # creating new HMTL img object and making links to local file
        
        $sOriginalBlockText = $oAttachmentLink.OuterHtml

        $sHTMLRelativePath = "./imgs/$sNewFileName"
        $bRet = $oAttachmentLink.SetAttributeValue("href",$sHTMLRelativePath)
        $oAttachmentLink.InnerHtml = ""
        $oNewImg = $dom.CreateElement("img")
        $bRet = $oNewImg.SetAttributeValue("src",$sHTMLRelativePath)
        $bRet = $oAttachmentLink.AppendChild($oNewImg)
        # fixing HTML
        $sNewBlockText = $oAttachmentLink.OuterHtml
        $sNewBlockText = "<br>" + $sNewBlockText
        #wlog "!!!!! DEBUG sOriginalBlockText [$sOriginalBlockText]"
        #wlog "!!!!! DEBUG sNewBlockText [$sNewBlockText]"
        $sOriginalText = $sOriginalText.Replace($sOriginalBlockText,$sNewBlockText)
        #wlog "!!!!! DEBUG NOW sOriginalText [$sOriginalText]"
        return $sOriginalText
    }
}
function processWall($sWallPath) {
    wlog "processing wall at path [$sWallPath]"
    
    $aWallFiles = Get-ChildItem $sWallPath *.html -File 
    foreach ($oWallFile in $aWallFiles) {
        $sWallFileName = $oWallFile.Name
        wlog "processing wall file for file $sWallFileName"
        $sContent = get-content $oWallFile.FullName
        $dom = New-Object -TypeName "HtmlAgilityPack.HtmlDocument"
        $dom.LoadHtml($sContent)
        $sFixedPageContent = $dom.Text

        # getting and parsing all DIVs for wall attachment data

        $aElems = $dom.DocumentNode.SelectNodes("//div[@class='kludges']//div[@class='attachment']")
        
        foreach ($oElem in $aElems) {
            $sOriginalElementText = $oElem.OuterHtml
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
function ProcessMessages($sAllMessagesPath) {
    wlog "processing messages at path [$sAllMessagesPath]"

    $aMessageFolders = Get-ChildItem $sAllMessagesPath -directory | Sort-Object -property Name
    wlog ("got messages folders: " +  $aMessageFolders.count)
    $aMessageFolders = $aMessageFolders | ?{$_.Name -eq "98773020"}
    foreach ($oMessageFolder in $aMessageFolders) {
        $sMessageFolderId = $oMessageFolder.Name
        wlog "processing messages for folder ID $sMessageFolderId"
        $aMessageFolderFiles = Get-ChildItem $oMessageFolder.FullName *.html -File 
        foreach ($oMessageFile in $aMessageFolderFiles) {
            $sMessageFileId = $oMessageFile.Name
            wlog "processing file for file ID $sMessageFileId"
            $sContent = get-content $oMessageFile.FullName
            #$sFixedPageContent = $sContent # for later String replace
            
            $dom = New-Object -TypeName "HtmlAgilityPack.HtmlDocument"
            $dom.LoadHtml($sContent)
            $sFixedPageContent = $dom.Text
            # getting and parsing all DIVs for message attachment data
            $aElems = $dom.DocumentNode.SelectNodes("//div[@class='wrap_page_content']//div[@class='item']//div[@class='item__main']//div[@class='message']//div//div[@class='kludges']//div[@class='attachment']")
            
            foreach ($oElem in $aElems) {
                $sOriginalElementText = $oElem.OuterHtml
                $sNewElementText = ProcessAttachmentNode $oElem
                if ($sOriginalElementText -ne $sNewElementText) {
                    #wlog "----------- DEB [$sOriginalElementText] [$sNewElementText]"
                    #$sOriginalElementText | out-file "c:\temp\$sMessageFileId"
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
function ProcessPhotoAlbums($sPhotoAlbumsPath) {
    wlog "==============================================="
    wlog "now processing photo albums"

    $aAlbums = Get-ChildItem $sPhotoAlbumsPath *.html -File | Sort-Object -property Length 
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

            if (-not($hRemoteLocalPhotos.ContainsKey($sImgDivAPath))) {
                $hRemoteLocalPhotos.Add($sImgDivAPath, "$sAlbumStorePath/$sPhotoFileName")
            }
            
            $sNewDivText = $sNewDivText.Replace($sImgSrcPath,$sImgPathForHtml)
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

ProcessPhotoAlbums $sAlbumsPath

$iCount = $hRemoteLocalPhotos.count
wlog ("at this time we got $iCount hashed fotos with original https://vk.com/photoXXXXXXXXX_XXXXXXXXX names")

ProcessMessages $sMessagesPath

processWall $sWallPath

wlog "not processed yet attachment descriptions:"
$aAllAttachmentDescriptions | fl