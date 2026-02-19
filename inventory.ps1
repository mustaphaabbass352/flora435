param(
    [string[]]$Commands
)

$products = @(
    @{SKU="FJ-M-RT";Name="Flora Joy Mini (Rubber Tissue) 100s"},
    @{SKU="FS-DH-10P";Name="Flora Smile Disposable Handkerchief (10 Packs)"},
    @{SKU="FJ-DH-10P";Name="Flora Joy Disposable Handkerchief (10 Packs)"},
    @{SKU="FJ-TR-UW";Name="Flora Joy Toilet Roll Unwrapped"},
    @{SKU="FJ-PT-B16";Name="Flora Joy Multi-Purpose Paper Towel Blue (1×6)"},
    @{SKU="FS-TN-1P";Name="Flora Smile Table Napkin"},
    @{SKU="FJ-TN-1P";Name="Flora Joy Table Napkin"},
    @{SKU="FG-PT-2P";Name="Flora Giant Multi-Purpose Paper Towel"},
    @{SKU="FS-PT-B19";Name="Flora Smile Multi-Purpose Paper Towel Blue (1×9)"},
    @{SKU="FJ-FT-BX";Name="Flora Joy Facial Tissue (Box)"},
    @{SKU="AF-FT-BX";Name="Africa Facial Tissue (Box)"},
    @{SKU="PY-FT-BX";Name="Papyrus Box Tissue"},
    @{SKU="TR-FT-BX";Name="Tradition Box Tissue"},
    @{SKU="FJ-ML-100";Name="Flora Joy Mini Love (100s)"},
    @{SKU="PY-TN-WP";Name="Papyrus Table Napkin (With Promotion)"},
    @{SKU="TP-TN-PR";Name="Tango Prime Table Napkin"},
    @{SKU="PY-TN-NP";Name="Papyrus Table Napkin (No Promotion)"},
    @{SKU="FS-TR-UW";Name="Toilet Roll Smile Unwrapped"},
    @{SKU="TW-PW-50";Name="Tango Wash (Multi-Purpose Prime Wash)"},
    @{SKU="WP-150G";Name="Washing Powder 150g"},
    @{SKU="WP-400G";Name="Washing Powder 400g"},
    @{SKU="WP-1KG";Name="Washing Powder 1kg"},
    @{SKU="PT-TR-112";Name="Public Toilet Roll 1×12"},
    @{SKU="HT-OR-106";Name="Hand Towel Orange 1×6"},
    @{SKU="HT-OR-109";Name="Hand Towel Orange 1×9"},
    @{SKU="PY-TR-20";Name="Papyrus Toilet Roll"},
    @{SKU="WV-HT-40";Name="Weva Hand Towel"},
    @{SKU="WV-TR-20";Name="Weva Toilet Roll"},
    @{SKU="SB-BS-20";Name="Special Bedsheet"},
    @{SKU="VF-HT-20";Name="Vfold Hand Towel"},
    @{SKU="FJ-DH-GT";Name="Flora Joy DH Giant"},
    @{SKU="HT-MLC-40";Name="Hand Towel Melcom"},
    @{SKU="HT-JOY-112";Name="Hand Towel Joy 1×12"},
    @{SKU="HT-JOY-106";Name="Hand Towel Joy 1×6"},
    @{SKU="AF-30CM";Name="30cm Aluminium Foil"},
    @{SKU="FT-DLT-BX";Name="FT Delta"},
    @{SKU="MTC-FT-BX";Name="MTC"},
    @{SKU="MTV-FT-BX";Name="MTV"}
)

$skuToName = @{}
$nameToSku = @{}
foreach ($p in $products) {
    $skuToName[$p.SKU] = $p.Name
    $nameToSku[$p.Name.ToLower()] = $p.SKU
}

$stock = @{}
foreach ($p in $products) { $stock[$p.SKU] = 0 }

$log = New-Object System.Collections.ArrayList

function Resolve-Item {
    param([string]$token)
    $t = ($token.Trim())
    if ($skuToName.ContainsKey($t)) { return @{SKU=$t;Name=$skuToName[$t]} }
    $key = $t.ToLower()
    if ($nameToSku.ContainsKey($key)) {
        $sku = $nameToSku[$key]
        return @{SKU=$sku;Name=$skuToName[$sku]}
    }
    return $null
}

function Print-Header {
    $fmt = "{0,-40} | {1,-12} | {2,-18} | {3, -22} | {4, -14} | {5, -12}"
    Write-Host ($fmt -f "Item","SKU","Batch","Quantity Added/Removed","Current Stock","Status")
}

function Print-Row {
    param([string]$item,[string]$sku,[string]$batch,[string]$qty,[int]$current,[string]$status)
    $fmt = "{0,-40} | {1,-12} | {2,-18} | {3, -22} | {4, -14} | {5, -12}"
    Write-Host ($fmt -f $item,$sku,($batch -as [string]),$qty,$current,$status)
}

