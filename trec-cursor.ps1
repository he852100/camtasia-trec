<#
TREC使用的是mp4容器,其中添加了几个自定义box
TSCR标识了camtasia版本信息
TSCM包含光标，光标轨迹，slide标题，等信息
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
#>


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
    Remove-item -Path $new -Force
    new-item -Path $new -ItemType File
    $write = [System.IO.File]::Open($new, [ System.IO.FileMode]::Open)
    $open = [System.IO.File]::Open($path, [ System.IO.FileMode]::Open)
    $tscm = [System.IO.File]::ReadAllBytes($path3)

    $length = 1mb
    $th = $length
    #$length = [math]::Ceiling($open.Length/1mb)
    $read = 1
    $len = 0
    while ($read) {
        $byte = [byte[]]0 * $length
        $len += $open.Read($byte)
        $debug = ([convert]::ToHexString($byte)  | Select-String -Pattern '0{6}015453434d').Matches.Index 
        if ($debug) {
            $end = $len + $debug / 2
            $open.Position = 0

            while ($read) {
                $e = $end - $open.Position
                if ($e -lt $length) {
                    $th = $e
                    $read = 0
                }
                $byte = [byte[]]0 * $th
                $null = $open.Read($byte, 0, $th)
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
    PS C:\> import-trec -path "c:\xxx.trec"
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
    $tscmhex = [convert]::ToHexString($read)
    $new = split-path $path

    #$json = Get-Content -path "$new\config.json" -Encoding utf8 | ConvertFrom-Json
    $csv = Get-Content -path "$new\config.csv" -Encoding utf8 | ConvertFrom-csv
    $csv | ForEach-Object {
        $png = $new + '\' + $_.'Number' + '.png'
        $gd = [System.IO.File]::ReadAllBytes("$png");
        $pnghex = [convert]::ToHexString($gd)
        if ($pnghex -notlike $_.image) {
            "修改图片$( $_.'Number')"
            $leng = $pnghex.Length / 2 - $_.imagelength + $_.length
            $dao = (($leng).ToString('X4') -split '(?<=^.{2})')[1..0] -join ''
            $x = (($_.x).ToString('X4') -split '(?<=^.{2})')[1..0] -join ''
            $y = (($_.y).ToString('X4') -split '(?<=^.{2})')[1..0] -join ''

            $image = $($_.image)
            
            $string = "$dao" + '0000' + $x + '0000' + "$y" + '0000' + "$pnghex"
            $tscmhex = $tscmhex -replace ".{24}$image", $string
        }
    }
    #$tscmhex
    $conv = $tscmhex | Select-String -Pattern '015453434d0{8}(.{8})' -AllMatches
    $yuanchang = [convert]::ToString('0x' + $conv.Matches.groups.Value[1], 10)
    $zonglength = $tscmhex.length / 2
    if ($yuanchang -eq $zonglength) {
        write-host "文件没有改变"
    }
    else {
        $zonglength = ($zonglength).ToString('X8')
        $tscmhex = $tscmhex -replace '(015453434d0{8}).{8}', "`${1}$zonglength"
        [system.io.file]::WriteAllBytes("$new\new.tscm", [convert]::FromHexString($tscmhex))
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
        $png = [convert]::ToHexString($gd) | Select-String -Pattern '(?<length2>.{2})(?<length1>.{2})0{4}(?<x1>.{2})(?<x>.{2})0{4}(?<y1>.{2})(?<y>.{2})0{4}(?<image>89504e470d0a1a0a.{20,}?49454e44ae4260)' -AllMatches


        $new = split-path $path
        $x = 0
        $object = $png.Matches | % {
            $x++
            $l = '0x' + ($_.groups | ? { $_.name -like 'length1' }).Value + ($_.groups | ? { $_.name -like 'length2' }).Value 
            $y = '0x' + ($_.groups | ? { $_.name -like 'y' }).Value + ($_.groups | ? { $_.name -like 'y1' }).Value
            $xx = '0x' + ($_.groups | ? { $_.name -like 'x' }).Value + ($_.groups | ? { $_.name -like 'x1' }).Value
            $image = ($_.groups | ? { $_.name -like 'image' }).Value 
            [system.io.file]::WriteAllBytes("$new\$x.png", [convert]::FromHexString($image))
            [PSCustomObject]@{
                'Number'    = $x
                Length      = [convert]::ToString( $l, 10)
                X           = [convert]::ToString($xx , 10)
                Y           = [convert]::ToString($y , 10)
                ImageLength = $image.length / 2
                Image       = $image
            }
        } 
        $object | ft
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
            import-Tscm -path $tscm
            import-trec -path $trec
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



