<#
TREC使用的是mp4容器,其中添加了TSCR，TSCM几个自定义box
TSCR标识了camtasia版本信息
TSCM包含光标图形，光标轨迹，按键，slide标题，等信息
#>
<#
tscm有十二个'DATA'块依次是：
recordingRegion.dat
cursorLocation.dat
cursorAction.dat
keyboard.dat
foregroundWnd.dat
caret.dat
misc.dat
cursorImages.dat
cursorOpacity.dat
slideComments.dat
slideTitles.dat
slideText.dat

mp4edit.exe --replace TSCM:C:/Users/he123/Documents/Camtasia/123/1.tscm C:\Users\he123\Documents\Camtasia\123\old.trec C:\Users\he123\Documents\Camtasia\123\new1.trec
 .\mp4dump.exe "C:\Users\he123\Documents\Camtasia\123\new1.trec" --format json|convertfrom-json|ft 
#>



<#
.SYNOPSIS
    从trec文件中导出tscm box
.DESCRIPTION
    trec文件是个mp4容器，这个脚本可以提取其中的tscm分段，它包含了光标和光标位置，鼠标点击，按键等信息
.EXAMPLE
    PS C:\> export-Tscm -path 'dds\dd.trec'
    export-Tscm -path [文件路径]
.INPUTS
    Inputs (if any)
.OUTPUTS
    Output (if any)
.NOTES
    这是一个对techsmith公司camtasia软件生成的trec格式录像文件中的光标文件进行替换的脚本
#>
function export-Tscm {
    #导出tscm
    [CmdletBinding()]
    param(
        # trec path
        [Parameter(Mandatory = $true, HelpMessage = "输入文件路径:  c:xxx.trec")]
        [string]
        $path
    )

    if ($path -match '\.trec') {
        $new = $path -replace '\.trec$'
        &  "$PSScriptRoot/tool/mp4extract.exe" TSCM $path "$new.tscm"

    }
    else { "路径错误" }


}



function import-trec {
    #tscm回写到trec
    [CmdletBinding()]
    param (
        # 文件路径
        [Parameter(Mandatory = $true, HelpMessage = "输入文件路径:  c:xxx.trec")]
        [string]
        $path        
    )

    #$path = "C:\Users\he123\Desktop\trecRec\cs_recording.trec"
    if ($path -notmatch '\.trec$') { '路径错误'; break }

    $new = $path -replace '(\.trec)', '.1$1'
    $path3 = $path -replace '(\.trec)', '.tscm'
    if(test-path $new ){$null=Remove-item -Path $new -Force}
    new-item -Path $new -ItemType File
    $write = [System.IO.File]::Open($new, [ System.IO.FileMode]::Open)
    $open = [System.IO.File]::Open($path, [ System.IO.FileMode]::Open)
    $tscm = [System.IO.File]::ReadAllBytes($path3)
    $duan = 0
    $size = 1mb
    $length = $size
    $th = $length
    $read = 1
    $len = 0
    while ($read) {
        $cha = $open.Length - $len
        if ($cha -lt $length) {
            $length = $cha
        }
        $byte = [byte[]]0 * $length
        $len += $open.Read($byte, 0, $length)
        $debug = [System.BitConverter]::ToString($byte).replace('-', '') 
        $debug = ($debug | Select-String -Pattern '0{6}015453434d').Matches.Index 
        if ($debug) {
            $end = $len - $length + $debug / 2
            $open.Position = 0

            while ($read) {
                $e = $end - $duan 
                if ($e -lt $size) {
                    $th = $e
                    $read = 0
                }
                $byte = [byte[]]0 * $th
                $duan += $open.Read($byte, 0, $th)
                $write.Write($byte, 0, $th)
            }
        }

    }
    $write.Write($tscm, 0, $tscm.Length)

    $open.Close()
    $write.Close()

    <#
.SYNOPSIS
    tscm回写到trec
.DESCRIPTION
    将tscm文件和原trec文件合称为新文件
.EXAMPLE
    PS C:\> import-trec -path "c:\xxx.tscm"
.NOTES
    这是一个对techsmith公司camtasia软件生成的trec格式录像文件中的光标文件进行替换的脚本
#>
}