function Process-Set {
    param([string[]]$parts)
    if ($parts.Count -lt 3) { Write-Host "Invalid SET. Use: SET | SKU | Current Stock | Optional Batch"; return }
    $sku = $parts[1].Trim()
    if (-not $skuToName.ContainsKey($sku)) { Write-Host "Unknown SKU: $sku"; return }
    $qtyRaw = $parts[2].Trim()
    $parsed = 0
    if (-not [int]::TryParse($qtyRaw, [ref]$parsed)) { Write-Host "Invalid stock value: $qtyRaw"; return }
    $qty = $parsed
    if ($qty -lt 0) { Write-Host "Stock must be >= 0"; return }
    $batch = $null
    if ($parts.Count -ge 4) { $batch = $parts[3].Trim() }
    $stock[$sku] = $qty
    $entry = [PSCustomObject]@{
        Item=$skuToName[$sku];SKU=$sku;Batch=$batch;Qty=0;Current=$stock[$sku];Status="Initialized"
    }
    [void]$log.Add($entry)
    Print-Header
    Print-Row $entry.Item $entry.SKU $entry.Batch "+0" $entry.Current $entry.Status
}

function Process-Transfer {
    param([string[]]$parts)
    if ($parts.Count -lt 3) { Write-Host "Invalid input. Use: Item/SKU | Add/Remove | Quantity | Optional Batch | Optional Delivered/Pending"; return }
    $itemToken = $parts[0]
    $action = $parts[1].Trim().ToLower()
    $qtyRaw = $parts[2].Trim()
    if (($action -ne "add") -and ($action -ne "remove")) { Write-Host "Action must be Add or Remove"; return }
    $parsed2 = 0
    if (-not [int]::TryParse($qtyRaw, [ref]$parsed2)) { Write-Host "Quantity must be a positive integer"; return }
    $qty = $parsed2
    if ($qty -le 0) { Write-Host "Quantity must be positive"; return }
    $resolved = Resolve-Item $itemToken
    if ($null -eq $resolved) { Write-Host "Item not found: $itemToken"; return }
    $sku = $resolved.SKU
    $name = $resolved.Name
    $batch = $null
    $statusOverride = $null
    if ($parts.Count -ge 4) {
        $t4 = $parts[3].Trim()
        if ($t4 -in @("Delivered","Pending","In-Transit")) { $statusOverride = $t4 } else { $batch = $t4 }
    }
    if ($parts.Count -ge 5) {
        $t5 = $parts[4].Trim()
        if ($t5 -in @("Delivered","Pending","In-Transit")) { $statusOverride = $t5 }
    }
    if ($action -eq "add") {
        $new = $stock[$sku] + $qty
        $stock[$sku] = $new
        $status = if ($statusOverride) { $statusOverride } else { "Delivered" }
        $entry = [PSCustomObject]@{Item=$name;SKU=$sku;Batch=$batch;Qty=$qty;Current=$new;Status=$status}
        [void]$log.Add($entry)
        Print-Header
        Print-Row $name $sku $batch ("+" + $qty) $new $status
    } else {
        if ($qty -gt $stock[$sku]) { Write-Host "Invalid: removal exceeds current stock ($($stock[$sku]))"; return }
        $new = $stock[$sku] - $qty
        $stock[$sku] = $new
        $status = if ($statusOverride) { $statusOverride } else { "In-Transit" }
        $entry = [PSCustomObject]@{Item=$name;SKU=$sku;Batch=$batch;Qty=(-$qty);Current=$new;Status=$status}
        [void]$log.Add($entry)
        Print-Header
        Print-Row $name $sku $batch ("-" + $qty) $new $status
    }
}

function Print-Log {
    if ($log.Count -eq 0) {
        Write-Host "Running Log"
        Write-Host "- Empty"
        return
    }
    Write-Host "Running Log"
    Print-Header
    foreach ($e in $log) {
        $sign = if ($e.Qty -ge 0) { "+" + $e.Qty } else { $e.Qty.ToString() }
        Print-Row $e.Item $e.SKU $e.Batch $sign $e.Current $e.Status
    }
}

function Process-Line {
    param([string]$line)
    if ([string]::IsNullOrWhiteSpace($line)) { return }
    $parts = $line -split "\|"
    $parts = $parts | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
    if ($parts.Count -eq 0) { return }
    if ($parts[0].ToUpper() -eq "SET") {
        Process-Set -parts $parts
    } else {
        Process-Transfer -parts $parts
    }
    Print-Log
}

if ($Commands -and $Commands.Count -gt 0) {
    foreach ($c in $Commands) { Process-Line -line $c }
} else {
    Write-Host "Flora Tissues Inventory Assistant"
    Write-Host "Enter commands. Examples:"
    Write-Host "FJ-TR-UW | Remove | 40 | BATCH-TR-2402"
    Write-Host "Flora Joy Table Napkin | Add | 120"
    Write-Host "FS-DH-10P | Add | 50 | Delivered"
    Write-Host "SET | FJ-TR-UW | 480 | BATCH-TR-START"
    Write-Host "Type EXIT to quit."
    while ($true) {
        $line = Read-Host ">"
        if ($line -and $line.Trim().ToUpper() -eq "EXIT") { break }
        Process-Line -line $line
    }
}