function import-Tscm {
    #tscm图片回写
    [CmdletBinding()]
    param (
        # Parameter help description
        [Parameter(Mandatory = $true, HelpMessage = "输入文件路径，例如:  c:\xxx.tscm")]
        [string]
        $path        
    )
    
    if ($path -notmatch '\.tscm$') { '路径错误'; break }
    $read = [System.IO.File]::ReadAllBytes("$path");
    $tscmhex = [System.BitConverter]::ToString($read).replace('-', '')
    $new = split-path $path

    #$json = Get-Content -path "$new\config.json" -Encoding utf8 | ConvertFrom-Json
    $csv = Get-Content -path "$new\config.csv" -Encoding utf8 | ConvertFrom-csv
    $csv | ForEach-Object {
        $png = $new + '\' + $_.'Number' + '.png'
        $gd = [System.IO.File]::ReadAllBytes("$png");
        $pnghex = [System.BitConverter]::ToString($gd).replace('-', '')
        if ($pnghex -notlike $_.image) {
            "图片$( $_.'Number')被修改"
            $leng = $pnghex.Length / 2 - $_.imagelength + $_.length
            $all = ''
            $dao = ''
            $x = ''
            $y = ''
            (($leng -as [int])+20).ToString('X8') -replace '(..)', '$1 ' -split ' ' | ForEach-Object { $all = $_ + $all }
             ($leng -as [int]).ToString('X8') -replace '(..)', '$1 ' -split ' ' | ForEach-Object { $dao = $_ + $dao }
             ($_.x -as [int]).ToString('X8') -replace '(..)', '$1 ' -split ' ' | ForEach-Object { $x = $_ + $x }
            ($_.y -as [int]).ToString('X8') -replace '(..)', '$1 ' -split ' ' | ForEach-Object { $y = $_ + $y }

            $image = $($_.image)
            
            $string = "$all$dao$x$y$pnghex"
            $tscmhex = $tscmhex -replace ".{32}$image", $string
        }
    }
    #
    $conv = $tscmhex | Select-String -Pattern '015453434d0{8}(.{8})' -AllMatches
    $yuanchang = [convert]::ToString('0x' + $conv.Matches.groups.Value[1], 10)
    $zonglength = $tscmhex.length / 2
    if ($yuanchang -eq $zonglength) {
        write-host "文件没有改变"
    }
    else {
        $zonglength = ($zonglength).ToString('X8')
        $tscmhex = $tscmhex -replace '(015453434d0{8}).{8}', "`${1}$zonglength" 
        [system.io.file]::WriteAllBytes("$path", $([byte[]] -split ($tscmhex -replace '..', '0x$& ') ))
    }
    <#
.SYNOPSIS
    tscm图片回写
.DESCRIPTION
    将修改后的png和csv图片信息文件写入到tscm文件
.EXAMPLE
    PS C:\> import-Tscm -path "c:\xxx.trec"
.NOTES
    这是一个对techsmith公司camtasia软件生成的trec格式录像文件中的光标文件进行替换的脚本
#>
}


<#
.SYNOPSIS
    导出png光标文件
.DESCRIPTION
    从tscm文件中导出png光标文件和光标xy轴，大小等信息的csv
.EXAMPLE
    PS C:\> import-Tscm -path "c:\xxx.trec"
.NOTES
    这是一个对techsmith公司camtasia软件生成的trec格式录像文件中的光标文件进行替换的脚本
#>
function export-png {
    #导出png光标文件
    [CmdletBinding()]
    param (
        # 路径
        [Parameter(Mandatory = $true, HelpMessage = "输入文件路径,例如:  c:\xxx.tscm")]
        [string]
        $path        
    )
    
    if ($path -match '\.tscm') {
        $gd = [System.IO.File]::ReadAllBytes($path);
        $png = [System.BitConverter]::ToString($gd).replace('-','') | Select-String -Pattern '(?<alllength>.{8})(?<pnglength>.{8})(?<x>.{8})(?<y>.{8})(?<image>89504e470d0a1a0a.{20,}?49454e44ae426082)' -AllMatches


        $new = split-path $path
        $x = 0
        $object = $png.Matches | ForEach-Object {
            $x++
            [string]$all=''
            [string]$l=''
            [string]$y=''
            [string]$xx=''
            
            ($_.groups | Where-Object { $_.name -like 'alllength' }).Value -replace '(..)','$1 ' -split ' ' |%{$all=$_+$all}
            ($_.groups | Where-Object { $_.name -like 'pnglength' }).Value -replace '(..)','$1 ' -split ' ' |%{$l=$_+$l}
            ($_.groups | Where-Object { $_.name -like 'y' }).Value  -replace '(..)','$1 ' -split ' ' |%{$y=$_+$y}
            $xx = '0x' + ($_.groups | Where-Object { $_.name -like 'x' }).Value -replace '(..)','$1 ' -split ' ' |%{$xx=$_+$xx}
            $image = ($_.groups | Where-Object { $_.name -like 'image' }).Value 
            [system.io.file]::WriteAllBytes("$new\$x.png", $([byte[]] -split ($image -replace '..', '0x$& ') ))
            [PSCustomObject]@{
                'Number'    = $x
                AllLength  =[uint]"0x$all"
                Length      = [uint]"0x$l"
                X           = [uint]"0x$xx"
                Y           = [uint]"0x$y"
                ImageLength = $image.length / 2
                Image       = $image
            }
        } 
        $object | Format-Table
        #$object | ConvertTo-json | set-content -path "$new\config.json"
        $object | ConvertTo-csv  | set-content -path "$new\config.csv"
    }
    else { "路径错误" }
}


<#
.SYNOPSIS
    通过原trec,tscm和png文件生成新的trec
.DESCRIPTION
    Long description
.EXAMPLE
    PS C:\> new-trec -trec 'xxxx.trec' -tscm 'xxxx.tscm'
    new-trec -trec [trec文件路径] -tscm [tscm文件路径]
.INPUTS
    Inputs (if any)
.OUTPUTS
    Output (if any)
.NOTES
    这是一个对techsmith公司camtasia软件生成的trec格式录像文件中的光标文件进行替换的脚本
#>

function new-trec {
    param (
        # 把新的trec,tscm和png生成新的trec
        [Parameter(mandatory = $true, HelpMessage = "请输入trec路径，例如：C:\Users\trecRec\config.trec")]
        [string]
        $trec,
        [Parameter(mandatory = $true, HelpMessage = "请输入trec路径，例如：C:\Users\trecRec\config.tscm")]
        [string]
        $tscm
    )
    try {
        $list = $trec, $tscm
        $br = test-path $list
        if ($br) {
            import-Tscm -path "$tscm"
            import-trec -path "$trec"
            write-host '完成'
        }
        else {
            for ($i = 0; $i -lt $list.Count; $i++) {
                if (!$br[$i]) { $jg = $list[$i] }
            }
            Write-Error "$jg 错误"
        }
    }
    catch {
        $_
    }
}



